import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';

enum _AuthMode { none, login, register }

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
  bool _messageIsError = false;
  _AuthMode _mode = _AuthMode.none;
  bool _awaitingConfirmation = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn,
      {String? successMessage, String? failurePrefix}) async {
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      await fn();
      if (mounted) {
        setState(() {
          _message = successMessage;
          _messageIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final friendly = _friendlyAuthError(e);
          _message =
              failurePrefix == null ? friendly : '$failurePrefix $friendly';
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _messageColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _messageIsError ? scheme.error : scheme.primary;
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _message = null;
      _messageIsError = false;
      _awaitingConfirmation = false;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        if (!auth.isConfigured) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Account is off. Run the app with dart-define values for '
                'COGNITO_REGION, COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID, and '
                'API_BASE_URL (see README).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }

        if (auth.isSignedIn) {
          final email = auth.email;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Account', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    email == null || email.isEmpty
                        ? 'Signed in'
                        : 'Signed in as $email',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_message != null && _message!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _message!,
                      style: TextStyle(color: _messageColor(context)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _run(() => auth.signOut()),
                      child: const Text('Sign out'),
                    ),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _mode == _AuthMode.login
                          ? FilledButton(
                              onPressed: _busy ? null : () => _switchMode(_AuthMode.login),
                              child: const Text('Login'),
                            )
                          : OutlinedButton(
                              onPressed: _busy ? null : () => _switchMode(_AuthMode.login),
                              child: const Text('Login'),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _mode == _AuthMode.register
                          ? FilledButton(
                              onPressed: _busy ? null : () => _switchMode(_AuthMode.register),
                              child: const Text('Register'),
                            )
                          : OutlinedButton(
                              onPressed: _busy ? null : () => _switchMode(_AuthMode.register),
                              child: const Text('Register'),
                            ),
                    ),
                  ],
                ),
                if (_mode != _AuthMode.none) ...[
                  const SizedBox(height: 16),
                  _buildForm(context, auth),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(BuildContext context, AuthState auth) {
    final isLogin = _mode == _AuthMode.login;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (!isLogin && _awaitingConfirmation) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Confirmation code (from email)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
        ],
        if (_message != null && _message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: TextStyle(color: _messageColor(context)),
          ),
        ],
        const SizedBox(height: 12),
        if (isLogin)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => auth.signIn(_email.text.trim(), _password.text),
                    ),
            child: const Text('Login'),
          )
        else if (_awaitingConfirmation)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () async {
                            await auth.confirmSignUp(
                              _email.text.trim(),
                              _code.text.trim(),
                            );
                            await auth.signIn(_email.text.trim(), _password.text);
                          },
                          successMessage: 'Email confirmed — signed in.',
                        ),
                child: const Text('Confirm email'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _awaitingConfirmation = false),
                child: const Text('Back'),
              ),
            ],
          )
        else
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () async {
                        await auth.signUp(_email.text.trim(), _password.text);
                        if (mounted) {
                          setState(() => _awaitingConfirmation = true);
                        }
                      },
                      successMessage:
                          'Check your email for a confirmation code.',
                    ),
            child: const Text('Register'),
          ),
      ],
    );
  }
}

String _friendlyAuthError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('notauthorizedexception') ||
      lower.contains('incorrect username or password')) {
    return 'Incorrect email or password.';
  }
  if (lower.contains('usernotfoundexception')) {
    return 'No account exists for that email.';
  }
  if (lower.contains('usernotconfirmedexception')) {
    return 'Please confirm your email first using the code we sent you.';
  }
  if (lower.contains('codemismatchexception')) {
    return 'That confirmation code is incorrect.';
  }
  if (lower.contains('expiredcodeexception')) {
    return 'That confirmation code has expired. Request a new one.';
  }
  if (lower.contains('usernameexistsexception')) {
    return 'An account already exists for that email. Try logging in.';
  }
  if (lower.contains('invalidpasswordexception')) {
    return 'Password is too weak. Use at least 8 characters with letters and numbers.';
  }
  if (lower.contains('invalidparameterexception')) {
    return 'That email or password isn\'t valid.';
  }
  if (lower.contains('limitexceededexception') ||
      lower.contains('toomanyrequestsexception')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception')) {
    return 'Network error. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
