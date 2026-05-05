import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_history/screens/chat_screen.dart';
import 'package:weather_history/state/app_state.dart';
import 'package:weather_history/state/auth_state.dart';
import 'package:weather_history/theme/app_theme.dart';

class _FakeAuth extends AuthState {
  _FakeAuth({required bool signedIn}) : _signedIn = signedIn;
  final bool _signedIn;
  @override
  bool get isSignedIn => _signedIn;
  @override
  Future<void> load() async {}
}

Future<void> _pumpChat(WidgetTester tester, {required bool signedIn}) async {
  SharedPreferences.setMockInitialValues({});
  await AppState.instance.load();
  final auth = _FakeAuth(signedIn: signedIn);

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
  testWidgets('empty state renders header and example prompts when signed-in',
      (tester) async {
    await _pumpChat(tester, signedIn: true);

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

  testWidgets('composer is present with the prompt hint when signed-in',
      (tester) async {
    await _pumpChat(tester, signedIn: true);

    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text('Ask about historical weather…'),
      findsOneWidget,
    );
  });

  testWidgets(
    'signed-out users see the sign-in prompt and no composer',
    (tester) async {
      await _pumpChat(tester, signedIn: false);

      expect(find.text('Sign in to chat'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    },
  );
}
