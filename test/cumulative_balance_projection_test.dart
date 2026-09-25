import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/features/transactions/domain/entities/transaction_entity.dart';
import 'package:wallet/widgets/yearly_weighted_income_bar_chart.dart';

TransactionEntity _tx(DateTime at, double value) => TransactionEntity.fromJson({
  'id': '${at.toIso8601String()}_$value',
  'userId': 'u',
  'accountId': 'a',
  'value': value,
  'percentage': 100,
  'ignore': false,
  'transactedAt': at.toUtc().toIso8601String(),
  'createdAt': at.toUtc().toIso8601String(),
  'updatedAt': at.toUtc().toIso8601String(),
});

void main() {
  final now = DateTime(2026, 9, 24);
  final txs = [
    _tx(DateTime(2025, 12, 10), 1000),
    _tx(DateTime(2026, 3, 5), -200),
    _tx(DateTime(2026, 9, 1), 50),
    // Future-dated (e.g. an installment): counted along with the estimate.
    _tx(DateTime(2026, 11, 1), -300),
  ];

  test(
    'current year: real through current month, then recurring per month',
    () {
      final r = cumulativeAccountsBalanceWithProjection(
        txs,
        2026,
        recurringMonthlyNet: 100,
        now: now,
      );
      expect(r.projectedFromIndex, 9);
      expect(r.monthly[0], 1000); // Jan
      expect(r.monthly[2], 800); // Mar
      expect(r.monthly[8], 850); // Sep (current, real)
      expect(r.monthly[9], 950); // Oct
      expect(r.monthly[10], 750); // Nov: 850 + 200 - 300
      expect(r.monthly[11], 850); // Dec: 850 + 300 - 300
    },
  );

  test('past year: all real, nothing projected', () {
    final r = cumulativeAccountsBalanceWithProjection(
      txs,
      2025,
      recurringMonthlyNet: 100,
      now: now,
    );
    expect(r.projectedFromIndex, 12);
    expect(r.monthly[11], 1000);
    expect(r.monthly[10], 0);
  });

  test('future year: continues from current month-end balance', () {
    final r = cumulativeAccountsBalanceWithProjection(
      txs,
      2027,
      recurringMonthlyNet: 100,
      now: now,
    );
    expect(r.projectedFromIndex, 0);
    expect(r.monthly[0], 850 - 300 + 100 * 4); // Oct, Nov, Dec, Jan
    expect(r.monthly[11], 850 - 300 + 100 * 15);
  });

  test('monthly estimate replaces months after the current one', () {
    final real = List<double>.generate(12, (i) => i + 1.0);
    final cur = monthlyWithRecurringEstimate(
      real,
      2026,
      estimate: 50,
      now: now,
    );
    expect(cur.projectedFromIndex, 9);
    expect(cur.monthly[8], 9); // Sep real
    expect(cur.monthly[9], 10 + 50); // Oct: scheduled + estimate
    expect(cur.monthly[11], 12 + 50);

    final past = monthlyWithRecurringEstimate(
      real,
      2025,
      estimate: 50,
      now: now,
    );
    expect(past.projectedFromIndex, 12);
    expect(past.monthly, real);

    final future = monthlyWithRecurringEstimate(
      real,
      2027,
      estimate: 50,
      now: now,
    );
    expect(future.projectedFromIndex, 0);
    expect(future.monthly[0], 1 + 50);
    expect(future.monthly[11], 12 + 50);
  });
}
