import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_weather.dart';
import '../services/open_meteo_archive.dart';
import '../state/app_state.dart';
import '../widgets/daily_weather_list_body.dart';
import 'weather_timeline_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = OpenMeteoArchive();
  late Future<List<DailyWeather>> _future;
  String? _lastLocationId;

  @override
  void initState() {
    super.initState();
    final app = AppState.instance;
    _lastLocationId = app.effectiveLocation.id;
    app.addListener(_onAppLocationChanged);
    _future = _load();
  }

  void _onAppLocationChanged() {
    final id = AppState.instance.effectiveLocation.id;
    if (id != _lastLocationId) {
      _lastLocationId = id;
      setState(() {
        _future = _load();
      });
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
    final range = pastFifteenDaysEndingYesterday();
    return _api.fetchDaily(
      latitude: loc.latitude,
      longitude: loc.longitude,
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
    return Consumer<AppState>(
      builder: (context, app, _) {
        final loc = app.effectiveLocation;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Past 15 days'),
            actions: [
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
                  leading: const Icon(Icons.place_outlined),
                  title: Text(loc.name),
                  subtitle: Text(loc.subtitle),
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
                          children: const [
                            ListTile(title: Text('No data')),
                          ],
                        );
                      }

                      return DailyWeatherListBody(
                        days: days,
                        settings: app.settings,
                        footer: Text(
                          'Weather data © Open-Meteo (CC-BY 4.0). '
                          'Ending yesterday — today is not included.',
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
