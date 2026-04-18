/// Persisted user preferences (units). Values map to Open-Meteo request params when we delegate to API units; otherwise we convert in UI from metric API responses.
class AppSettings {
  const AppSettings({
    required this.useCelsius,
    required this.windUnit,
    required this.precipUnit,
  });

  final bool useCelsius;

  /// Display / request style for wind: metric uses km/h from API as-is.
  final WindUnit windUnit;
  final PrecipUnit precipUnit;

  static const AppSettings defaults = AppSettings(
    useCelsius: true,
    windUnit: WindUnit.kmh,
    precipUnit: PrecipUnit.mm,
  );

  AppSettings copyWith({
    bool? useCelsius,
    WindUnit? windUnit,
    PrecipUnit? precipUnit,
  }) {
    return AppSettings(
      useCelsius: useCelsius ?? this.useCelsius,
      windUnit: windUnit ?? this.windUnit,
      precipUnit: precipUnit ?? this.precipUnit,
    );
  }

  Map<String, dynamic> toJson() => {
        'useCelsius': useCelsius,
        'windUnit': windUnit.name,
        'precipUnit': precipUnit.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    WindUnit w = WindUnit.kmh;
    try {
      w = WindUnit.values.byName(json['windUnit'] as String? ?? 'kmh');
    } catch (_) {}
    PrecipUnit p = PrecipUnit.mm;
    try {
      p = PrecipUnit.values.byName(json['precipUnit'] as String? ?? 'mm');
    } catch (_) {}
    return AppSettings(
      useCelsius: json['useCelsius'] as bool? ?? true,
      windUnit: w,
      precipUnit: p,
    );
  }
}

enum WindUnit { kmh, mph, ms }

enum PrecipUnit { mm, inch }
