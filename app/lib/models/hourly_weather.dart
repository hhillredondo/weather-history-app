/// One row from Open-Meteo `hourly` arrays (Historical API).
class HourlyWeatherRow {
  HourlyWeatherRow({
    required this.time,
    this.tempC,
    this.precipitationMm,
    this.weatherCode,
    this.windSpeedKmh,
    this.windDirectionDeg,
    this.cloudCoverPct,
    this.relativeHumidityPct,
    this.uvIndex,
  });

  final DateTime time;
  final double? tempC;
  final double? precipitationMm;
  final int? weatherCode;
  final double? windSpeedKmh;
  final double? windDirectionDeg;
  final int? cloudCoverPct;
  final int? relativeHumidityPct;
  final double? uvIndex;

  /// Parses Open-Meteo archive JSON root (must include `hourly` object).
  static List<HourlyWeatherRow> fromOpenMeteoRoot(Map<String, dynamic> root) {
    final hourly = root['hourly'];
    if (hourly is! Map<String, dynamic>) return [];

    final times = hourly['time'] as List<dynamic>?;
    if (times == null || times.isEmpty) return [];

    final t2 = hourly['temperature_2m'] as List<dynamic>?;
    final pr = hourly['precipitation'] as List<dynamic>?;
    final wc = hourly['weather_code'] as List<dynamic>?;
    final ws = hourly['wind_speed_10m'] as List<dynamic>?;
    final wd = hourly['wind_direction_10m'] as List<dynamic>?;
    final cc = hourly['cloud_cover'] as List<dynamic>?;
    final rh = hourly['relative_humidity_2m'] as List<dynamic>?;
    final uv = hourly['uv_index'] as List<dynamic>?;

    final out = <HourlyWeatherRow>[];
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.parse(times[i] as String);
      out.add(HourlyWeatherRow(
        time: t,
        tempC: _dbl(t2, i),
        precipitationMm: _dbl(pr, i),
        weatherCode: _intg(wc, i),
        windSpeedKmh: _dbl(ws, i),
        windDirectionDeg: _dbl(wd, i),
        cloudCoverPct: _intg(cc, i),
        relativeHumidityPct: _intg(rh, i),
        uvIndex: _dbl(uv, i),
      ));
    }
    return out;
  }

  static double? _dbl(List<dynamic>? list, int i) {
    if (list == null || i >= list.length) return null;
    final v = list[i];
    if (v == null) return null;
    return (v as num).toDouble();
  }

  static int? _intg(List<dynamic>? list, int i) {
    if (list == null || i >= list.length) return null;
    final v = list[i];
    if (v == null) return null;
    return (v as num).round();
  }
}
