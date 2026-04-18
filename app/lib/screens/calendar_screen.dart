import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/daily_weather.dart';
import '../services/open_meteo_archive.dart';
import '../state/app_state.dart';
import '../widgets/daily_weather_list_body.dart';
import 'weather_timeline_utils.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _api = OpenMeteoArchive();
  late DateTime _centerDay;
  late Future<List<DailyWeather>> _future;
  String? _lastLocationId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _centerDay = today.subtract(const Duration(days: 1));
    final app = AppState.instance;
    _lastLocationId = app.effectiveLocation.id;
    app.addListener(_onAppLocationChanged);
    _future = _load();
  }

  void _onAppLocationChanged() {
    final id = AppState.instance.effectiveLocation.id;
    if (id != _lastLocationId) {
      _lastLocationId = id;
      setState(() => _future = _load());
    }
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppLocationChanged);
    super.dispose();
  }

  Future<List<DailyWeather>> _load() async {
    final app = AppState.instance;
    final loc = app.effectiveLocation;
    final range = fifteenDaysAroundArchive(_centerDay);
    return _api.fetchDaily(
      latitude: loc.latitude,
      longitude: loc.longitude,
      start: range.$1,
      end: range.$2,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: _centerDay.isAfter(yesterday) ? yesterday : _centerDay,
      firstDate: DateTime(1940),
      lastDate: yesterday,
      helpText: 'Choose centre day (±7 days shown)',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _centerDay = DateTime(picked.year, picked.month, picked.day);
      _future = _load();
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final headerFmt = DateFormat.yMMMEd();

    return Consumer<AppState>(
      builder: (context, app, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Calendar'),
            actions: [
              IconButton(
                tooltip: 'Pick day',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.date_range),
                  title: Text('Centre: ${headerFmt.format(_centerDay)}'),
                  subtitle: Text(
                    '${DateFormat.yMd().format(fifteenDaysAroundArchive(_centerDay).$1)} – '
                    '${DateFormat.yMd().format(fifteenDaysAroundArchive(_centerDay).$2)} '
                    '(archive ends yesterday)',
                  ),
                  onTap: _pickDate,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: FutureBuilder<List<DailyWeather>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(
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
                            Icon(Icons.cloud_off,
                                size: 48,
                                color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 16),
                            Text('${snapshot.error}'),
                          ],
                        );
                      }
                      final days = snapshot.data ?? [];
                      if (days.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            ListTile(title: Text('No data')),
                          ],
                        );
                      }
                      return DailyWeatherListBody(
                        days: days,
                        settings: app.settings,
                        footer: Text(
                          '15-day window around the selected day (±7). '
                          '© Open-Meteo (CC-BY 4.0).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
