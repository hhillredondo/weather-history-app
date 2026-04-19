/// Compile-time configuration for AWS Cognito + HTTP API.
///
/// Example (web/desktop/mobile):
/// `flutter run --dart-define=COGNITO_REGION=eu-west-1 --dart-define=COGNITO_USER_POOL_ID=xx \
///   --dart-define=COGNITO_CLIENT_ID=yy --dart-define=API_BASE_URL=https://xxxx.execute-api.../`
abstract final class AwsConfig {
  static const String region =
      String.fromEnvironment('COGNITO_REGION', defaultValue: '');
  static const String userPoolId =
      String.fromEnvironment('COGNITO_USER_POOL_ID', defaultValue: '');
  static const String clientId =
      String.fromEnvironment('COGNITO_CLIENT_ID', defaultValue: '');
  /// Base URL of the HTTP API (no trailing slash), e.g. https://abc.execute-api.eu-west-1.amazonaws.com
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static bool get isConfigured =>
      region.isNotEmpty &&
      userPoolId.isNotEmpty &&
      clientId.isNotEmpty &&
      apiBaseUrl.isNotEmpty;
}
