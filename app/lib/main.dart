import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_locations_screen.dart';
import 'services/weather_repository.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  final auth = AuthState();
  await auth.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: AppState.instance),
        ChangeNotifierProvider<AuthState>.value(value: auth),
        ProxyProvider<AuthState, WeatherRepository>(
          update: (_, auth, _) => WeatherRepository(auth),
        ),
      ],
      child: const WeatherHistoryApp(),
    ),
  );
}

class WeatherHistoryApp extends StatelessWidget {
  const WeatherHistoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather History',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeLocationsScreen(),
    );
  }
}
