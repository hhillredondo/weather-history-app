import 'package:flutter_test/flutter_test.dart';
import 'package:weather_history/util/weather_code.dart';

void main() {
  group('weatherCodeLabel', () {
    test('null maps to em-dash', () {
      expect(weatherCodeLabel(null), '—');
    });

    test('representative codes map to expected labels', () {
      expect(weatherCodeLabel(0), 'Clear');
      expect(weatherCodeLabel(2), 'Partly cloudy');
      expect(weatherCodeLabel(45), 'Fog');
      expect(weatherCodeLabel(53), 'Drizzle');
      expect(weatherCodeLabel(63), 'Rain');
      expect(weatherCodeLabel(73), 'Snow');
      expect(weatherCodeLabel(81), 'Rain showers');
      expect(weatherCodeLabel(95), 'Thunderstorm');
    });

    test('unknown codes expose the value', () {
      expect(weatherCodeLabel(999), 'Code 999');
    });
  });

  group('compassFromDegrees', () {
    test('cardinal points', () {
      expect(compassFromDegrees(0), 'N');
      expect(compassFromDegrees(90), 'E');
      expect(compassFromDegrees(180), 'S');
      expect(compassFromDegrees(270), 'W');
    });

    test('handles wrap-around and nulls', () {
      expect(compassFromDegrees(360), 'N');
      expect(compassFromDegrees(-45), 'NW');
      expect(compassFromDegrees(null), '—');
    });

    test('intercardinal points round to nearest', () {
      expect(compassFromDegrees(45), 'NE');
      expect(compassFromDegrees(135), 'SE');
      expect(compassFromDegrees(225), 'SW');
      expect(compassFromDegrees(315), 'NW');
    });
  });
}
