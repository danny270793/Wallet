/// Calendar-length holding period between two wall dates (local), formatted compactly:
/// `1y 3m 5d`; omit zero high-order units (`3m 5d`, `5d`, `3m`).
String formatAssetHoldingDurationYmd(DateTime boughtAt, DateTime? endedAt) {
  final start = _calendarDateLocal(boughtAt);
  final endRaw = endedAt ?? DateTime.now();
  final end = _calendarDateLocal(endRaw);

  if (end.isBefore(start)) {
    return '0d';
  }

  var y = end.year - start.year;
  var m = end.month - start.month;
  var d = end.day - start.day;

  if (d < 0) {
    m -= 1;
    final prevMonthLastDay = DateTime(end.year, end.month, 0).day;
    d += prevMonthLastDay;
  }

  if (m < 0) {
    y -= 1;
    m += 12;
  }

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
