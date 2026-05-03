import 'package:flutter_test/flutter_test.dart';
import 'package:weather_history/models/daily_weather.dart';
import 'package:weather_history/models/hourly_weather.dart';

void main() {
  test('DailyWeather parses new UV and wind-direction fields', () {
    final rows = DailyWeather.fromArchiveDailyJson({
      'time': ['2024-06-01', '2024-06-02'],
      'temperature_2m_max': [22.0, 18.5],
      'temperature_2m_min': [14.0, 11.0],
      'precipitation_sum': [0.0, 2.3],
      'weather_code': [1, 63],
      'wind_speed_10m_max': [10.0, 14.4],
      'wind_direction_10m_dominant': [180.0, 270.0],
      'uv_index_max': [6.1, 3.0],
    });

    expect(rows, hasLength(2));
    expect(rows.first.tempMaxC, 22.0);
    expect(rows.first.windDirectionDominantDeg, 180.0);
    expect(rows.first.uvIndexMax, 6.1);
    expect(rows.last.weatherCode, 63);
  });

  test('HourlyWeatherRow parses humidity and uv fields', () {
    final rows = HourlyWeatherRow.fromOpenMeteoRoot({
      'hourly': {
        'time': ['2024-06-01T00:00', '2024-06-01T01:00'],
        'temperature_2m': [14.0, 13.2],
        'precipitation': [0.0, 0.0],
        'weather_code': [2, 2],
        'wind_speed_10m': [5.0, 4.2],
        'wind_direction_10m': [200.0, 210.0],
        'cloud_cover': [80, 75],
        'relative_humidity_2m': [90, 88],
        'uv_index': [0.0, 0.0],
      },
    });

    expect(rows, hasLength(2));
    expect(rows.first.relativeHumidityPct, 90);
    expect(rows.first.cloudCoverPct, 80);
    expect(rows.first.uvIndex, 0.0);
  });

  test('HourlyWeatherRow handles missing hourly payload gracefully', () {
    expect(HourlyWeatherRow.fromOpenMeteoRoot({}), isEmpty);
  });
}
