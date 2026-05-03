import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/daily_weather.dart';
import '../models/saved_location.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/weather_code.dart';
import 'weather_icon_badge.dart';

/// Pill-shaped row for one [SavedLocation] in the home list.
///
/// Layout: round weather badge · name + condition + min/max · trailing big
/// temperature. When [summary] is null we show neutral placeholders rather
/// than empty space so the pill keeps its silhouette while data loads.
class LocationPillTile extends StatelessWidget {
  const LocationPillTile({
    super.key,
    required this.location,
    required this.settings,
    required this.summary,
    this.onTap,
    this.onLongPress,
  });

  final SavedLocation location;
  final AppSettings settings;
  final DailyWeather? summary;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);

    final condition = weatherCodeLabel(summary?.weatherCode);
    final range = summary == null
        ? '—'
        : '${formatTemp(summary!.tempMaxC, settings)} '
            '${formatTemp(summary!.tempMinC, settings)}';
    final headline = summary == null
        ? '—'
        : formatTemp(summary!.tempMaxC ?? summary!.tempMinC, settings);
    final uv = summary?.uvIndexMax;

    return Material(
      color: tokens.pillSurface,
      borderRadius: const BorderRadius.all(Radius.circular(36)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: const BorderRadius.all(Radius.circular(36)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 22, 14),
          child: Row(
            children: [
              WeatherIconBadge(weatherCode: summary?.weatherCode),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      condition,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                    ),
                    Text(
                      range,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                    ),
                    if (uv != null)
                      Text(
                        'UV ${uv.toStringAsFixed(1)} · ${uvBand(uv)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                headline,
                style: theme.textTheme.headlineLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
