import 'calendar_months.dart';

/// Local due dates for each installment of a deferred card purchase.
///
/// [graceMonths] full billing cycles skipped before the first payment. Whether
/// the purchase month counts as the first grace cycle depends on [cardCutDay]:
/// if the purchase calendar day is strictly before [cardCutDay], that month is
/// within the grace window; otherwise the purchase month is treated as past the
/// cut and an extra month is skipped before counting grace.
///
/// Each installment uses the purchase calendar day (same as [purchaseLocal]'s
/// day, clamped to the target month's length). Time-of-day matches
/// [purchaseLocal]. Cut day still drives which billing cycle months apply.
List<DateTime> scheduleDeferredCreditInstallmentsLocal({
  required DateTime purchaseLocal,
  required int graceMonths,
  required int termMonths,
  required int cardCutDay,
}) {
  if (termMonths < 2) {
    throw ArgumentError.value(termMonths, 'termMonths', 'must be at least 2');
  }
  if (graceMonths < 0) {
    throw ArgumentError.value(graceMonths, 'graceMonths', 'must be non-negative');
  }

  final beforeCut = purchaseLocal.day < cardCutDay;
  final extraCycleSkip = beforeCut ? 0 : 1;
  final monthsToFirstPayment = graceMonths + extraCycleSkip;

  final p = purchaseLocal;
  final monthStart = DateTime(
    p.year,
    p.month,
    1,
    p.hour,
    p.minute,
    p.second,
    p.millisecond,
    p.microsecond,
  );
  final firstMonth = addCalendarMonths(monthStart, monthsToFirstPayment);

  DateTime withPurchaseDayOnCalendarMonth(DateTime ymd) {
    final y = ymd.year;
    final m = ymd.month;
    final last = DateTime(y, m + 1, 0).day;
    final d = p.day.clamp(1, last);
    return DateTime(
      y,
      m,
      d,
      p.hour,
      p.minute,
      p.second,
      p.millisecond,
      p.microsecond,
    );
  }

  final firstDue = withPurchaseDayOnCalendarMonth(firstMonth);
  return List.generate(
    termMonths,
    (i) => addCalendarMonths(firstDue, i),
  );
}
