/// Calendar month arithmetic in the same timezone as [date] (use local for UI datetimes).
DateTime addCalendarMonths(DateTime date, int months) {
  final totalMonths = date.year * 12 + (date.month - 1) + months;
  final y = totalMonths ~/ 12;
  final m = totalMonths % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  final d = date.day <= lastDay ? date.day : lastDay;
  return DateTime(
    y,
    m,
    d,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
