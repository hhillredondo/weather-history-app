import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../state/app_state.dart';
import '../widgets/account_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<AppState>(
        builder: (context, app, _) {
          final s = app.settings;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AccountSection(),
              const SizedBox(height: 16),
              Text('Units', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Temperature'),
                subtitle: Text(s.useCelsius ? 'Celsius' : 'Fahrenheit'),
                value: s.useCelsius,
                onChanged: (v) => app.setSettings(s.copyWith(useCelsius: v)),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Wind speed'),
                trailing: DropdownButton<WindUnit>(
                  value: s.windUnit,
                  onChanged: (v) {
                    if (v != null) app.setSettings(s.copyWith(windUnit: v));
                  },
                  items: const [
                    DropdownMenuItem(value: WindUnit.kmh, child: Text('km/h')),
                    DropdownMenuItem(value: WindUnit.mph, child: Text('mph')),
                    DropdownMenuItem(value: WindUnit.ms, child: Text('m/s')),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Precipitation'),
                trailing: DropdownButton<PrecipUnit>(
                  value: s.precipUnit,
                  onChanged: (v) {
                    if (v != null) app.setSettings(s.copyWith(precipUnit: v));
                  },
                  items: const [
                    DropdownMenuItem(value: PrecipUnit.mm, child: Text('mm')),
                    DropdownMenuItem(
                      value: PrecipUnit.inch,
                      child: Text('inches'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Weather data © Open-Meteo, CC-BY 4.0. '
                'See open-meteo.com for licence and attribution.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
