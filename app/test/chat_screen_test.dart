import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_history/screens/chat_screen.dart';
import 'package:weather_history/state/app_state.dart';
import 'package:weather_history/state/auth_state.dart';
import 'package:weather_history/theme/app_theme.dart';

Future<void> _pumpChat(WidgetTester tester) async {
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
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const ChatScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('empty state renders header and example prompts', (tester) async {
    await _pumpChat(tester);

    expect(find.text('Ask the archive'), findsWidgets);
    expect(
      find.textContaining('How hot was July in Lisbon'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Top 5 wettest days'),
      findsOneWidget,
    );
  });

  testWidgets('composer is present with the prompt hint', (tester) async {
    await _pumpChat(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text('Ask about historical weather…'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping send while signed-out surfaces an error',
    (tester) async {
      await _pumpChat(tester);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      // Use the composer's icon button.
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(find.textContaining('Sign in'), findsOneWidget);
    },
  );
}
