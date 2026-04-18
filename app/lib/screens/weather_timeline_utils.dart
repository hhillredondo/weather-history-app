/// Default window: 15 calendar days ending **yesterday** (not including today).
(DateTime start, DateTime end) pastFifteenDaysEndingYesterday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final start = yesterday.subtract(const Duration(days: 14));
  return (start, yesterday);
}

/// Ideal calendar window: centre **±7** (15 calendar days inclusive).
(DateTime start, DateTime end) fifteenDaysAround(DateTime centerDay) {
  final d = DateTime(centerDay.year, centerDay.month, centerDay.day);
  return (
    d.subtract(const Duration(days: 7)),
    d.add(const Duration(days: 7)),
  );
}

/// Same window as [fifteenDaysAround], but **clamped for Open-Meteo Archive**:
/// the archive has no future days, so the end date must not be after **yesterday**
/// (local calendar day). Otherwise the API returns HTTP 400.
(DateTime start, DateTime end) fifteenDaysAroundArchive(
  DateTime centerDay,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(centerDay.year, centerDay.month, centerDay.day);
  var start = d.subtract(const Duration(days: 7));
  var end = d.add(const Duration(days: 7));
  if (end.isAfter(yesterday)) {
    end = yesterday;
  }
  if (start.isAfter(end)) {
    start = end;
  }
  return (start, end);
}
