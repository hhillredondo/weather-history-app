/// Default map centre (London) until saved locations / GPS exist.
abstract final class AppConfig {
  static const double defaultLatitude = 51.5074;
  static const double defaultLongitude = -0.1278;

  /// Open-Meteo Historical Archive — non-commercial free tier (monitor usage;
  /// commercial "API Standard" adds historical + customer endpoints — see open-meteo.com/pricing).
  static const String openMeteoArchiveBase =
      'https://archive-api.open-meteo.com/v1/archive';
}
