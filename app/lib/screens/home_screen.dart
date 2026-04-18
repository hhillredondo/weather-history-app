import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/daily_weather.dart';
import '../services/open_meteo_archive.dart';
import '../util/weather_code.dart';

/// Default window: 15 calendar days ending **yesterday** (not including today).
(DateTime start, DateTime end) pastFifteenDaysEndingYesterday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final start = yesterday.subtract(const Duration(days: 14));
  return (start, yesterday);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = OpenMeteoArchive();
  late Future<List<DailyWeather>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DailyWeather>> _load() async {
    final range = pastFifteenDaysEndingYesterday();
    return _api.fetchDaily(
      latitude: AppConfig.defaultLatitude,
      longitude: AppConfig.defaultLongitude,
      start: range.$1,
      end: range.$2,
    );
  }

  Future<void> _onRefresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMEd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather history'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _onRefresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<DailyWeather>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load weather',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }

            final days = snapshot.data ?? [];
            if (days.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [ListTile(title: Text('No data'))],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: days.length + 1,
              itemBuilder: (context, index) {
                if (index == days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Weather data © Open-Meteo (CC-BY 4.0). '
                      'Default location: London — saved locations & settings coming later.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                final d = days[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(dateFmt.format(d.date)),
                    subtitle: Text(weatherCodeLabel(d.weatherCode)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _tempRange(d),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${d.precipitationSumMm?.toStringAsFixed(1) ?? '—'} mm · '
                          '${d.windSpeedMaxKmh?.round() ?? '—'} km/h max',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _tempRange(DailyWeather d) {
    final a = d.tempMaxC;
    final b = d.tempMinC;
    if (a == null && b == null) return '—';
    if (a != null && b != null) {
      return '${a.round()}° / ${b.round()}°';
    }
    return '${a?.round() ?? b?.round()}°';
  }
}
