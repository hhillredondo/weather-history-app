/// Single message in the chat transcript.
///
/// `plots` and `toolCalls` only apply to assistant messages and are populated
/// from the `/v1/chat` response.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.plots = const [],
    this.toolCalls = const [],
  });

  final ChatRole role;
  final String content;
  final List<ChatPlot> plots;
  final List<ChatToolCall> toolCalls;

  Map<String, dynamic> toWireJson() => {
        'role': role.wire,
        'content': content,
      };
}

enum ChatRole {
  user('user'),
  assistant('assistant');

  const ChatRole(this.wire);
  final String wire;
}

/// A chart spec returned by the model's `plot` tool. Rendered client-side.
class ChatPlot {
  const ChatPlot({
    required this.title,
    required this.kind,
    required this.series,
    this.yLabel,
  });

  factory ChatPlot.fromJson(Map<String, dynamic> j) => ChatPlot(
        title: (j['title'] as String?) ?? '',
        kind: (j['kind'] as String?) == 'bar' ? PlotKind.bar : PlotKind.line,
        yLabel: j['y_label'] as String?,
        series: ((j['series'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChatSeries.fromJson)
            .toList(),
      );

  final String title;
  final String? yLabel;
  final PlotKind kind;
  final List<ChatSeries> series;
}

enum PlotKind { line, bar }

class ChatSeries {
  const ChatSeries({required this.label, required this.points});

  factory ChatSeries.fromJson(Map<String, dynamic> j) => ChatSeries(
        label: (j['label'] as String?) ?? '',
        points: ((j['points'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChatPoint.fromJson)
            .toList(),
      );

  final String label;
  final List<ChatPoint> points;
}

class ChatPoint {
  const ChatPoint({required this.x, required this.y});

  factory ChatPoint.fromJson(Map<String, dynamic> j) => ChatPoint(
        x: (j['x'] ?? '').toString(),
        y: (j['y'] as num?)?.toDouble() ?? 0,
      );

  final String x;
  final double y;
}

/// Trace of a single tool invocation (returned for transparency, not chat memory).
class ChatToolCall {
  const ChatToolCall({required this.name, required this.ok, this.input});

  factory ChatToolCall.fromJson(Map<String, dynamic> j) => ChatToolCall(
        name: (j['name'] as String?) ?? '?',
        ok: j['ok'] as bool? ?? true,
        input: j['input'] as Map<String, dynamic>?,
      );

  final String name;
  final bool ok;
  final Map<String, dynamic>? input;
}

/// Successful response from `/v1/chat`.
class ChatReply {
  const ChatReply({
    required this.reply,
    required this.plots,
    required this.toolCalls,
    this.dailyUsed,
    this.dailyLimit,
  });

  factory ChatReply.fromJson(Map<String, dynamic> j) {
    final usage = j['usage'] as Map<String, dynamic>?;
    return ChatReply(
      reply: (j['reply'] as String?) ?? '',
      plots: ((j['plots'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatPlot.fromJson)
          .toList(),
      toolCalls: ((j['tool_calls'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatToolCall.fromJson)
          .toList(),
      dailyUsed: (usage?['daily_used'] as num?)?.toInt(),
      dailyLimit: (usage?['daily_limit'] as num?)?.toInt(),
    );
  }

  final String reply;
  final List<ChatPlot> plots;
  final List<ChatToolCall> toolCalls;
  final int? dailyUsed;
  final int? dailyLimit;
}
