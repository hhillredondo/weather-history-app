import 'package:flutter_test/flutter_test.dart';
import 'package:weather_history/models/chat_message.dart';

void main() {
  group('ChatReply.fromJson', () {
    test('parses a minimal text-only reply', () {
      final reply = ChatReply.fromJson({
        'reply': 'Hello world',
        'plots': [],
        'tool_calls': [],
        'usage': {'daily_used': 100, 'daily_limit': 10000},
      });
      expect(reply.reply, 'Hello world');
      expect(reply.plots, isEmpty);
      expect(reply.toolCalls, isEmpty);
      expect(reply.dailyUsed, 100);
      expect(reply.dailyLimit, 10000);
    });

    test('parses tool calls including failed ones', () {
      final reply = ChatReply.fromJson({
        'reply': 'Did the thing.',
        'plots': [],
        'tool_calls': [
          {'name': 'aggregate', 'ok': true, 'input': {'metric': 'temp_max'}},
          {'name': 'plot', 'ok': false},
        ],
      });
      expect(reply.toolCalls, hasLength(2));
      expect(reply.toolCalls[0].name, 'aggregate');
      expect(reply.toolCalls[0].ok, isTrue);
      expect(reply.toolCalls[0].input?['metric'], 'temp_max');
      expect(reply.toolCalls[1].ok, isFalse);
    });

    test('parses a line plot with two series and numeric points', () {
      final reply = ChatReply.fromJson({
        'reply': 'See chart.',
        'plots': [
          {
            'title': 'Daily max temp',
            'y_label': 'Temperature (°C)',
            'kind': 'line',
            'series': [
              {
                'label': '2024',
                'points': [
                  {'x': '2024-07-01', 'y': 28.5},
                  {'x': '2024-07-02', 'y': 31.0},
                ],
              },
              {
                'label': '2023',
                'points': [
                  {'x': '2023-07-01', 'y': 26.0},
                ],
              },
            ],
          },
        ],
        'tool_calls': [],
      });
      expect(reply.plots, hasLength(1));
      final plot = reply.plots.first;
      expect(plot.title, 'Daily max temp');
      expect(plot.kind, PlotKind.line);
      expect(plot.yLabel, 'Temperature (°C)');
      expect(plot.series, hasLength(2));
      expect(plot.series.first.points, hasLength(2));
      expect(plot.series.first.points.first.x, '2024-07-01');
      expect(plot.series.first.points.first.y, 28.5);
    });

    test('falls back to line plot when kind is unknown or missing', () {
      final r1 = ChatReply.fromJson({
        'reply': '',
        'plots': [
          {'title': 't', 'kind': 'unknown', 'series': []},
        ],
        'tool_calls': [],
      });
      expect(r1.plots.first.kind, PlotKind.line);

      final r2 = ChatReply.fromJson({
        'reply': '',
        'plots': [
          {'title': 't', 'series': []},
        ],
        'tool_calls': [],
      });
      expect(r2.plots.first.kind, PlotKind.line);
    });

    test('parses bar plot kind', () {
      final reply = ChatReply.fromJson({
        'reply': '',
        'plots': [
          {
            'title': 'Yearly max',
            'kind': 'bar',
            'series': [
              {
                'label': 'Madrid',
                'points': [
                  {'x': '2020', 'y': 41},
                  {'x': '2021', 'y': 42},
                ],
              },
            ],
          },
        ],
        'tool_calls': [],
      });
      expect(reply.plots.first.kind, PlotKind.bar);
    });

    test('handles missing or null fields gracefully', () {
      final reply = ChatReply.fromJson({});
      expect(reply.reply, '');
      expect(reply.plots, isEmpty);
      expect(reply.toolCalls, isEmpty);
      expect(reply.dailyUsed, isNull);
      expect(reply.dailyLimit, isNull);
    });

    test('coerces non-string x values to strings and missing y to 0', () {
      final reply = ChatReply.fromJson({
        'reply': '',
        'plots': [
          {
            'title': 't',
            'kind': 'line',
            'series': [
              {
                'label': 'l',
                'points': [
                  {'x': 2024, 'y': null},
                  {'x': null, 'y': 5},
                ],
              },
            ],
          },
        ],
        'tool_calls': [],
      });
      final pts = reply.plots.first.series.first.points;
      expect(pts[0].x, '2024');
      expect(pts[0].y, 0);
      expect(pts[1].x, '');
      expect(pts[1].y, 5);
    });
  });

  group('ChatMessage', () {
    test('toWireJson emits role and content only', () {
      const m = ChatMessage(role: ChatRole.user, content: 'Hi');
      expect(m.toWireJson(), {'role': 'user', 'content': 'Hi'});
    });

    test('assistant role serialises correctly', () {
      const m = ChatMessage(role: ChatRole.assistant, content: 'Reply');
      expect(m.toWireJson()['role'], 'assistant');
    });
  });
}
