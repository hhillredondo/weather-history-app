import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_history/main.dart';
import 'package:weather_history/services/weather_repository.dart';
import 'package:weather_history/state/app_state.dart';
import 'package:weather_history/state/auth_state.dart';

void main() {
  testWidgets('shows weather title on home', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    final auth = AuthState();
    await auth.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: AppState.instance),
          ChangeNotifierProvider<AuthState>.value(value: auth),
          ProxyProvider<AuthState, WeatherRepository>(
            update: (_, a, _) => WeatherRepository(a),
          ),
        ],
        child: const WeatherHistoryApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Historical Weather'), findsOneWidget);
  });
}
