import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/automatic_recurring_movements.dart';
import 'package:wallet/features/cards/domain/entities/card_entity.dart';
import 'package:wallet/features/loans/domain/entities/loan_entity.dart';
import 'package:wallet/features/transactions/domain/entities/transaction_entity.dart';

final _today = DateTime(2026, 10, 14);

TransactionEntity _installment(DateTime at, double value) =>
    TransactionEntity.fromJson({
      'id': '${at.toIso8601String()}_$value',
      'userId': 'u',
      'cardId': 'c',
      'creditId': 'credit',
      'value': value,
      'percentage': 100,
      'ignore': false,
      'transactedAt': at.toUtc().toIso8601String(),
      'createdAt': at.toUtc().toIso8601String(),
      'updatedAt': at.toUtc().toIso8601String(),
    });

final _card = CardEntity(
  id: 'c',
  userId: 'u',
  name: 'Card',
  nominalInterestRate: 12,
  // Revolving balance today: -1000 ledger + the -100 installment already posted.
  balance: -1000,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final _loan = LoanEntity(
  id: 'l',
  userId: 'u',
  accountId: 'a',
  name: 'Loan',
  value: 1200,
  termMonths: 12,
  paymentDay: 30,
  firstPaymentDate: DateTime(2026, 1, 30),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final _source = AutomaticMovementsSource(
  loans: [_loan],
  cards: [_card],
  creditInstallments: [
    _installment(DateTime(2026, 10, 5), -100), // posted
    _installment(DateTime(2026, 11, 5), -100),
    _installment(DateTime(2026, 12, 5), -100),
  ],
);

double _amountOf<T extends AutomaticRecurringMovement>(
  List<AutomaticRecurringMovement> rows,
) => rows.whereType<T>().fold(0, (s, r) => s + r.monthlyAmount);

void main() {
  test('deferred rows follow the selected month', () {
    final nov = _source.forMonth(DateTime(2026, 11), today: _today);
    expect(_amountOf<CardDeferredRecurringMovement>(nov), -100);
    final jan = _source.forMonth(DateTime(2027, 1), today: _today);
    expect(jan.whereType<CardDeferredRecurringMovement>(), isEmpty);
  });

  test('card interest grows with installments posted before that month', () {
    final oct = _source.forMonth(DateTime(2026, 10), today: _today);
    expect(_amountOf<CardInterestRecurringMovement>(oct), closeTo(-11, 1e-9));
    final dec = _source.forMonth(DateTime(2026, 12), today: _today);
    // -1100 today, plus November's -100 posted before December.
    expect(_amountOf<CardInterestRecurringMovement>(dec), closeTo(-12, 1e-9));
  });

  test('loan row only in months with an installment', () {
    final oct = _source.forMonth(DateTime(2026, 10), today: _today);
    expect(_amountOf<LoanRecurringMovement>(oct), closeTo(-100, 1e-9));
    final next = _source.forMonth(DateTime(2027, 1), today: _today);
    expect(next.whereType<LoanRecurringMovement>(), isEmpty);
  });
}
