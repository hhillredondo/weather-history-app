import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_history/main.dart';
import 'package:weather_history/state/app_state.dart';

void main() {
  testWidgets('shows home title in shell', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState.instance,
        child: const WeatherHistoryApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Past 15 days'), findsOneWidget);
  });
}
