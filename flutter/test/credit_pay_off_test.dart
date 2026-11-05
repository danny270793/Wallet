import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/credit_ledger_grouping.dart';
import 'package:wallet/core/demo/demo_store.dart';

void main() {
  group('paying off a credit early', () {
    late DemoStore store;
    late String creditId;
    late List<String> installmentIds;

    setUp(() {
      store = DemoStore();
      final now = DateTime.now();
      creditId = store
          .addCredit(transactedAt: now, graceMonths: 0, termMonths: 3)
          .id;
      installmentIds = [
        for (var i = 0; i < 3; i++)
          store
              .addTransaction(
                transactedAt: DateTime(now.year, now.month + 1 + i, 15),
                value: -100,
                ignore: true,
                creditId: creditId,
              )
              .id,
      ];
    });

    test('paid installments leave lists and totals', () {
      final payment = store.addTransaction(
        transactedAt: DateTime.now(),
        value: -300,
      );
      store.markCreditInstallmentsPaid(installmentIds, payment.id);

      expect(store.transactionsHavingCreditGroup(), isEmpty);
      // Card balances still need them: the payment was credited to the card.
      expect(
        store.transactionsHavingCreditGroup(includePaid: true),
        hasLength(3),
      );
      expect(store.transactionsForYear(DateTime(2100)).map((t) => t.id), [
        payment.id,
      ]);
      // Still reachable by credit id, so deleting the whole credit removes them.
      expect(store.transactionsByCreditId(creditId), hasLength(3));
    });

    test('deleting the payment makes the installments owed again', () {
      final payment = store.addTransaction(
        transactedAt: DateTime.now(),
        value: -300,
      );
      store.markCreditInstallmentsPaid(installmentIds, payment.id);
      store.deleteTransaction(payment.id);

      final back = store.transactionsHavingCreditGroup();
      expect(back, hasLength(3));
      expect(back.every((t) => t.paidByTransactionId == null), isTrue);
    });

    test('a credit with nothing left to pay is settled', () {
      final now = DateTime.now();
      final paidRow = store.addTransaction(
        transactedAt: DateTime(now.year, now.month - 1, 15),
        value: -100,
        ignore: true,
        creditId: creditId,
      );
      final payment = store.addTransaction(transactedAt: now, value: -300);
      store.markCreditInstallmentsPaid(installmentIds, payment.id);

      final rows = store.transactionsHavingCreditGroup();
      expect(rows.map((t) => t.id), [paidRow.id]);
      expect(settledCreditIds(rows), {creditId});
    });
  });
}
