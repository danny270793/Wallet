import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/calendar_months.dart';
import 'package:wallet/core/demo/demo_data_generator.dart';
import 'package:wallet/core/demo/demo_datasources.dart';
import 'package:wallet/core/demo/demo_mode.dart';
import 'package:wallet/core/demo/demo_offline_user_context.dart';
import 'package:wallet/core/demo/demo_store.dart';
import 'package:wallet/features/cards/domain/entities/card_type.dart';
import 'package:wallet/features/transactions/domain/entities/transaction_entity.dart';

final _now = DateTime(2026, 10, 22, 12);

DemoStore _populated({int seed = 1, DateTime? now}) {
  final store = DemoStore();
  DemoDataGenerator(
    store,
    now: now ?? _now,
    random: Random(seed),
  ).populate();
  return store;
}

List<TransactionEntity> _all(DemoStore s) =>
    s.transactionsForYear(DateTime(2100));

void main() {
  group('DemoDataGenerator', () {
    test('fills every feature', () {
      final s = _populated();
      expect(s.accounts().length, greaterThanOrEqualTo(3));
      expect(s.cards().length, greaterThanOrEqualTo(2));
      expect(s.categories(), isNotEmpty);
      expect(s.tags(), isNotEmpty);
      expect(s.loans(), isNotEmpty);
      expect(s.capitalPayments(), isNotEmpty);
      expect(s.assets(), isNotEmpty);
      expect(s.recurringMovements(), isNotEmpty);
      expect(s.transactionsHavingCreditGroup(), isNotEmpty);
      expect(_all(s), isNotEmpty);
    });

    test('covers the current month, the previous one and a full year back', () {
      final s = _populated();
      expect(s.transactionsForMonth(DateTime(2026, 10, 1)), isNotEmpty);
      expect(s.transactionsForMonth(DateTime(2026, 9, 1)), isNotEmpty);
      for (var back = 0; back < 12; back++) {
        final month = addCalendarMonths(DateTime(2026, 10, 1), -back);
        expect(
          s.transactionsForMonth(month),
          isNotEmpty,
          reason: 'no transactions in $month',
        );
      }
    });

    test('is relative to the given date, not hard-coded', () {
      final later = DateTime(2031, 3, 9, 12);
      final s = _populated(now: later);
      expect(s.transactionsForMonth(DateTime(2031, 3, 1)), isNotEmpty);
      expect(s.transactionsForMonth(DateTime(2031, 2, 1)), isNotEmpty);
      expect(s.transactionsForMonth(DateTime(2026, 10, 1)), isEmpty);
    });

    test('plain transactions never sit in the future', () {
      final s = _populated();
      for (final t in _all(s).where((t) => t.creditId == null)) {
        expect(
          t.transactedAt.isAfter(_now),
          isFalse,
          reason: '${t.description} at ${t.transactedAt}',
        );
      }
    });

    test('every reference points at an existing row', () {
      final s = _populated();
      final accounts = {for (final a in s.accounts()) a.id};
      final cards = {for (final c in s.cards()) c.id};
      final categories = {for (final c in s.categories()) c.id};
      final tags = {for (final t in s.tags()) t.id};
      for (final t in _all(s)) {
        expect(
          (t.accountId == null) != (t.cardId == null),
          isTrue,
          reason: 'exactly one of account/card: ${t.description}',
        );
        if (t.accountId != null) {
          expect(accounts, contains(t.accountId));
          expect(t.accountName, isNotNull);
        }
        if (t.cardId != null) {
          expect(cards, contains(t.cardId));
          expect(t.cardName, isNotNull);
        }
        if (t.categoryId != null) expect(categories, contains(t.categoryId));
        if (t.tagId != null) expect(tags, contains(t.tagId));
        if (t.creditId != null) {
          expect(s.credit(t.creditId!), isNotNull);
          expect(t.creditTransactedAt, isNotNull);
        }
      }
      for (final l in s.loans()) {
        expect(accounts, contains(l.accountId));
      }
      final loans = {for (final l in s.loans()) l.id};
      for (final p in s.capitalPayments()) {
        expect(loans, contains(p.loanId));
      }
      for (final r in s.recurringMovements()) {
        expect(categories, contains(r.categoryId));
        expect(tags, contains(r.tagId));
        expect(r.categoryName, isNotNull);
        expect(r.tagName, isNotNull);
      }
    });

    test('transfers come in balanced pairs', () {
      final s = _populated();
      final groups = <String, List<TransactionEntity>>{};
      for (final t in _all(s).where((t) => t.isAccountTransferLeg)) {
        groups.putIfAbsent(t.transferGroupId!, () => []).add(t);
      }
      expect(groups, isNotEmpty);
      for (final legs in groups.values) {
        expect(legs.length, 2);
        expect(legs[0].value + legs[1].value, closeTo(0, 0.001));
      }
    });

    test('deferred purchases have one installment per term month', () {
      final s = _populated();
      final byCredit = <String, List<TransactionEntity>>{};
      for (final t in s.transactionsHavingCreditGroup()) {
        byCredit.putIfAbsent(t.creditId!, () => []).add(t);
      }
      expect(byCredit.length, greaterThanOrEqualTo(2));
      byCredit.forEach((id, rows) {
        final credit = s.credit(id)!;
        expect(rows.length, credit.termMonths);
        expect(s.transactionsByCreditId(id).length, credit.termMonths);
        expect(rows.every((r) => r.ignore && r.cardId != null), isTrue);
        expect(
          rows.fold<double>(0, (sum, r) => sum + r.value),
          lessThan(0),
        );
        final first = s.transactionsByCreditId(id).first;
        expect(first.description, startsWith('(1/${credit.termMonths})'));
      });
      // At least one purchase still has installments to pay.
      expect(
        s.transactionsHavingCreditGroup().any((t) => t.transactedAt.isAfter(_now)),
        isTrue,
      );
    });

    test('balances are the sum of the ledger like the SQL views', () {
      final s = _populated();
      final rows = _all(s);
      for (final a in s.accounts()) {
        final expected = rows
            .where((t) => t.accountId == a.id)
            .fold<double>(0, (sum, t) => sum + t.value);
        expect(a.balance, closeTo(expected, 0.01));
      }
      for (final c in s.cards()) {
        final expected = rows
            .where((t) => t.cardId == c.id && t.creditId == null)
            .fold<double>(0, (sum, t) => sum + t.value);
        expect(c.balance, closeTo(expected, 0.01));
      }
    });

    test('the sample user is better off than broke', () {
      final s = _populated();
      final total = s.accounts().fold<double>(0, (sum, a) => sum + a.balance);
      expect(total, greaterThan(0));
    });

    test('two runs differ (generated at the moment, not canned)', () {
      final a = _all(_populated(seed: 1)).map((t) => t.value).toList();
      final b = _all(_populated(seed: 2)).map((t) => t.value).toList();
      expect(a, isNot(equals(b)));
    });

    test('works for any day of the month', () {
      for (final day in [1, 2, 15, 28, 31]) {
        final s = _populated(now: DateTime(2026, 8, day, 23, 59));
        expect(_all(s), isNotEmpty);
        expect(s.transactionsForMonth(DateTime(2026, 7, 1)), isNotEmpty);
      }
    });
  });

  group('DemoStore mutations and queries', () {
    test('create, update and delete are reflected in reads', () {
      final s = DemoStore();
      final account = s.addAccount('Main');
      s.addTransaction(
        accountId: account.id,
        description: 'Coffee beans',
        transactedAt: DateTime(2026, 10, 5, 9),
        value: -12.5,
      );
      expect(s.accounts().single.balance, -12.5);

      s.updateAccount(account.id, 'Renamed');
      expect(s.accounts().single.name, 'Renamed');
      expect(
        s.transactionsForMonth(DateTime(2026, 10, 1)).single.accountName,
        'Renamed',
      );

      final tx = s.transactionsForMonth(DateTime(2026, 10, 1)).single;
      s.updateTransaction(
        id: tx.id,
        accountId: account.id,
        description: 'Coffee beans',
        transactedAt: tx.transactedAt,
        value: -20,
        ignore: false,
        percentage: 100,
      );
      expect(s.accounts().single.balance, -20);

      s.deleteTransaction(tx.id);
      expect(s.accounts().single.balance, 0);
      s.deleteAccount(account.id);
      expect(s.accounts(), isEmpty);
    });

    test('month queries use the local calendar month, newest first', () {
      final s = DemoStore();
      final a = s.addAccount('A');
      for (final (day, v) in [(1, 1.0), (15, 2.0), (31, 3.0)]) {
        s.addTransaction(
          accountId: a.id,
          transactedAt: DateTime(2026, 10, day, 10),
          value: v,
        );
      }
      s.addTransaction(
        accountId: a.id,
        transactedAt: DateTime(2026, 11, 1),
        value: 9,
      );
      final october = s.transactionsForMonth(DateTime(2026, 10, 17));
      expect(october.map((t) => t.value), [3.0, 2.0, 1.0]);
      expect(s.transactionsForYear(DateTime(2026, 6, 1)).length, 4);
      expect(s.transactionsForYear(DateTime(2025, 6, 1)), isEmpty);
    });

    test('search is case-insensitive and ignores blanks', () {
      final s = DemoStore();
      final a = s.addAccount('A');
      s.addTransaction(
        accountId: a.id,
        description: 'Pizza Night',
        transactedAt: DateTime(2026, 1, 1),
        value: -1,
      );
      expect(s.searchTransactions('pizza').length, 1);
      expect(s.searchTransactions('   '), isEmpty);
      expect(s.searchTransactions('sushi'), isEmpty);
    });

    test('deleting a loan removes its capital payments', () {
      final s = DemoStore();
      final a = s.addAccount('A');
      final loan = s.addLoan(
        accountId: a.id,
        name: 'L',
        value: 100,
        termMonths: 4,
        paymentDay: 5,
        firstPaymentDate: DateTime(2026, 1, 5),
      );
      s.addCapitalPayment(
        loanId: loan.id,
        value: 10,
        paidAt: DateTime(2026, 2, 1, 15),
      );
      expect(s.capitalPayments().single.paidAt, DateTime(2026, 2, 1));
      s.deleteLoan(loan.id);
      expect(s.capitalPayments(), isEmpty);
    });

    test('unknown ids fail loudly instead of silently doing nothing', () {
      final s = DemoStore();
      expect(() => s.deleteTag('missing'), throwsStateError);
      expect(() => s.updateAccount('missing', 'x'), throwsStateError);
    });
  });

  group('demo datasources', () {
    test('behave like the remote ones through the shared interfaces', () async {
      final store = DemoStore();
      final accounts = AccountsDemoDatasource(store);
      final cards = CardsDemoDatasource(store);
      final categories = CategoriesDemoDatasource(store);
      final tags = TagsDemoDatasource(store);
      final transactions = TransactionsDemoDatasource(store);
      final credits = WalletCreditsDemoDatasource(store);

      final account = await accounts.createAccount(name: 'Main');
      final card = await cards.createCard(
        name: 'Visa',
        type: CardType.visa,
        cutDay: 10,
        payDay: 25,
      );
      final category = await categories.createCategory(name: 'Food');
      final tag = await tags.createTag(name: 'Fun', description: '  ');
      expect(tag.description, isNull);

      final header = await credits.insertCredit(
        transactedAt: DateTime(2026, 10, 1),
        graceMonths: 0,
        termMonths: 3,
        description: 'TV',
      );
      expect((await credits.fetchCredit(header.id))!.termMonths, 3);
      expect(await credits.fetchCredit(''), isNull);
      expect(await credits.fetchCredit('nope'), isNull);

      await transactions.createTransaction(
        cardId: card.id,
        categoryId: category.id,
        tagId: tag.id,
        description: '(1/3) TV',
        transactedAt: DateTime(2026, 10, 12),
        value: -100,
        ignore: true,
        percentage: 100,
        creditId: header.id,
      );
      await transactions.createTransaction(
        accountId: account.id,
        transactedAt: DateTime(2026, 10, 3),
        value: 50,
        ignore: false,
        percentage: 100,
      );

      expect((await accounts.getAccounts()).single.balance, 50);
      // The deferred installment is not part of the card balance.
      expect((await cards.getCards()).single.balance, 0);
      final month = await transactions.getTransactionsForMonth(
        DateTime(2026, 10, 1),
      );
      expect(month.length, 2);
      expect(month.first.cardName, 'Visa');
      expect(month.first.categoryName, 'Food');
      expect(month.first.tagName, 'Fun');
      expect(
        (await transactions.getTransactionsByCreditGroupId(header.id)).length,
        1,
      );
      expect(await transactions.getTransactionsByCreditGroupId(''), isEmpty);

      final updated = await credits.updateCreditGracing(
        id: header.id,
        graceMonths: 2,
        termMonths: 6,
      );
      expect(updated.graceMonths, 2);
      expect(updated.transactedAt, header.transactedAt);
    });
  });

  group('DemoMode', () {
    tearDown(() => DemoMode.instance.exit());

    test('enter generates data, exit throws it away', () {
      final mode = DemoMode.instance;
      var notified = 0;
      void listener() => notified++;
      mode.addListener(listener);
      addTearDown(() => mode.removeListener(listener));

      expect(mode.isActive, isFalse);
      expect(() => mode.store, throwsStateError);

      mode.enter();
      expect(mode.isActive, isTrue);
      expect(mode.store.accounts(), isNotEmpty);
      final firstStore = mode.store;

      mode.enter();
      expect(identical(mode.store, firstStore), isFalse);

      mode.exit();
      expect(mode.isActive, isFalse);
      mode.exit();
      expect(notified, 3);
    });

    test('has no user id so nothing is cached on disk', () {
      expect(const DemoOfflineUserContext().userId, isNull);
    });
  });
}
