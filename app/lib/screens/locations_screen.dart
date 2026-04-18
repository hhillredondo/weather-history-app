import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/open_meteo_geocoding.dart';
import '../state/app_state.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _geo = OpenMeteoGeocoding();
  final _searchController = TextEditingController();
  List<GeocodingHit> _hits = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() {
      _searching = true;
      _hits = [];
    });
    try {
      final hits = await _geo.search(_searchController.text);
      if (mounted) setState(() => _hits = hits);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addHit(GeocodingHit hit) async {
    final app = AppState.instance;
    final id = app.newId();
    await app.addLocation(hit.toSavedLocation(id));
    await app.setFavourite(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved & set as favourite: ${hit.name}')),
      );
      setState(() => _hits = []);
      _searchController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locations')),
      body: Consumer<AppState>(
        builder: (context, app, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search city or place',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _searching ? null : _runSearch,
                      child: _searching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
              if (_hits.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: _hits.length,
                    itemBuilder: (context, i) {
                      final h = _hits[i];
                      return ListTile(
                        title: Text(h.name),
                        subtitle: Text(
                          [
                            if (h.admin1 != null) h.admin1!,
                            if (h.countryCode != null) h.countryCode!,
                          ].join(', '),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () => _addHit(h),
                          child: const Text('Add'),
                        ),
                      );
                    },
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Saved (${app.locations.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Expanded(
                flex: _hits.isEmpty ? 1 : 3,
                child: app.locations.isEmpty
                    ? ListView(
                        children: const [
                          ListTile(
                            subtitle: Text(
                              'No saved places. Search above to add one — '
                              'the favourite is used on Home and Calendar.',
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: app.locations.length,
                        itemBuilder: (context, i) {
                          final loc = app.locations[i];
                          final isFav = app.favouriteLocationId == loc.id;
                          return ListTile(
                            title: Text(loc.name),
                            subtitle: Text(loc.subtitle),
                            leading: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: isFav
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            onTap: () => app.setFavourite(loc.id),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Remove place?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(c, true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) await app.removeLocation(loc.id);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
