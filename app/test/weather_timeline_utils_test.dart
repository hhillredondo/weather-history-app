import 'package:flutter_test/flutter_test.dart';
import 'package:weather_history/screens/weather_timeline_utils.dart';

void main() {
  group('pastDaysEndingYesterday', () {
    test('ends yesterday, spans requested number of calendar days', () {
      final (start, end) = pastDaysEndingYesterday(14);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      expect(end, yesterday);
      expect(end.difference(start).inDays, 13);
    });
  });

  group('pastDaysEndingOn', () {
    test('14 days ending on a specific date', () {
      final picked = DateTime(2013, 12, 30);
      final (start, end) = pastDaysEndingOn(picked, 14);
      expect(end, DateTime(2013, 12, 30));
      expect(start, DateTime(2013, 12, 17));
      expect(end.difference(start).inDays, 13);
    });
  });

  group('pastDaysEndingOnArchive', () {
    test('clamps end to yesterday when picked date is in the future', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final (_, end) = pastDaysEndingOnArchive(
        today.add(const Duration(days: 30)),
        14,
      );
      expect(end, yesterday);
    });

    test('leaves the full range for picks far in the past', () {
      final (start, end) =
          pastDaysEndingOnArchive(DateTime(2000, 1, 15), 14);
      expect(end, DateTime(2000, 1, 15));
      expect(start, DateTime(2000, 1, 2));
    });
  });
}
