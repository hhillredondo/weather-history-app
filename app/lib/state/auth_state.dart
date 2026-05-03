import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/aws_config.dart';
import '../services/cognito_identity_service.dart';

const _kAccess = 'cognito_access_token';
const _kRefresh = 'cognito_refresh_token';
const _kId = 'cognito_id_token';

class AuthState extends ChangeNotifier {
  AuthState() : _cognito = CognitoIdentityService();

  final CognitoIdentityService _cognito;
  final _storage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  String? _idToken;

  bool get isConfigured => AwsConfig.isConfigured;
  bool get isSignedIn {
    final t = _accessToken;
    return t != null && t.isNotEmpty;
  }

  String? get accessToken => _accessToken;

  Future<void> load() async {
    if (!isConfigured) {
      notifyListeners();
      return;
    }
    _accessToken = await _storage.read(key: _kAccess);
    _refreshToken = await _storage.read(key: _kRefresh);
    _idToken = await _storage.read(key: _kId);
    notifyListeners();
  }

  Future<void> _persistTokens(TokenBundle t) async {
    _accessToken = t.accessToken;
    _refreshToken = t.refreshToken;
    _idToken = t.idToken;
    await _storage.write(key: _kAccess, value: t.accessToken);
    await _storage.write(key: _kRefresh, value: t.refreshToken);
    if (t.idToken != null) {
      await _storage.write(key: _kId, value: t.idToken!);
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final t = await _cognito.signIn(email: email, password: password);
    await _persistTokens(t);
  }

  Future<void> signUp(String email, String password) async {
    await _cognito.signUp(email: email, password: password);
  }

  Future<void> confirmSignUp(String email, String code) async {
    await _cognito.confirmSignUp(email: email, code: code);
  }

  Future<void> signOut() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kId);
    _accessToken = null;
    _refreshToken = null;
    _idToken = null;
    notifyListeners();
  }

  /// Refresh access token using refresh token; no-op if unavailable.
  Future<bool> refreshAccessToken() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final t = await _cognito.refresh(refreshToken: refresh);
      await _persistTokens(t);
      return true;
    } catch (_) {
      await signOut();
      return false;
    }
  }

  /// Sub claim from ID token (JWT payload), if present.
  String? get idTokenSub => _idTokenClaim('sub');

  /// Email claim from ID token (JWT payload), if present.
  String? get email => _idTokenClaim('email');

  String? _idTokenClaim(String key) {
    final id = _idToken;
    if (id == null) return null;
    try {
      final parts = id.split('.');
      if (parts.length < 2) return null;
      final payload = utf8.decode(_decodeJwtBytes(parts[1]));
      final map = json.decode(payload) as Map<String, dynamic>;
      return map[key] as String?;
    } catch (_) {
      return null;
    }
  }
}

List<int> _decodeJwtBytes(String segment) {
  var s = segment;
  final pad = s.length % 4;
  if (pad > 0) {
    s = s.padRight(s.length + (4 - pad), '=');
  }
  return base64Url.decode(s);
}
