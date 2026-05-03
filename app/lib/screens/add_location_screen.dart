import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/open_meteo_geocoding.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Search for a place via Open-Meteo geocoding and add it to saved locations.
class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final _geo = OpenMeteoGeocoding();
  final _controller = TextEditingController();
  List<GeocodingHit> _hits = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() {
      _searching = true;
      _hits = [];
      _error = null;
    });
    try {
      final hits = await _geo.search(_controller.text);
      if (mounted) setState(() => _hits = hits);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addHit(GeocodingHit hit) async {
    final app = context.read<AppState>();
    final id = app.newId();
    final loc = hit.toSavedLocation(id);
    await app.addLocation(loc);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add a location')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: tokens.pillSurface,
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.search_rounded, color: tokens.mutedText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search city or place',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: _runSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        tooltip: 'Search',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: _hits.isEmpty && !_searching
                  ? _Hint(text: 'Type a place name and press search.')
                  : ListView.separated(
                      itemCount: _hits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final h = _hits[i];
                        return _HitTile(hit: h, onTap: () => _addHit(h));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final GeocodingHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    final theme = Theme.of(context);
    final subtitle = [
      if (hit.admin1 != null && hit.admin1!.isNotEmpty) hit.admin1!,
      if (hit.countryCode != null && hit.countryCode!.isNotEmpty)
        hit.countryCode!,
    ].join(', ');
    return Material(
      color: tokens.pillSurface,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.name, style: theme.textTheme.titleMedium),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
