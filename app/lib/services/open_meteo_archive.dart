import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/daily_weather.dart';
import '../models/hourly_weather.dart';

/// Client for [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api).
/// Used for **direct** calls when the backend proxy is not in use.
class OpenMeteoArchive {
  OpenMeteoArchive({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _dailyVars = [
    'temperature_2m_max',
    'temperature_2m_min',
    'precipitation_sum',
    'weather_code',
    'wind_speed_10m_max',
    'wind_direction_10m_dominant',
    'uv_index_max',
    'sunrise',
    'sunset',
  ];

  static const _hourlyVars = [
    'temperature_2m',
    'precipitation',
    'weather_code',
    'wind_speed_10m',
    'wind_direction_10m',
    'cloud_cover',
    'relative_humidity_2m',
    'uv_index',
  ];

  /// Parse a full Open-Meteo archive JSON object (root) into daily rows.
  static List<DailyWeather> dailyListFromOpenMeteoRoot(Map<String, dynamic> root) {
    final daily = root['daily'];
    if (daily is! Map<String, dynamic>) {
      throw const OpenMeteoException('Missing daily payload');
    }
    return DailyWeather.fromArchiveDailyJson(daily);
  }

  static Map<String, dynamic> _decodeJson(http.Response res) {
    if (res.statusCode != 200) {
      developer.log(
        'Open-Meteo HTTP ${res.statusCode}',
        name: 'weather_history.open_meteo',
        level: 1000,
        error: res.body,
      );
      throw OpenMeteoException('HTTP ${res.statusCode}', body: res.body);
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    if (map['error'] == true) {
      final reason = map['reason']?.toString() ?? 'Unknown API error';
      developer.log(
        'Open-Meteo API error: $reason',
        name: 'weather_history.open_meteo',
        level: 1000,
      );
      throw OpenMeteoException(reason, body: res.body);
    }
    return map;
  }

  /// Inclusive date range [start]..[end] (calendar days — we send ISO `yyyy-MM-dd`).
  Future<List<DailyWeather>> fetchDaily({
    required double latitude,
    required double longitude,
    required DateTime start,
    required DateTime end,
    String timezone = 'auto',
  }) async {
    final d = DateFormat('yyyy-MM-dd');
    final uri = Uri.parse(AppConfig.openMeteoArchiveBase).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'start_date': d.format(start),
      'end_date': d.format(end),
      'timezone': timezone,
      'daily': _dailyVars.join(','),
    });

    final res = await _http.get(uri, headers: {'Accept': 'application/json'});
    final map = _decodeJson(res);
    return dailyListFromOpenMeteoRoot(map);
  }

  /// Hourly data for [start]..[end] (often one day: start == end).
  Future<List<HourlyWeatherRow>> fetchHourly({
    required double latitude,
    required double longitude,
    required DateTime start,
    required DateTime end,
    String timezone = 'auto',
  }) async {
    final d = DateFormat('yyyy-MM-dd');
    final uri = Uri.parse(AppConfig.openMeteoArchiveBase).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'start_date': d.format(start),
      'end_date': d.format(end),
      'timezone': timezone,
      'hourly': _hourlyVars.join(','),
    });

    final res = await _http.get(uri, headers: {'Accept': 'application/json'});
    final map = _decodeJson(res);
    return HourlyWeatherRow.fromOpenMeteoRoot(map);
  }
}

class OpenMeteoException implements Exception {
  const OpenMeteoException(this.message, {this.body});

  final String message;
  final String? body;

  @override
  String toString() => 'OpenMeteoException: $message';
}
