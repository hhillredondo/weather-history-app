/// Date range helpers for the Open-Meteo archive.
///
/// The archive end date must be no later than **yesterday** (local) — otherwise
/// the API responds with HTTP 400.

DateTime _yesterday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(const Duration(days: 1));
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Last [days] calendar days ending **yesterday** (today is excluded).
///
/// E.g. `pastDaysEndingYesterday(14)` returns 14 inclusive days.
(DateTime start, DateTime end) pastDaysEndingYesterday(int days) {
  assert(days > 0, 'days must be positive');
  final end = _yesterday();
  final start = end.subtract(Duration(days: days - 1));
  return (start, end);
}

/// Window of [days] calendar days **ending on [end]** (inclusive of [end]).
///
/// E.g. `pastDaysEndingOn(DateTime(2013,12,30), 14)` returns
/// `2013-12-17 .. 2013-12-30`.
(DateTime start, DateTime end) pastDaysEndingOn(DateTime end, int days) {
  assert(days > 0, 'days must be positive');
  final e = _dateOnly(end);
  return (e.subtract(Duration(days: days - 1)), e);
}

/// Same as [pastDaysEndingOn] but clamps the end to **yesterday** if the user
/// picked a date in the future (the Open-Meteo archive has no future days).
(DateTime start, DateTime end) pastDaysEndingOnArchive(
  DateTime end,
  int days,
) {
  final yesterday = _yesterday();
  var e = _dateOnly(end);
  if (e.isAfter(yesterday)) e = yesterday;
  return pastDaysEndingOn(e, days);
}
