import '../models/app_settings.dart';

double celsiusToFahrenheit(double c) => c * 9 / 5 + 32;

double kmhToMph(double kmh) => kmh * 0.621371;

double mmToInch(double mm) => mm / 25.4;

/// Format temperature for display (API returns °C).
String formatTemp(double? celsius, AppSettings s) {
  if (celsius == null) return '—';
  if (s.useCelsius) return '${celsius.round()}°C';
  return '${celsiusToFahrenheit(celsius).round()}°F';
}

String formatTempRange(double? maxC, double? minC, AppSettings s) {
  if (maxC == null && minC == null) return '—';
  if (maxC != null && minC != null) {
    return '${formatTemp(maxC, s)} / ${formatTemp(minC, s)}';
  }
  return formatTemp(maxC ?? minC, s);
}

/// API wind max is km/h.
String formatWindKmh(double? kmh, AppSettings s) {
  if (kmh == null) return '—';
  return switch (s.windUnit) {
    WindUnit.kmh => '${kmh.round()} km/h',
    WindUnit.mph => '${kmhToMph(kmh).round()} mph',
    WindUnit.ms => '${(kmh / 3.6).toStringAsFixed(1)} m/s',
  };
}

/// API precip sum is mm.
String formatPrecipMm(double? mm, AppSettings s) {
  if (mm == null) return '—';
  return switch (s.precipUnit) {
    PrecipUnit.mm => '${mm.toStringAsFixed(1)} mm',
    PrecipUnit.inch => '${mmToInch(mm).toStringAsFixed(2)} in',
  };
}

/// Plain-language band for a UV index value (WHO scale).
String uvBand(double uv) {
  if (uv < 3) return 'Low';
  if (uv < 6) return 'Moderate';
  if (uv < 8) return 'High';
  if (uv < 11) return 'Very high';
  return 'Extreme';
}
