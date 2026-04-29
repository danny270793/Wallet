/// Calendar elapsed from purchase to [endedAt] or today; omits fractional sub-day jitter.
///
/// Returns `null` if [endedAt ?? now] falls before purchase (wall dates).
typedef AssetHoldingYmd = ({int years, int months, int days});

/// Returns calendar y/m/d for [boughtAt] → [endedAt ?? now].
/// `null` if the end wall date is before start.
AssetHoldingYmd? assetHoldingCalendarYmd(DateTime boughtAt, DateTime? endedAt) {
  final start = _calendarDateLocal(boughtAt);
  final end = _calendarDateLocal(endedAt ?? DateTime.now());

  if (end.isBefore(start)) {
    return null;
  }

  var years = end.year - start.year;
  var months = end.month - start.month;
  var days = end.day - start.day;

  if (days < 0) {
    months -= 1;
    final prevMonthLastDay = DateTime(end.year, end.month, 0).day;
    days += prevMonthLastDay;
  }

  if (months < 0) {
    years -= 1;
    months += 12;
  }

  return (years: years, months: months, days: days);
}

/// Rough “calendar months held” using whole y/m plus leftover days scaled by avg month (~30.4375 days).
///
/// Matches intuitive cases such as exactly `2m` → divisor `2`; `200 / 2 = 100` per mo.
///
/// Returns `null` when the holding length is effectively zero calendar days (`0y 0m 0d`) or inverted.
double? assetValuePerApproximateCalendarMonth(double value, DateTime boughtAt, DateTime? endedAt) {
  final ymd = assetHoldingCalendarYmd(boughtAt, endedAt);
  if (ymd == null) {
    return null;
  }

  final y = ymd.years;
  final m = ymd.months;
  final d = ymd.days;

  if (y == 0 && m == 0 && d == 0) {
    return null;
  }

  const avgDaysPerGregorianMonth = 30.4375;
  final monthsDenom = y * 12.0 + m + d / avgDaysPerGregorianMonth;

  if (monthsDenom <= 0) {
    return null;
  }

  return value / monthsDenom;
}

/// Calendar-length holding period between two wall dates (local), formatted compactly:
/// `1y 3m 5d`; omit zero high-order units (`3m 5d`, `5d`, `3m`).
String formatAssetHoldingDurationYmd(DateTime boughtAt, DateTime? endedAt) {
  final ymd = assetHoldingCalendarYmd(boughtAt, endedAt);
  if (ymd == null) {
    return '0d';
  }

  final y = ymd.years;
  final m = ymd.months;
  final d = ymd.days;

  final parts = <String>[];
  if (y > 0) {
    parts.add('${y}y');
  }
  if (m > 0) {
    parts.add('${m}m');
  }
  if (d > 0) {
    parts.add('${d}d');
  }
  if (parts.isEmpty) {
    return '0d';
  }
  return parts.join(' ');
}

DateTime _calendarDateLocal(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}
