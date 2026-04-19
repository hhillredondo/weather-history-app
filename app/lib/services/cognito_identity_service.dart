import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/aws_config.dart';

class TokenBundle {
  TokenBundle({
    required this.accessToken,
    required this.refreshToken,
    this.idToken,
  });

  final String accessToken;
  final String refreshToken;
  final String? idToken;
}

/// Minimal Cognito IDP client over HTTPS (no Amplify). Uses USER_PASSWORD_AUTH.
class CognitoIdentityService {
  static final _targetHeader = {
    'Content-Type': 'application/x-amz-json-1.1',
  };

  Uri get _endpoint => Uri.parse(
        'https://cognito-idp.${AwsConfig.region}.amazonaws.com/',
      );

  Future<TokenBundle> signIn({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _endpoint,
      headers: {
        ..._targetHeader,
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
      },
      body: jsonEncode({
        'AuthFlow': 'USER_PASSWORD_AUTH',
        'ClientId': AwsConfig.clientId,
        'AuthParameters': {
          'USERNAME': email,
          'PASSWORD': password,
        },
      }),
    );
    _throwIfError(res);
    final map = json.decode(res.body) as Map<String, dynamic>;
    final auth = map['AuthenticationResult'] as Map<String, dynamic>?;
    if (auth == null) {
      throw Exception('No AuthenticationResult: ${res.body}');
    }
    return TokenBundle(
      accessToken: auth['AccessToken'] as String,
      refreshToken: auth['RefreshToken'] as String,
      idToken: auth['IdToken'] as String?,
    );
  }

  Future<TokenBundle> refresh({required String refreshToken}) async {
    final res = await http.post(
      _endpoint,
      headers: {
        ..._targetHeader,
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
      },
      body: jsonEncode({
        'AuthFlow': 'REFRESH_TOKEN_AUTH',
        'ClientId': AwsConfig.clientId,
        'AuthParameters': {
          'REFRESH_TOKEN': refreshToken,
        },
      }),
    );
    _throwIfError(res);
    final map = json.decode(res.body) as Map<String, dynamic>;
    final auth = map['AuthenticationResult'] as Map<String, dynamic>?;
    if (auth == null) throw Exception('No AuthenticationResult');
    return TokenBundle(
      accessToken: auth['AccessToken'] as String,
      refreshToken: refreshToken,
      idToken: auth['IdToken'] as String?,
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _endpoint,
      headers: {
        ..._targetHeader,
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.SignUp',
      },
      body: jsonEncode({
        'ClientId': AwsConfig.clientId,
        'Username': email,
        'Password': password,
        'UserAttributes': [
          {'Name': 'email', 'Value': email},
        ],
      }),
    );
    _throwIfError(res);
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    final res = await http.post(
      _endpoint,
      headers: {
        ..._targetHeader,
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmSignUp',
      },
      body: jsonEncode({
        'ClientId': AwsConfig.clientId,
        'Username': email,
        'ConfirmationCode': code,
      }),
    );
    _throwIfError(res);
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    Map<String, dynamic>? map;
    try {
      map = json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    final msg = map?['__type'] != null
        ? '${map!['__type']}: ${map['message']}'
        : res.body;
    throw Exception(msg);
  }
}
