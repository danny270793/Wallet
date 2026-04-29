import '../features/transactions/domain/entities/transaction_entity.dart';

/// Income (positive amounts), outcome (absolute negatives), net balance for a set of transactions.
///
/// Rows with [TransactionEntity.isAccountTransferLeg] are omitted (transfer pairs do not count
/// toward income/outcome/net).
({double income, double outcome, double balance})
transactionMonthTotalsBreakdown(
  Iterable<TransactionEntity> txs, {
  required bool Function(TransactionEntity) include,
  required double Function(TransactionEntity) amount,
}) {
  var income = 0.0;
  var outcome = 0.0;
  var balance = 0.0;
  for (final t in txs) {
    if (t.isAccountTransferLeg) continue;
    if (!include(t)) continue;
    final v = amount(t);
    balance += v;
    if (v > 0) {
      income += v;
    } else if (v < 0) {
      outcome += -v;
    }
  }
  return (income: income, outcome: outcome, balance: balance);
}
