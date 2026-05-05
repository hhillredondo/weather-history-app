import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_history/models/daily_weather.dart';
import 'package:weather_history/models/hourly_weather.dart';
import 'package:weather_history/models/saved_location.dart';
import 'package:weather_history/screens/home_locations_screen.dart';
import 'package:weather_history/services/weather_repository.dart';
import 'package:weather_history/state/app_state.dart';
import 'package:weather_history/state/auth_state.dart';
import 'package:weather_history/theme/app_theme.dart';

class _FakeWeatherRepository extends WeatherRepository {
  _FakeWeatherRepository(super.auth, this._daily);

  final DailyWeather _daily;

  @override
  Future<List<DailyWeather>> fetchDailyRange({
    required double latitude,
    required double longitude,
    required DateTime start,
    required DateTime end,
    String timezone = 'auto',
  }) async {
    return [_daily];
  }

  @override
  Future<List<HourlyWeatherRow>> fetchHourlyForDay({
    required double latitude,
    required double longitude,
    required DateTime day,
    String timezone = 'auto',
  }) async {
    return [];
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required AppState app,
  required AuthState auth,
  required WeatherRepository repo,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<AuthState>.value(value: auth),
        Provider<WeatherRepository>.value(value: repo),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const HomeLocationsScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('empty state shows the no-locations placeholder', (tester) async {
    await AppState.instance.load();
    final auth = AuthState();
    await auth.load();
    final repo = _FakeWeatherRepository(
      auth,
      DailyWeather(
        date: DateTime(2024, 7, 1),
        tempMaxC: 20,
        tempMinC: 10,
        precipitationSumMm: 0,
        weatherCode: 1,
        windSpeedMaxKmh: 5,
      ),
    );

    await _pumpHome(tester, app: AppState.instance, auth: auth, repo: repo);
    await tester.pump();

    expect(find.text('Historical Weather'), findsOneWidget);
    expect(find.text('No locations yet'), findsOneWidget);
  });

  testWidgets('renders a saved location pill when one is present', (tester) async {
    await AppState.instance.load();
    // Inject a location directly to avoid persistence side effects.
    await AppState.instance.addLocation(
      SavedLocation(
        id: 'madrid',
        name: 'Madrid',
        latitude: 40.4,
        longitude: -3.7,
        countryCode: 'ES',
        admin1: 'Madrid',
      ),
    );
    addTearDown(() => AppState.instance.removeLocation('madrid'));

    final auth = AuthState();
    await auth.load();
    final repo = _FakeWeatherRepository(
      auth,
      DailyWeather(
        date: DateTime(2024, 7, 1),
        tempMaxC: 32.0,
        tempMinC: 18.0,
        precipitationSumMm: 0,
        weatherCode: 0,
        windSpeedMaxKmh: 8,
      ),
    );

    await _pumpHome(tester, app: AppState.instance, auth: auth, repo: repo);
    // First frame; futures haven't resolved.
    await tester.pump();
    // Let the FutureBuilder for the location summary settle.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Madrid'), findsOneWidget);
  });

  testWidgets('shows the chat and settings actions', (tester) async {
    await AppState.instance.load();
    final auth = AuthState();
    await auth.load();
    final repo = _FakeWeatherRepository(
      auth,
      DailyWeather(
        date: DateTime(2024, 7, 1),
        tempMaxC: 20,
        tempMinC: 10,
        precipitationSumMm: 0,
        weatherCode: 1,
        windSpeedMaxKmh: 5,
      ),
    );

    await _pumpHome(tester, app: AppState.instance, auth: auth, repo: repo);
    await tester.pump();

    expect(find.byTooltip('Ask the archive'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    expect(find.byTooltip('Add a location'), findsOneWidget);
  });
}
