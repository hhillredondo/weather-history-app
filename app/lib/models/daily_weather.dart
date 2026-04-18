import 'package:intl/intl.dart';

/// One row from Open-Meteo `daily` arrays (see Historical Weather API docs).
class DailyWeather {
  DailyWeather({
    required this.date,
    required this.tempMaxC,
    required this.tempMinC,
    required this.precipitationSumMm,
    required this.weatherCode,
    required this.windSpeedMaxKmh,
  });

  final DateTime date;
  final double? tempMaxC;
  final double? tempMinC;
  final double? precipitationSumMm;
  final int? weatherCode;
  final double? windSpeedMaxKmh;

  static List<DailyWeather> fromArchiveDailyJson(Map<String, dynamic> json) {
    final times = json['time'] as List<dynamic>?;
    if (times == null || times.isEmpty) return [];

    final maxT = json['temperature_2m_max'] as List<dynamic>?;
    final minT = json['temperature_2m_min'] as List<dynamic>?;
    final precip = json['precipitation_sum'] as List<dynamic>?;
    final codes = json['weather_code'] as List<dynamic>?;
    final windMax = json['wind_speed_10m_max'] as List<dynamic>?;

    final fmt = DateFormat('yyyy-MM-dd');
    final out = <DailyWeather>[];
    for (var i = 0; i < times.length; i++) {
      final d = fmt.parseStrict(times[i] as String);
      out.add(DailyWeather(
        date: d,
        tempMaxC: _doubleAt(maxT, i),
        tempMinC: _doubleAt(minT, i),
        precipitationSumMm: _doubleAt(precip, i),
        weatherCode: _intAt(codes, i),
        windSpeedMaxKmh: _doubleAt(windMax, i),
      ));
    }
    return out;
  }

  static double? _doubleAt(List<dynamic>? list, int i) {
    if (list == null || i >= list.length) return null;
    final v = list[i];
    if (v == null) return null;
    return (v as num).toDouble();
  }

  static int? _intAt(List<dynamic>? list, int i) {
    if (list == null || i >= list.length) return null;
    final v = list[i];
    if (v == null) return null;
    return (v as num).round();
  }
}
