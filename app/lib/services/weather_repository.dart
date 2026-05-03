import 'package:intl/intl.dart';

import '../config/aws_config.dart';
import '../models/daily_weather.dart';
import '../models/hourly_weather.dart';
import '../state/auth_state.dart';
import 'backend_api.dart';
import 'open_meteo_archive.dart';

/// Shared weather access: when signed in and [AwsConfig] is set, uses the backend
/// (Lambda → Open-Meteo + DynamoDB cache); otherwise calls Open-Meteo from the device.
class WeatherRepository {
  WeatherRepository(this._auth);

  final AuthState _auth;
  final _direct = OpenMeteoArchive();

  bool get _useBackend => _auth.isSignedIn && AwsConfig.isConfigured;

  Future<List<DailyWeather>> fetchDailyRange({
    required double latitude,
    required double longitude,
    required DateTime start,
    required DateTime end,
    String timezone = 'auto',
  }) async {
    final d = DateFormat('yyyy-MM-dd');
    if (_useBackend) {
      final envelope = await BackendApi(_auth).getWeatherArchive(
        latitude: latitude,
        longitude: longitude,
        startDate: d.format(start),
        endDate: d.format(end),
        hourly: false,
        timezone: timezone,
      );
      final data = envelope['data'] as Map<String, dynamic>;
      return OpenMeteoArchive.dailyListFromOpenMeteoRoot(data);
    }
    return _direct.fetchDaily(
      latitude: latitude,
      longitude: longitude,
      start: start,
      end: end,
      timezone: timezone,
    );
  }

  /// Single calendar day, hourly series (for drill-down).
  Future<List<HourlyWeatherRow>> fetchHourlyForDay({
    required double latitude,
    required double longitude,
    required DateTime day,
    String timezone = 'auto',
  }) async {
    final d = DateFormat('yyyy-MM-dd');
    final dayOnly = DateTime(day.year, day.month, day.day);
    final ds = d.format(dayOnly);
    if (_useBackend) {
      final envelope = await BackendApi(_auth).getWeatherArchive(
        latitude: latitude,
        longitude: longitude,
        startDate: ds,
        endDate: ds,
        hourly: true,
        timezone: timezone,
      );
      final data = envelope['data'] as Map<String, dynamic>;
      return HourlyWeatherRow.fromOpenMeteoRoot(data);
    }
    return _direct.fetchHourly(
      latitude: latitude,
      longitude: longitude,
      start: dayOnly,
      end: dayOnly,
      timezone: timezone,
    );
  }
}
