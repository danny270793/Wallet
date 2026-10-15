import 'dart:math' as math;

import 'loan_capital_payment_entity.dart';
import 'loan_entity.dart';

/// One row of a loan's payment plan: a monthly installment or a capital payment.
sealed class LoanScheduleEntry {
  const LoanScheduleEntry({required this.date, required this.remaining});

  final DateTime date;

  /// Principal still owed after this row.
  final double remaining;

  /// Amount paid in this row.
  double get payment;
}

class LoanInstallmentEntry extends LoanScheduleEntry {
  const LoanInstallmentEntry({
    required this.number,
    required super.date,
    required this.payment,
    required this.interest,
    required this.principal,
    required super.remaining,
  });

  final int number;
  @override
  final double payment;
  final double interest;
  final double principal;
}

class LoanCapitalPaymentEntry extends LoanScheduleEntry {
  LoanCapitalPaymentEntry({
    required this.capitalPayment,
    required super.remaining,
  }) : super(date: capitalPayment.paidAt);

  final LoanCapitalPaymentEntity capitalPayment;

  @override
  double get payment => capitalPayment.value;
}

/// Fixed-payment (French) amortization: monthly rate is the nominal annual rate
/// divided by 12; with no rate the balance is split evenly.
///
/// A capital payment dated before an installment lowers the balance first, and
/// the installments left are recomputed over the same remaining number of
/// months (the term stays, the monthly amount drops). Installments stop once
/// the balance reaches 0. The last installment absorbs rounding.
List<LoanScheduleEntry> loanSchedule(
  LoanEntity loan, {
  List<LoanCapitalPaymentEntity> capitalPayments = const [],
}) {
  final n = loan.termMonths;
  if (n <= 0) return const [];
  final r = (loan.nominalInterestRate ?? 0) / 100 / 12;
  final pending = [...capitalPayments.where((p) => p.loanId == loan.id)]
    ..sort((a, b) {
      final byDate = a.paidAt.compareTo(b.paidAt);
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });

  final out = <LoanScheduleEntry>[];
  var balance = loan.value;
  var p = 0;

  void applyCapital(LoanCapitalPaymentEntity c) {
    balance = math.max(0, balance - c.value);
    out.add(LoanCapitalPaymentEntry(capitalPayment: c, remaining: balance));
  }

  for (var i = 1; i <= n && balance > 1e-6; i++) {
    final due = loanInstallmentDueDate(loan, i - 1);
    while (p < pending.length && pending[p].paidAt.isBefore(due)) {
      applyCapital(pending[p++]);
    }
    if (balance <= 1e-6) break;
    final left = n - i + 1;
    // Recomputing every month keeps rounding from drifting; it equals the
    // fixed payment whenever no capital payment happened.
    final payment = _annuity(balance, r, left);
    final interest = balance * r;
    var principal = payment - interest;
    if (i == n || principal > balance) principal = balance;
    balance -= principal;
    if (balance.abs() < 1e-6) balance = 0;
    out.add(
      LoanInstallmentEntry(
        number: i,
        date: due,
        payment: principal + interest,
        interest: interest,
        principal: principal,
        remaining: balance,
      ),
    );
  }
  while (p < pending.length) {
    applyCapital(pending[p++]);
  }
  return out;
}

double _annuity(double balance, double r, int months) =>
    r == 0 ? balance / months : balance * r / (1 - math.pow(1 + r, -months));

/// Installment [index] (0 = first): [LoanEntity.firstPaymentDate], then
/// [LoanEntity.paymentDay] of each following month, clamped to short months.
DateTime loanInstallmentDueDate(LoanEntity loan, int index) {
  if (index == 0) return loan.firstPaymentDate;
  final first = loan.firstPaymentDate;
  return _dayInMonth(first.year, first.month + index, loan.paymentDay);
}

DateTime _dayInMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(day, lastDay));
}

/// Paid when its date is today or earlier; capital payments are always paid.
bool loanEntryIsPaid(LoanScheduleEntry e, {DateTime? today}) {
  if (e is LoanCapitalPaymentEntry) return true;
  final now = today ?? DateTime.now();
  return !e.date.isAfter(DateTime(now.year, now.month, now.day));
}

/// Current monthly installment: the next unpaid one, or the last if all are paid.
double loanCurrentPayment(
  LoanEntity loan, {
  List<LoanCapitalPaymentEntity> capitalPayments = const [],
}) {
  final installments = loanSchedule(
    loan,
    capitalPayments: capitalPayments,
  ).whereType<LoanInstallmentEntry>().toList();
  if (installments.isEmpty) return 0;
  for (final i in installments) {
    if (!loanEntryIsPaid(i)) return i.payment;
  }
  return installments.last.payment;
}

/// Principal owed at the end of [date] (installments and capital payments on
/// or before it applied).
double loanBalanceOn(
  LoanEntity loan,
  DateTime date, {
  List<LoanCapitalPaymentEntity> capitalPayments = const [],
}) {
  var balance = loan.value;
  for (final e in loanSchedule(loan, capitalPayments: capitalPayments)) {
    if (e.date.isAfter(date)) break;
    balance = e.remaining;
  }
  return balance;
}
