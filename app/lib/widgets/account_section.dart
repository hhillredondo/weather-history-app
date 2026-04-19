import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backend_api.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';

class AccountSection extends StatefulWidget {
  const AccountSection({super.key});

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await fn();
      if (mounted) setState(() => _message = 'Done.');
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthState, AppState>(
      builder: (context, auth, app, _) {
        if (!auth.isConfigured) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Cloud sync is off. Run the app with dart-define values for '
                'COGNITO_REGION, COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID, and '
                'API_BASE_URL (see README).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }

        if (auth.isSignedIn) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Account', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Signed in',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_message != null) Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await BackendApi(auth).pullIntoApp(app);
                                }),
                        child: const Text('Pull from cloud'),
                      ),
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await BackendApi(auth).pushAll(app);
                                }),
                        child: const Text('Push to cloud'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => auth.signOut()),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Account', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation code (after sign up)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await auth.signIn(_email.text.trim(), _password.text);
                                await BackendApi(auth).pullIntoApp(app);
                              }),
                      child: const Text('Sign in'),
                    ),
                    FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _run(() => auth.signUp(
                                _email.text.trim(),
                                _password.text,
                              )),
                      child: const Text('Sign up'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => auth.confirmSignUp(
                                _email.text.trim(),
                                _code.text.trim(),
                              )),
                      child: const Text('Confirm email'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
