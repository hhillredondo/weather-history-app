import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/daily_weather.dart';

/// Client for [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api).
/// v1 calls the public archive host — no API key. Rate limits apply on the free tier; this client does not throttle (you monitor usage externally).
class OpenMeteoArchive {
  OpenMeteoArchive({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Inclusive date range [start]..[end] (calendar days in the given timezone context — we send ISO `yyyy-MM-dd`).
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
      'daily': [
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_sum',
        'weather_code',
        'wind_speed_10m_max',
      ].join(','),
    });

    final res = await _http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw OpenMeteoException(
        'HTTP ${res.statusCode}',
        body: res.body,
      );
    }

    final map = json.decode(res.body) as Map<String, dynamic>;
    if (map['error'] == true) {
      throw OpenMeteoException(
        map['reason']?.toString() ?? 'Unknown API error',
        body: res.body,
      );
    }

    final daily = map['daily'];
    if (daily is! Map<String, dynamic>) {
      throw const OpenMeteoException('Missing daily payload');
    }

    return DailyWeather.fromArchiveDailyJson(daily);
  }
}

class OpenMeteoException implements Exception {
  const OpenMeteoException(this.message, {this.body});

  final String message;
  final String? body;

  @override
  String toString() => 'OpenMeteoException: $message';
}
