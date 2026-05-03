import 'package:flutter_test/flutter_test.dart';
import 'package:weather_history/models/app_settings.dart';
import 'package:weather_history/util/units.dart';

void main() {
  const metric = AppSettings.defaults;
  const imperial = AppSettings(
    useCelsius: false,
    windUnit: WindUnit.mph,
    precipUnit: PrecipUnit.inch,
  );

  group('temperature formatting', () {
    test('formats Celsius by default', () {
      expect(formatTemp(20.4, metric), '20°C');
      expect(formatTemp(null, metric), '—');
    });

    test('converts to Fahrenheit when disabled', () {
      expect(formatTemp(0, imperial), '32°F');
      expect(formatTemp(100, imperial), '212°F');
    });

    test('range falls back to whichever side is present', () {
      expect(formatTempRange(null, null, metric), '—');
      expect(formatTempRange(10, null, metric), '10°C');
      expect(formatTempRange(null, 5, metric), '5°C');
      expect(formatTempRange(30, 20, metric), '30°C / 20°C');
    });
  });

  group('wind formatting', () {
    test('km/h default', () => expect(formatWindKmh(10, metric), '10 km/h'));
    test('mph conversion', () {
      expect(formatWindKmh(100, imperial), '62 mph');
    });
    test('m/s conversion', () {
      const msSettings = AppSettings(
        useCelsius: true,
        windUnit: WindUnit.ms,
        precipUnit: PrecipUnit.mm,
      );
      expect(formatWindKmh(36, msSettings), '10.0 m/s');
    });
    test('null renders dash', () => expect(formatWindKmh(null, metric), '—'));
  });

  group('precipitation formatting', () {
    test('mm default', () {
      expect(formatPrecipMm(2.5, metric), '2.5 mm');
    });
    test('inches conversion', () {
      expect(formatPrecipMm(25.4, imperial), '1.00 in');
    });
    test('null renders dash', () {
      expect(formatPrecipMm(null, metric), '—');
    });
  });
}
