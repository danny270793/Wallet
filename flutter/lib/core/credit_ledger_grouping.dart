import '../features/transactions/domain/entities/transaction_entity.dart';

/// Groups rows by [TransactionEntity.creditLedgerGroupingKey]; newest groups (by latest date) first.
List<({String id, List<TransactionEntity> rows})> groupedCreditLedger(
  List<TransactionEntity> flat,
) {
  final m = <String, List<TransactionEntity>>{};
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == null || g.isEmpty) continue;
    m.putIfAbsent(g, () => []).add(t);
  }
  for (final rows in m.values) {
    rows.sort((a, b) => a.transactedAt.compareTo(b.transactedAt));
  }
  final out = <({String id, List<TransactionEntity> rows})>[];
  DateTime newest(List<TransactionEntity> r) {
    DateTime mx = r.first.transactedAt;
    for (final x in r) {
      if (x.transactedAt.isAfter(mx)) mx = x.transactedAt;
    }
    return mx;
  }

  final keys = m.keys.toList()
    ..sort((a, b) => newest(m[b]!).compareTo(newest(m[a]!)));
  for (final k in keys) {
    final rows = m[k]!;
    out.add((id: k, rows: rows));
  }
  return out;
}

/// Installment is treated as already posted when its local calendar date is on or before today.
bool installmentIsPaidThroughToday(TransactionEntity t) {
  final now = DateTime.now();
  final local = t.transactedAt.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  return !d.isAfter(today);
}

/// Installments due in [monthStart]'s calendar month (credit rows only), by local
/// [transactedAt] date — includes all days in the month (nothing is omitted for
/// “today” when the selected month is the current month).
List<TransactionEntity> creditLedgerInstallmentsInSelectedMonth(
  List<TransactionEntity> flat,
  DateTime monthStart,
) {
  final y = monthStart.year;
  final m = monthStart.month;
  final out = <TransactionEntity>[];
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == null || g.isEmpty) continue;
    final local = t.transactedAt.toLocal();
    if (local.year != y || local.month != m) continue;
    out.add(t);
  }
  return out;
}

/// Credit groups with at least one **non-ignored** installment in [monthStart]'s
/// month (see [creditLedgerInstallmentsInSelectedMonth]). Includes installments
/// already due on or before today so overdue rows still appear for that month.
List<({String id, List<TransactionEntity> rows})> groupedCreditLedgerForSelectedMonth(
  List<TransactionEntity> flat,
  DateTime monthStart,
) {
  final flatMonth = creditLedgerInstallmentsInSelectedMonth(flat, monthStart);
  final all = groupedCreditLedger(flatMonth);
  return all.where((g) => g.rows.any((t) => !t.ignore)).toList();
}
