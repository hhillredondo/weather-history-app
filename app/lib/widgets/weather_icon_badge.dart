import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../util/weather_code.dart';

/// Colour palette for weather glyphs by category.
class WeatherIconColors {
  WeatherIconColors._();

  static const Color sun = Color(0xFFFFC23C);
  static const Color cloud = Color(0xFFEDEDED);
  static const Color rain = Color(0xFF5BA9FF);
  static const Color snow = Color(0xFFEDEDED);
  static const Color storm = Color(0xFFB497FF);
  static const Color fog = Color(0xFFB8BCC4);
  static const Color unknown = Color(0xFFB8BCC4);
}

/// Colour for the icon glyph based on the WMO weather code.
Color colorForWeatherCode(int? code) {
  if (code == null) return WeatherIconColors.unknown;
  if (code == 0 || code == 1) return WeatherIconColors.sun;
  if (code == 2 || code == 3) return WeatherIconColors.cloud;
  if (code == 45 || code == 48) return WeatherIconColors.fog;
  if (code >= 51 && code <= 67) return WeatherIconColors.rain;
  if (code >= 71 && code <= 77) return WeatherIconColors.snow;
  if (code >= 80 && code <= 82) return WeatherIconColors.rain;
  if (code >= 85 && code <= 86) return WeatherIconColors.snow;
  if (code >= 95 && code <= 99) return WeatherIconColors.storm;
  return WeatherIconColors.unknown;
}

/// Round badge showing a weather glyph in the accent colour.
///
/// Used in location pills and forecast rows. Styled to roughly match the
/// "yellow sun on dark circle" motif from the reference Pixel UI without
/// shipping bespoke illustrations.
class WeatherIconBadge extends StatelessWidget {
  const WeatherIconBadge({
    super.key,
    required this.weatherCode,
    this.size = 44,
  });

  final int? weatherCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = WeatherTokens.of(context);
    final iconSize = size * 0.62;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.iconCircleBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        weatherCodeIcon(weatherCode),
        color: colorForWeatherCode(weatherCode),
        size: iconSize,
      ),
    );
  }
}
