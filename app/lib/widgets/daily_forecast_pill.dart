import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/daily_weather.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/weather_code.dart';
import 'weather_icon_badge.dart';

/// Pill row for one day in a multi-day forecast list.
class DailyForecastPill extends StatelessWidget {
  const DailyForecastPill({
    super.key,
    required this.day,
    required this.settings,
    this.highlight = false,
    this.onTap,
  });

  final DailyWeather day;
  final AppSettings settings;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    final weekdayFmt = DateFormat('EEE');
    final dateFmt = DateFormat('d MMM');

    return Material(
      color: highlight ? tokens.pillSurfaceHigh : tokens.pillSurface,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 20, 12),
          child: Row(
            children: [
              WeatherIconBadge(weatherCode: day.weatherCode, size: 38),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weekdayFmt.format(day.date),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${dateFmt.format(day.date)} · '
                      '${weatherCodeLabel(day.weatherCode)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (day.uvIndexMax != null)
                      Text(
                        'UV ${day.uvIndexMax!.toStringAsFixed(1)} · '
                        '${uvBand(day.uvIndexMax!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTemp(day.tempMaxC, settings),
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    formatTemp(day.tempMinC, settings),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
