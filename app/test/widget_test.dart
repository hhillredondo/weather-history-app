import 'package:flutter_test/flutter_test.dart';

import 'package:weather_history/main.dart';

void main() {
  testWidgets('shows app bar title', (WidgetTester tester) async {
    await tester.pumpWidget(const WeatherHistoryApp());
    expect(find.text('Weather history'), findsOneWidget);
  });
}
