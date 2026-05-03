import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/daily_weather.dart';
import '../models/hourly_weather.dart';
import '../models/saved_location.dart';
import '../services/weather_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/weather_code.dart';
import '../widgets/day_stats_list.dart';
import '../widgets/weather_icon_badge.dart';

/// Hourly drill-down for a single day from the Open-Meteo archive.
class DayDetailScreen extends StatefulWidget {
  const DayDetailScreen({
    super.key,
    required this.location,
    required this.day,
  });

  final SavedLocation location;
  final DailyWeather day;

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  Future<List<HourlyWeatherRow>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<HourlyWeatherRow>> _load() {
    final repo = context.read<WeatherRepository>();
    return repo.fetchHourlyForDay(
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
      day: widget.day.date,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().settings;
    final dateFmt = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(title: Text(dateFmt.format(widget.day.date))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<HourlyWeatherRow>>(
          future: _future,
          builder: (context, snapshot) {
            final hourly = snapshot.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _DaySummary(
                  location: widget.location,
                  day: widget.day,
                  settings: settings,
                ),
                const SizedBox(height: 24),
                _SectionLabel(text: 'Conditions'),
                const SizedBox(height: 8),
                DayStatsList(
                  day: widget.day,
                  settings: settings,
                  hourly: hourly,
                ),
                const SizedBox(height: 24),
                _SectionLabel(text: 'Hourly'),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    hourly == null)
                  const _LoadingTile()
                else if (snapshot.hasError)
                  _ErrorTile(error: snapshot.error)
                else if (hourly == null || hourly.isEmpty)
                  const _EmptyTile()
                else
                  _HourlyList(rows: hourly, settings: settings),
                const SizedBox(height: 16),
                const _Attribution(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.location,
    required this.day,
    required this.settings,
  });

  final SavedLocation location;
  final DailyWeather day;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    final headline = formatTemp(day.tempMaxC ?? day.tempMinC, settings);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: tokens.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              WeatherIconBadge(weatherCode: day.weatherCode, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  weatherCodeLabel(day.weatherCode),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(headline, style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(
            'High ${formatTemp(day.tempMaxC, settings)} · '
            'Low ${formatTemp(day.tempMinC, settings)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyList extends StatelessWidget {
  const _HourlyList({required this.rows, required this.settings});

  final List<HourlyWeatherRow> rows;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    return Material(
      color: tokens.pillSurface,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _HourTile(row: rows[i], settings: settings),
              if (i != rows.length - 1)
                Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.4),
                  indent: 64,
                  endIndent: 16,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({required this.row, required this.settings});

  final HourlyWeatherRow row;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    final timeFmt = DateFormat.Hm();
    final details = <String>[
      formatPrecipMm(row.precipitationMm, settings),
      '${formatWindKmh(row.windSpeedKmh, settings)} '
          '${compassFromDegrees(row.windDirectionDeg)}',
      if (row.relativeHumidityPct != null) '${row.relativeHumidityPct}% RH',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
      child: Row(
        children: [
          WeatherIconBadge(weatherCode: row.weatherCode, size: 36),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              timeFmt.format(row.time),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: Text(
              details.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.mutedText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatTemp(row.tempC, settings),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: tokens.pillSurface,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile();

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.pillSurface,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Text(
        'No hourly data for this day.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WeatherTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.pillSurface,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Could not load hourly data',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$error', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'Weather data © Open-Meteo (CC-BY 4.0).',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.mutedText,
            ),
      ),
    );
  }
}
