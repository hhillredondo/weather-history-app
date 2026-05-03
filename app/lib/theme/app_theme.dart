import 'package:flutter/material.dart';

/// Centralized theme for the weather history app.
///
/// Inspired by modern Pixel-style weather UIs: large temperature typography,
/// rounded "pill" surfaces, and a warm amber accent that reads against both
/// near-black dark and soft cream light backgrounds.
class AppTheme {
  AppTheme._();

  static const Color _amber = Color(0xFFFFC23C);
  static const Color _darkBg = Color(0xFF0F1013);
  static const Color _darkSurface = Color(0xFF1B1C20);
  static const Color _darkSurfaceHigh = Color(0xFF24262B);
  static const Color _lightBg = Color(0xFFF6F4EE);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceHigh = Color(0xFFEFEBE2);

  static ThemeData light() => _build(
        Brightness.light,
        background: _lightBg,
        surface: _lightSurface,
        surfaceHigh: _lightSurfaceHigh,
        onSurface: const Color(0xFF1B1C20),
        onSurfaceMuted: const Color(0xFF5A5C63),
        outline: const Color(0xFFE3DFD4),
        iconCircle: const Color(0xFF15161A),
      );

  static ThemeData dark() => _build(
        Brightness.dark,
        background: _darkBg,
        surface: _darkSurface,
        surfaceHigh: _darkSurfaceHigh,
        onSurface: const Color(0xFFF1F1F3),
        onSurfaceMuted: const Color(0xFF9CA0A8),
        outline: const Color(0xFF2C2E33),
        iconCircle: const Color(0xFF000000),
      );

  static ThemeData _build(
    Brightness brightness, {
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color onSurface,
    required Color onSurfaceMuted,
    required Color outline,
    required Color iconCircle,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: onSurface,
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF15161A)
          : const Color(0xFFFFFFFF),
      secondary: onSurface,
      onSecondary: brightness == Brightness.dark
          ? const Color(0xFF15161A)
          : const Color(0xFFFFFFFF),
      tertiary: const Color(0xFF8AB4F8),
      onTertiary: const Color(0xFF0B1A33),
      error: const Color(0xFFE57373),
      onError: const Color(0xFF2A0F0F),
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceMuted,
      surfaceContainerLowest: background,
      surfaceContainerLow: background,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      outline: outline,
      outlineVariant: outline,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      iconTheme: IconThemeData(color: onSurface),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: surfaceHigh,
        foregroundColor: onSurface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      textTheme: _textTheme(onSurface, onSurfaceMuted),
      extensions: <ThemeExtension<dynamic>>[
        WeatherTokens(
          iconCircleBg: iconCircle,
          iconForeground: _amber,
          pillSurface: surface,
          pillSurfaceHigh: surfaceHigh,
          mutedText: onSurfaceMuted,
          accent: _amber,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Color onSurface, Color muted) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 84,
        fontWeight: FontWeight.w300,
        letterSpacing: -2.0,
        color: onSurface,
        height: 1.0,
      ),
      displayMedium: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.0,
        color: onSurface,
        height: 1.0,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.05,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: muted,
        letterSpacing: 0.2,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: onSurface, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      labelMedium: TextStyle(fontSize: 12, color: muted),
      labelSmall: TextStyle(fontSize: 11, color: muted, letterSpacing: 0.5),
    );
  }
}

/// Custom design tokens that aren't naturally part of [ColorScheme].
@immutable
class WeatherTokens extends ThemeExtension<WeatherTokens> {
  const WeatherTokens({
    required this.iconCircleBg,
    required this.iconForeground,
    required this.pillSurface,
    required this.pillSurfaceHigh,
    required this.mutedText,
    required this.accent,
  });

  final Color iconCircleBg;
  final Color iconForeground;
  final Color pillSurface;
  final Color pillSurfaceHigh;
  final Color mutedText;
  final Color accent;

  @override
  WeatherTokens copyWith({
    Color? iconCircleBg,
    Color? iconForeground,
    Color? pillSurface,
    Color? pillSurfaceHigh,
    Color? mutedText,
    Color? accent,
  }) {
    return WeatherTokens(
      iconCircleBg: iconCircleBg ?? this.iconCircleBg,
      iconForeground: iconForeground ?? this.iconForeground,
      pillSurface: pillSurface ?? this.pillSurface,
      pillSurfaceHigh: pillSurfaceHigh ?? this.pillSurfaceHigh,
      mutedText: mutedText ?? this.mutedText,
      accent: accent ?? this.accent,
    );
  }

  @override
  WeatherTokens lerp(ThemeExtension<WeatherTokens>? other, double t) {
    if (other is! WeatherTokens) return this;
    return WeatherTokens(
      iconCircleBg: Color.lerp(iconCircleBg, other.iconCircleBg, t)!,
      iconForeground: Color.lerp(iconForeground, other.iconForeground, t)!,
      pillSurface: Color.lerp(pillSurface, other.pillSurface, t)!,
      pillSurfaceHigh: Color.lerp(pillSurfaceHigh, other.pillSurfaceHigh, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }

  static WeatherTokens of(BuildContext context) =>
      Theme.of(context).extension<WeatherTokens>()!;
}
