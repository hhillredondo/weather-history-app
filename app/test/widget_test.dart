import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_history/main.dart';
import 'package:weather_history/state/app_state.dart';
import 'package:weather_history/state/auth_state.dart';

void main() {
  testWidgets('shows home title in shell', (WidgetTester tester) async {
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
        ],
        child: const WeatherHistoryApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Past 15 days'), findsOneWidget);
  });
}
