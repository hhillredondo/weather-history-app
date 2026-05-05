import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_weather.dart';
import '../models/saved_location.dart';
import '../services/weather_repository.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/location_pill_tile.dart';
import 'add_location_screen.dart';
import 'chat_screen.dart';
import 'location_weather_screen.dart';
import 'settings_screen.dart';
import 'weather_timeline_utils.dart';

/// Default screen: pill-list of every saved location with a one-day summary.
class HomeLocationsScreen extends StatefulWidget {
  const HomeLocationsScreen({super.key});

  @override
  State<HomeLocationsScreen> createState() => _HomeLocationsScreenState();
}

class _HomeLocationsScreenState extends State<HomeLocationsScreen> {
  final Map<String, Future<DailyWeather?>> _summaries = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    _ensureSummaries(app.locations);
  }

  void _ensureSummaries(List<SavedLocation> locations) {
    for (final loc in locations) {
      _summaries.putIfAbsent(loc.id, () => _loadSummary(loc));
    }
  }

  Future<DailyWeather?> _loadSummary(SavedLocation loc) async {
    final repo = context.read<WeatherRepository>();
    final (start, end) = pastDaysEndingYesterday(1);
    try {
      final rows = await repo.fetchDailyRange(
        latitude: loc.latitude,
        longitude: loc.longitude,
        start: start,
        end: end,
      );
      return rows.isEmpty ? null : rows.last;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshAll() async {
    final app = context.read<AppState>();
    setState(() {
      _summaries.clear();
      for (final loc in app.locations) {
        _summaries[loc.id] = _loadSummary(loc);
      }
    });
    await Future.wait(_summaries.values);
  }

  void _openLocation(SavedLocation loc) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LocationWeatherScreen(location: loc),
      ),
    );
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AddLocationScreen()),
    );
    if (mounted) {
      final app = context.read<AppState>();
      _ensureSummaries(app.locations);
      setState(() {});
    }
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  void _openChat() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }

  Future<void> _confirmRemove(SavedLocation loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove location?'),
        content: Text('Remove ${loc.name} from your saved places?'),
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
    final app = context.read<AppState>();
    await app.removeLocation(loc.id);
    setState(() => _summaries.remove(loc.id));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historical Weather'),
        actions: [
          IconButton(
            tooltip: 'Ask the archive',
            onPressed: _openChat,
            icon: const Icon(Icons.smart_toy_rounded),
          ),
          const SizedBox(width: 4),
          _ProfileChip(
            signedIn: auth.isSignedIn,
            onTap: _openSettings,
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        tooltip: 'Add a location',
        child: const Icon(Icons.search_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: app.locations.isEmpty
            ? const _EmptyHome()
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: app.locations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final loc = app.locations[i];
                  final future = _summaries[loc.id];
                  return FutureBuilder<DailyWeather?>(
                    future: future,
                    builder: (context, snapshot) {
                      return LocationPillTile(
                        location: loc,
                        settings: app.settings,
                        summary: snapshot.data,
                        onTap: () => _openLocation(loc),
                        onLongPress: () => _confirmRemove(loc),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.signedIn, required this.onTap});

  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    final fg = Theme.of(context).colorScheme.onSurface;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tokens.pillSurfaceHigh,
          shape: BoxShape.circle,
          border: Border.all(
            color: signedIn ? fg : tokens.mutedText,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.settings_rounded,
          size: 20,
          color: fg,
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 80),
      children: [
        Icon(
          Icons.location_searching_rounded,
          size: 64,
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(height: 16),
        Text(
          'No locations yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the search button to add a city — '
          'each one will show its past 14 days when you open it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
