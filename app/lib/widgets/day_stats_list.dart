import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/daily_weather.dart';
import '../models/hourly_weather.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/weather_code.dart';
import 'weather_icon_badge.dart';

/// Compact summary panel of daily stats: precipitation, wind, sunrise/sunset,
/// UV index, humidity. Rendered as plain rows on a single rounded surface
/// rather than the icon-grid tiles from the reference UI.
class DayStatsList extends StatelessWidget {
  const DayStatsList({
    super.key,
    required this.day,
    required this.settings,
    this.hourly,
  });

  final DailyWeather day;
  final AppSettings settings;
  final List<HourlyWeatherRow>? hourly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    final timeFmt = DateFormat.Hm();
    final humidity = _averageHumidity(hourly);

    final onSurface = theme.colorScheme.onSurface;
    final rows = <_StatRow>[
      _StatRow(
        icon: Icons.water_drop_rounded,
        iconColor: WeatherIconColors.rain,
        label: 'Precipitation',
        value: formatPrecipMm(day.precipitationSumMm, settings),
      ),
      _StatRow(
        icon: Icons.air_rounded,
        iconColor: onSurface,
        label: 'Wind',
        value: '${formatWindKmh(day.windSpeedMaxKmh, settings)} '
            '${compassFromDegrees(day.windDirectionDominantDeg)}',
      ),
      if (day.sunrise != null || day.sunset != null)
        _StatRow(
          icon: Icons.wb_twilight_rounded,
          iconColor: WeatherIconColors.sun,
          label: 'Sunrise · Sunset',
          value: _formatSunTimes(day.sunrise, day.sunset, timeFmt),
        ),
      if (day.uvIndexMax case final uv?)
        _StatRow(
          icon: Icons.wb_sunny_rounded,
          iconColor: WeatherIconColors.sun,
          label: 'UV index',
          value: '${uv.toStringAsFixed(1)} · ${uvBand(uv)}',
        ),
      if (humidity != null)
        _StatRow(
          icon: Icons.opacity_rounded,
          iconColor: WeatherIconColors.rain,
          label: 'Humidity (avg)',
          value: '$humidity%',
        ),
    ];

    return Material(
      color: tokens.pillSurface,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _StatTile(row: rows[i]),
              if (i != rows.length - 1)
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  indent: 56,
                  endIndent: 16,
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatSunTimes(
    DateTime? sunrise,
    DateTime? sunset,
    DateFormat fmt,
  ) {
    final r = sunrise == null ? '—' : fmt.format(sunrise);
    final s = sunset == null ? '—' : fmt.format(sunset);
    return '$r · $s';
  }

  static int? _averageHumidity(List<HourlyWeatherRow>? hourly) {
    if (hourly == null || hourly.isEmpty) return null;
    final values = hourly
        .map((r) => r.relativeHumidityPct)
        .whereType<int>()
        .toList();
    if (values.isEmpty) return null;
    final sum = values.fold<int>(0, (a, b) => a + b);
    return (sum / values.length).round();
  }
}

class _StatRow {
  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.row});

  final _StatRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Icon(row.icon, color: row.iconColor, size: 22),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              row.label,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Text(
            row.value,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
