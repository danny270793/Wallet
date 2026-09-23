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

/// Deferred installment sums for one card: [billed] for the ones already posted
/// (see [installmentIsPaidThroughToday]), [pending] for the ones still to come.
typedef CardCreditTotals = ({double billed, double pending});

/// Splits credit installments per card id, using the same posted/pending cutoff
/// as /credits so both screens agree. Rows with no [TransactionEntity.cardId] are skipped.
Map<String, CardCreditTotals> creditTotalsByCard(List<TransactionEntity> flat) {
  final out = <String, CardCreditTotals>{};
  for (final t in flat) {
    final g = t.creditLedgerGroupingKey;
    if (g == null || g.isEmpty) continue;
    final cardId = t.cardId;
    if (cardId == null || cardId.isEmpty) continue;
    final current = out[cardId] ?? (billed: 0.0, pending: 0.0);
    out[cardId] = installmentIsPaidThroughToday(t)
        ? (billed: current.billed + t.value, pending: current.pending)
        : (billed: current.billed, pending: current.pending + t.value);
  }
  return out;
}

/// Regular card ledger plus installments already posted (the first amount on /cards).
double cardPostedBalance(double ledgerBalance, CardCreditTotals? credits) =>
    ledgerBalance + (credits?.billed ?? 0);

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
