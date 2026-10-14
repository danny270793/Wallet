import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/features/loans/domain/entities/loan_capital_payment_entity.dart';
import 'package:wallet/features/loans/domain/entities/loan_entity.dart';
import 'package:wallet/features/loans/domain/entities/loan_schedule.dart';

LoanEntity _loan({
  double value = 1000,
  double? rate,
  int term = 12,
  int day = 30,
  DateTime? first,
}) => LoanEntity(
  id: 'l',
  userId: 'u',
  accountId: 'a',
  name: 'Loan',
  value: value,
  nominalInterestRate: rate,
  termMonths: term,
  paymentDay: day,
  firstPaymentDate: first ?? DateTime(2026, 1, 30),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

LoanCapitalPaymentEntity _capital(double value, DateTime paidAt) =>
    LoanCapitalPaymentEntity(
      id: 'c$value',
      userId: 'u',
      loanId: 'l',
      value: value,
      paidAt: paidAt,
      createdAt: DateTime.utc(2026),
    );

List<LoanInstallmentEntry> _installments(List<LoanScheduleEntry> s) =>
    s.whereType<LoanInstallmentEntry>().toList();

void main() {
  test('no rate splits the value evenly', () {
    final s = _installments(loanSchedule(_loan(value: 1200, term: 12)));
    expect(s, hasLength(12));
    expect(s.every((i) => (i.payment - 100).abs() < 1e-9), isTrue);
    expect(s.last.remaining, 0);
  });

  test('fixed payment with interest pays the loan off', () {
    final s = _installments(
      loanSchedule(_loan(value: 10000, rate: 12, term: 12)),
    );
    expect(s.first.payment, closeTo(888.49, 0.01));
    expect(s.first.interest, closeTo(100, 1e-9));
    expect(s.last.payment, closeTo(888.49, 0.01));
    final principal = s.fold<double>(0, (a, i) => a + i.principal);
    expect(principal, closeTo(10000, 1e-6));
    expect(s.last.remaining, 0);
  });

  test('due dates keep the payment day, clamped to short months', () {
    final s = loanSchedule(_loan(term: 3));
    expect(s.map((i) => i.date).toList(), [
      DateTime(2026, 1, 30),
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 30),
    ]);
  });

  test('first installment uses its own date, the rest the payment day', () {
    final s = loanSchedule(
      _loan(term: 3, day: 5, first: DateTime(2026, 11, 20)),
    );
    expect(s.map((i) => i.date).toList(), [
      DateTime(2026, 11, 20),
      DateTime(2026, 12, 5),
      DateTime(2027, 1, 5),
    ]);
  });

  test('capital payment lowers later installments, term stays', () {
    final loan = _loan(value: 1200, term: 12);
    final s = loanSchedule(
      loan,
      capitalPayments: [_capital(600, DateTime(2026, 6, 15))],
    );
    final inst = _installments(s);
    expect(inst, hasLength(12));
    // Five installments of 100 paid, 700 left, minus 600 = 100 over 7 months.
    expect(inst[4].payment, closeTo(100, 1e-9));
    expect(inst[5].payment, closeTo(100 / 7, 1e-9));
    expect(inst.last.remaining, 0);
    final capital = s.whereType<LoanCapitalPaymentEntry>().single;
    expect(capital.remaining, closeTo(100, 1e-9));
    expect(s.indexOf(capital), 5);
  });

  test('capital payment of the whole balance ends the schedule', () {
    final s = loanSchedule(
      _loan(value: 1200, term: 12),
      capitalPayments: [_capital(1100, DateTime(2026, 2, 1))],
    );
    expect(_installments(s), hasLength(1));
    expect(s.last, isA<LoanCapitalPaymentEntry>());
    expect(s.last.remaining, 0);
  });

  test('past installments and capital payments count as paid', () {
    final today = DateTime(2026, 2, 28);
    final s = loanSchedule(_loan(term: 3));
    expect(s.map((e) => loanEntryIsPaid(e, today: today)).toList(), [
      true,
      true,
      false,
    ]);
  });

  test('payment date round-trips as a plain date', () {
    final loan = _loan();
    expect(LoanEntity.fromJson(loan.toJson()), loan);
  });
}
