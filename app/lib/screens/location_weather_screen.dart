import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/daily_weather.dart';
import '../models/saved_location.dart';
import '../services/weather_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/weather_code.dart';
import '../widgets/daily_forecast_pill.dart';
import '../widgets/weather_icon_badge.dart';
import 'day_detail_screen.dart';
import 'weather_timeline_utils.dart';

/// One location's archive view. Two modes:
///
/// * **Recent** — past 14 days ending yesterday (default).
/// * **Picked** — 14 days ending on a user-picked date.
class LocationWeatherScreen extends StatefulWidget {
  const LocationWeatherScreen({super.key, required this.location});

  final SavedLocation location;

  @override
  State<LocationWeatherScreen> createState() => _LocationWeatherScreenState();
}

class _LocationWeatherScreenState extends State<LocationWeatherScreen> {
  Future<List<DailyWeather>>? _future;
  DateTime? _pickedDay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<DailyWeather>> _load() {
    final repo = context.read<WeatherRepository>();
    final (start, end) = _pickedDay == null
        ? pastDaysEndingYesterday(14)
        : pastDaysEndingOnArchive(_pickedDay!, 14);
    return repo.fetchDailyRange(
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
      start: start,
      end: end,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final initial = _pickedDay ?? yesterday;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(yesterday) ? yesterday : initial,
      firstDate: DateTime(1940),
      lastDate: yesterday,
      helpText: 'Pick a day (shows that day + previous 13)',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedDay = DateTime(picked.year, picked.month, picked.day);
      _future = _load();
    });
  }

  void _clearPicked() {
    setState(() {
      _pickedDay = null;
      _future = _load();
    });
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove location?'),
        content: Text(
          'Remove ${widget.location.name} from your saved places? '
          'This only removes it from this app — the data stays in the archive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().removeLocation(widget.location.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _openDay(DailyWeather day) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DayDetailScreen(location: widget.location, day: day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.name),
        actions: [
          if (_pickedDay != null)
            IconButton(
              tooltip: 'Back to recent 14 days',
              onPressed: _clearPicked,
              icon: const Icon(Icons.history_rounded),
            ),
          IconButton(
            tooltip: 'Pick a day',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: 'Remove location',
            onPressed: _confirmRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DailyWeather>>(
          future: _future,
          builder: (context, snapshot) {
            if (_future == null ||
                (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)) {
              return const _LoadingBody();
            }
            if (snapshot.hasError) {
              return _ErrorBody(error: snapshot.error);
            }
            final days = snapshot.data ?? [];
            if (days.isEmpty) {
              return const _EmptyBody();
            }
            return _LoadedBody(
              location: widget.location,
              days: days,
              pickedDay: _pickedDay,
              settings: app.settings,
              onDayTap: _openDay,
            );
          },
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.location,
    required this.days,
    required this.pickedDay,
    required this.settings,
    required this.onDayTap,
  });

  final SavedLocation location;
  final List<DailyWeather> days;
  final DateTime? pickedDay;
  final AppSettings settings;
  final void Function(DailyWeather day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    final theme = Theme.of(context);

    final featured = days.last;
    final headerLabel = pickedDay == null
        ? 'Past 14 days'
        : '14 days ending ${DateFormat.yMMMd().format(pickedDay!)}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _Hero(location: location, day: featured, settings: settings),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(headerLabel, style: theme.textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        for (final d in days.reversed) ...[
          DailyForecastPill(
            day: d,
            settings: settings,
            highlight: pickedDay != null && _sameDay(d.date, pickedDay!),
            onTap: () => onDayTap(d),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        Text(
          'Weather data © Open-Meteo (CC-BY 4.0). Archive ends yesterday.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Hero extends StatelessWidget {
  const _Hero({
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
    final dateFmt = DateFormat.yMMMEd();
    final headline = formatTemp(day.tempMaxC ?? day.tempMinC, settings);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
          ),
          const SizedBox(height: 6),
          Text(dateFmt.format(day.date), style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WeatherIconBadge(weatherCode: day.weatherCode, size: 56),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  weatherCodeLabel(day.weatherCode),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(headline, style: theme.textTheme.displayLarge),
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 280,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 80),
        Center(child: Text('No data for this range.')),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.cloud_off_rounded,
            size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text('Could not load weather', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('$error', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
