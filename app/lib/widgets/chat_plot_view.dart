import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';

/// Renders a [ChatPlot] (line or bar) inside a chat bubble.
class ChatPlotView extends StatelessWidget {
  const ChatPlotView({super.key, required this.plot});

  final ChatPlot plot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: tokens.pillSurfaceHigh,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plot.title, style: theme.textTheme.titleMedium),
          if (plot.yLabel case final yLabel? when yLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              yLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: plot.kind == PlotKind.bar ? _BarChart(plot: plot) : _LineChart(plot: plot),
          ),
          if (plot.series.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                for (var i = 0; i < plot.series.length; i++)
                  _LegendDot(label: plot.series[i].label, color: _seriesColor(theme, i)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Color _seriesColor(ThemeData theme, int i) {
  const palette = [
    Color(0xFF5BA9FF),
    Color(0xFFFFC23C),
    Color(0xFF8AB4F8),
  ];
  return palette[i % palette.length];
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.plot});
  final ChatPlot plot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    final allPoints = plot.series.expand((s) => s.points).toList();
    if (allPoints.isEmpty) {
      return Center(
        child: Text('No data', style: theme.textTheme.bodySmall),
      );
    }
    final labels = plot.series.first.points.map((p) => p.x).toList();
    final ys = allPoints.map((p) => p.y).toList();
    final yMin = ys.reduce((a, b) => a < b ? a : b);
    final yMax = ys.reduce((a, b) => a > b ? a : b);
    final pad = (yMax - yMin).abs() * 0.1 + 0.5;
    final xInterval = labels.length <= 4 ? 1.0 : (labels.length / 4).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: yMin - pad,
        maxY: yMax + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: theme.textTheme.labelSmall?.copyWith(color: tokens.mutedText),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                final lbl = labels[i];
                final short = lbl.length > 8 ? lbl.substring(lbl.length - 5) : lbl;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: theme.textTheme.labelSmall?.copyWith(color: tokens.mutedText)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          for (var i = 0; i < plot.series.length; i++)
            LineChartBarData(
              isCurved: true,
              curveSmoothness: 0.2,
              barWidth: 2.5,
              color: _seriesColor(theme, i),
              dotData: const FlDotData(show: false),
              spots: [
                for (var x = 0; x < plot.series[i].points.length; x++)
                  FlSpot(x.toDouble(), plot.series[i].points[x].y),
              ],
            ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.plot});
  final ChatPlot plot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    if (plot.series.isEmpty || plot.series.first.points.isEmpty) {
      return Center(child: Text('No data', style: theme.textTheme.bodySmall));
    }
    final s = plot.series.first;
    final ys = s.points.map((p) => p.y).toList();
    final yMax = ys.reduce((a, b) => a > b ? a : b);
    final yMin = ys.reduce((a, b) => a < b ? a : b);
    final yLo = yMin > 0 ? 0.0 : yMin * 1.1;
    final yHi = yMax * 1.1;
    final xInterval = s.points.length <= 6 ? 1.0 : (s.points.length / 6).ceilToDouble();

    return BarChart(
      BarChartData(
        minY: yLo,
        maxY: yHi,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: theme.textTheme.labelSmall?.copyWith(color: tokens.mutedText),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= s.points.length) return const SizedBox.shrink();
                final lbl = s.points[i].x;
                final short = lbl.length > 6 ? lbl.substring(lbl.length - 4) : lbl;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: theme.textTheme.labelSmall?.copyWith(color: tokens.mutedText)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < s.points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: s.points[i].y,
                  color: _seriesColor(theme, 0),
                  width: 10,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
