import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
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
          final theme = Theme.of(context);
          final tokens = WeatherTokens.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const AccountSection(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('Units', style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              Material(
                color: tokens.pillSurface,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Temperature'),
                      subtitle: Text(s.useCelsius ? 'Celsius' : 'Fahrenheit'),
                      value: s.useCelsius,
                      onChanged: (v) =>
                          app.setSettings(s.copyWith(useCelsius: v)),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                    ListTile(
                      title: const Text('Wind speed'),
                      trailing: DropdownButton<WindUnit>(
                        value: s.windUnit,
                        underline: const SizedBox.shrink(),
                        onChanged: (v) {
                          if (v != null) {
                            app.setSettings(s.copyWith(windUnit: v));
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                              value: WindUnit.kmh, child: Text('km/h')),
                          DropdownMenuItem(
                              value: WindUnit.mph, child: Text('mph')),
                          DropdownMenuItem(
                              value: WindUnit.ms, child: Text('m/s')),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                    ListTile(
                      title: const Text('Precipitation'),
                      trailing: DropdownButton<PrecipUnit>(
                        value: s.precipUnit,
                        underline: const SizedBox.shrink(),
                        onChanged: (v) {
                          if (v != null) {
                            app.setSettings(s.copyWith(precipUnit: v));
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                              value: PrecipUnit.mm, child: Text('mm')),
                          DropdownMenuItem(
                              value: PrecipUnit.inch, child: Text('inches')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Weather data © Open-Meteo, CC-BY 4.0. '
                  'See open-meteo.com for licence and attribution.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
