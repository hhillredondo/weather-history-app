import 'package:flutter/material.dart';

/// WMO weather interpretation codes (Open-Meteo / ECMWF convention).
/// See Open-Meteo Historical API docs — table linked from parameter `weather_code`.
String weatherCodeLabel(int? code) {
  if (code == null) return '—';
  if (code == 0) return 'Clear';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 55) return 'Drizzle';
  if (code >= 56 && code <= 57) return 'Freezing drizzle';
  if (code >= 61 && code <= 65) return 'Rain';
  if (code >= 66 && code <= 67) return 'Freezing rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 85 && code <= 86) return 'Snow showers';
  if (code >= 95 && code <= 99) return 'Thunderstorm';
  return 'Code $code';
}

/// Filled, rounded Material icon representative of a WMO weather code.
///
/// Filled glyphs read as bold tokens against the dark circular badge used in
/// the location pills and forecast rows.
IconData weatherCodeIcon(int? code) {
  if (code == null) return Icons.help_rounded;
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code == 1) return Icons.wb_sunny_rounded;
  if (code == 2) return Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 57) return Icons.grain_rounded;
  if (code >= 61 && code <= 67) return Icons.water_drop_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
  if (code >= 85 && code <= 86) return Icons.cloudy_snowing;
  if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
  return Icons.help_rounded;
}

/// Compass cardinal for a bearing in degrees (0 = N, clockwise).
String compassFromDegrees(double? degrees) {
  if (degrees == null) return '—';
  const cardinals = [
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW',
  ];
  final idx = (((degrees % 360) / 45).round()) % 8;
  return cardinals[idx];
}
