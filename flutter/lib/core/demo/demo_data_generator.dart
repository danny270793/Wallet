import 'dart:math';

import '../../features/cards/domain/entities/card_type.dart';
import '../../features/transactions/domain/usecases/create_account_transfer_usecase.dart';
import '../calendar_months.dart';
import '../credit_group_description.dart';
import '../deferred_credit_installment_schedule.dart';
import '../split_equal_amounts.dart';
import 'demo_store.dart';

/// Fills a [DemoStore] with believable fake data relative to [now]: about 14
/// months of history plus deferred installments that run into the future.
///
/// Amounts are random but bounded, so every run looks different while staying
/// sensible (salary above rent, balances mostly positive, and so on).
class DemoDataGenerator {
  DemoDataGenerator(this._store, {DateTime? now, Random? random})
    : _now = now ?? DateTime.now(),
      _random = random ?? Random();

  /// How many full months before the current one get transactions.
  static const historyMonths = 13;

  final DemoStore _store;
  final DateTime _now;
  final Random _random;

  late String _checking;
  late String _savings;
  late String _cash;
  late String _visa;
  late String _mastercard;

  final _category = <String, String>{};
  final _tag = <String, String>{};

  /// Card spend per card id and `year*100+month`, paid off the next month.
  final _cardSpend = <String, Map<int, double>>{};

  void populate() {
    _createCategoriesAndTags();
    _createAccountsAndCards();
    _openingBalances();
    for (var back = historyMonths; back >= 0; back--) {
      _generateMonth(DateTime(_now.year, _now.month - back, 1), back);
    }
    _cardPayments();
    _deferredPurchases();
    _loans();
    _assets();
    _recurringMovements();
  }

  // helpers

  double _between(double min, double max) =>
      double.parse((min + _random.nextDouble() * (max - min)).toStringAsFixed(2));

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];

  DateTime _monthStart(int back) =>
      DateTime(_now.year, _now.month - back, 1);

  /// [day] of [monthStart]'s month, clamped to its length, at a daytime hour.
  DateTime _at(DateTime monthStart, int day, {int? hour}) {
    final last = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    return DateTime(
      monthStart.year,
      monthStart.month,
      day.clamp(1, last),
      hour ?? 8 + _random.nextInt(13),
      _random.nextInt(60),
    );
  }

  bool _isPast(DateTime at) => !at.isAfter(_now);

  String _cat(String name) => _category[name]!;
  String _tg(String name) => _tag[name]!;

  void _spend({
    required DateTime at,
    required double amount,
    required String description,
    required String category,
    required String tag,
    String? accountId,
    String? cardId,
    double percentage = 100,
  }) {
    if (!_isPast(at)) return;
    final value = -amount.abs();
    _store.addTransaction(
      accountId: accountId,
      cardId: cardId,
      categoryId: _cat(category),
      tagId: _tg(tag),
      description: description,
      transactedAt: at,
      value: value,
      percentage: percentage,
    );
    if (cardId != null) {
      final byMonth = _cardSpend.putIfAbsent(cardId, () => {});
      final key = at.year * 100 + at.month;
      byMonth[key] = (byMonth[key] ?? 0) + amount.abs();
    }
  }

  void _earn({
    required DateTime at,
    required double amount,
    required String description,
    required String category,
    required String tag,
    required String accountId,
  }) {
    if (!_isPast(at)) return;
    _store.addTransaction(
      accountId: accountId,
      categoryId: _cat(category),
      tagId: _tg(tag),
      description: description,
      transactedAt: at,
      value: amount.abs(),
    );
  }

  /// Two legs sharing a transfer group id, like [CreateAccountTransferUsecase].
  void _transfer({
    required DateTime at,
    required double amount,
    String? fromAccount,
    String? toAccount,
    String? toCard,
  }) {
    if (!_isPast(at)) return;
    final groupId = _store.newId();
    _store.addTransaction(
      accountId: fromAccount,
      description: CreateAccountTransferUsecase.transferDescription,
      transactedAt: at,
      value: -amount,
      transferGroupId: groupId,
    );
    _store.addTransaction(
      accountId: toAccount,
      cardId: toCard,
      description: CreateAccountTransferUsecase.transferDescription,
      transactedAt: at,
      value: amount,
      transferGroupId: groupId,
    );
  }

  // catalog

  void _createCategoriesAndTags() {
    const categories = {
      'Housing': 'Rent, repairs and furniture',
      'Groceries': 'Supermarket and fresh food',
      'Dining': 'Restaurants, coffee and delivery',
      'Transport': 'Fuel, transit and rides',
      'Utilities': 'Electricity, water and internet',
      'Entertainment': 'Streaming, games and events',
      'Health': 'Pharmacy, doctor and gym',
      'Shopping': 'Clothes, gadgets and gifts',
      'Insurance': 'Car and home cover',
      'Salary': 'Monthly pay',
      'Freelance': 'Side projects',
    };
    categories.forEach((name, description) {
      _category[name] = _store
          .addCategory(name, description: description)
          .id;
    });

    const tags = {
      'Essential': 'Needed every month',
      'Fun': 'Nice to have',
      'Family': 'Spent for or with family',
      'Work': 'Work related',
      'Subscription': 'Recurring services',
      'Savings': 'Money set aside',
    };
    tags.forEach((name, description) {
      _tag[name] = _store.addTag(name, description: description).id;
    });
    _store.addTag('Archived', description: 'Old trips', hidden: true);
  }

  void _createAccountsAndCards() {
    _checking = _store.addAccount('Checking').id;
    _savings = _store.addAccount('Savings').id;
    _cash = _store.addAccount('Cash').id;
    _visa = _store
        .addCard(
          name: 'Visa Platinum',
          type: CardType.visa,
          nominalInterestRate: 24.5,
          cutDay: 20,
          payDay: 5,
        )
        .id;
    _mastercard = _store
        .addCard(
          name: 'Mastercard Gold',
          type: CardType.mastercard,
          nominalInterestRate: 19.9,
          cutDay: 10,
          payDay: 28,
        )
        .id;
  }

  void _openingBalances() {
    final start = _at(_monthStart(historyMonths), 1, hour: 9);
    for (final (account, amount) in [
      (_checking, 2500.0),
      (_savings, 4200.0),
      (_cash, 80.0),
    ]) {
      _store.addTransaction(
        accountId: account,
        description: 'Opening balance',
        transactedAt: start,
        value: amount,
      );
    }
  }

  // monthly activity

  static const _groceryStores = [
    'Supermarket',
    'Farmers market',
    'Corner store',
    'Bakery',
    'Organic shop',
  ];
  static const _restaurants = [
    'Pizza night',
    'Sushi place',
    'Brunch',
    'Burger spot',
    'Thai takeout',
    'Taco truck',
  ];
  static const _shops = [
    'Sneakers',
    'Jacket',
    'Headphones',
    'Book order',
    'Gift for a friend',
    'Home decor',
    'Backpack',
  ];

  void _generateMonth(DateTime month, int back) {
    // income
    _earn(
      at: _at(month, 1, hour: 9),
      amount: 3450,
      description: 'Salary',
      category: 'Salary',
      tag: 'Work',
      accountId: _checking,
    );
    if (_random.nextDouble() < 0.35) {
      _earn(
        at: _at(month, 10 + _random.nextInt(15)),
        amount: _between(250, 720),
        description: _pick(['Website project', 'Logo design', 'Consulting']),
        category: 'Freelance',
        tag: 'Work',
        accountId: _checking,
      );
    }

    // fixed bills
    _spend(
      at: _at(month, 3, hour: 10),
      amount: 1100,
      description: 'Rent',
      category: 'Housing',
      tag: 'Essential',
      accountId: _checking,
    );
    _spend(
      at: _at(month, 12),
      amount: _between(55, 95),
      description: 'Electricity bill',
      category: 'Utilities',
      tag: 'Essential',
      accountId: _checking,
    );
    _spend(
      at: _at(month, 14),
      amount: _between(24, 40),
      description: 'Water bill',
      category: 'Utilities',
      tag: 'Essential',
      accountId: _checking,
    );
    _spend(
      at: _at(month, 8),
      amount: 59.9,
      description: 'Internet',
      category: 'Utilities',
      tag: 'Subscription',
      cardId: _visa,
    );
    _spend(
      at: _at(month, 2),
      amount: 35,
      description: 'Transit pass',
      category: 'Transport',
      tag: 'Essential',
      accountId: _checking,
    );

    // subscriptions
    _spend(
      at: _at(month, 9),
      amount: 15.49,
      description: 'Netflix',
      category: 'Entertainment',
      tag: 'Subscription',
      cardId: _visa,
    );
    _spend(
      at: _at(month, 15),
      amount: 10.99,
      description: 'Spotify',
      category: 'Entertainment',
      tag: 'Subscription',
      cardId: _visa,
    );
    _spend(
      at: _at(month, 1, hour: 7),
      amount: 39,
      description: 'Gym membership',
      category: 'Health',
      tag: 'Subscription',
      cardId: _mastercard,
    );

    // groceries
    for (var i = 0; i < 4 + _random.nextInt(3); i++) {
      final onCard = _random.nextBool();
      _spend(
        at: _at(month, 1 + _random.nextInt(28)),
        amount: _between(18, 96),
        description: _pick(_groceryStores),
        category: 'Groceries',
        tag: _random.nextDouble() < 0.3 ? 'Family' : 'Essential',
        accountId: onCard ? null : _checking,
        cardId: onCard ? _mastercard : null,
      );
    }

    // dining, some of them split with a friend
    for (var i = 0; i < 3 + _random.nextInt(4); i++) {
      final shared = _random.nextDouble() < 0.25;
      _spend(
        at: _at(month, 1 + _random.nextInt(28)),
        amount: _between(9, 52),
        description: shared
            ? '${_pick(_restaurants)} (split)'
            : _pick(_restaurants),
        category: 'Dining',
        tag: 'Fun',
        cardId: _visa,
        percentage: shared ? 50 : 100,
      );
    }

    // transport
    for (var i = 0; i < 2 + _random.nextInt(2); i++) {
      _spend(
        at: _at(month, 1 + _random.nextInt(28)),
        amount: _between(24, 48),
        description: 'Fuel',
        category: 'Transport',
        tag: 'Essential',
        cardId: _mastercard,
      );
    }
    if (_random.nextDouble() < 0.5) {
      _spend(
        at: _at(month, 1 + _random.nextInt(28)),
        amount: _between(8, 26),
        description: 'Ride share',
        category: 'Transport',
        tag: 'Fun',
        cardId: _visa,
      );
    }

    // occasional extras
    if (_random.nextDouble() < 0.45) {
      _spend(
        at: _at(month, 1 + _random.nextInt(28)),
        amount: _between(8, 42),
        description: 'Pharmacy',
        category: 'Health',
        tag: 'Essential',
        accountId: _checking,
      );
    }
    for (var i = 0; i < 1 + _random.nextInt(3); i++) {
      _spend(
        at: _at(month, 1 + _random.nextInt(28)),
        amount: _between(20, 140),
        description: _pick(_shops),
        category: 'Shopping',
        tag: 'Fun',
        cardId: _visa,
      );
    }

    // cash
    _transfer(
      at: _at(month, 6, hour: 11),
      amount: 100,
      fromAccount: _checking,
      toAccount: _cash,
    );
    for (var i = 0; i < 3 + _random.nextInt(4); i++) {
      _spend(
        at: _at(month, 1 + _random.nextInt(28)),
        amount: _between(2.5, 14),
        description: _pick(['Coffee', 'Snack', 'Street food', 'Newspaper']),
        category: 'Dining',
        tag: 'Fun',
        accountId: _cash,
      );
    }

    // savings
    _transfer(
      at: _at(month, 2, hour: 9),
      amount: 300,
      fromAccount: _checking,
      toAccount: _savings,
    );
  }

  /// Pays last month's card spend from checking, as a transfer onto the card.
  void _cardPayments() {
    for (final entry in _cardSpend.entries) {
      for (final month in entry.value.entries) {
        final y = month.key ~/ 100;
        final m = month.key % 100;
        final paidIn = DateTime(y, m + 1, 1);
        if (!_isPast(paidIn)) continue;
        _transfer(
          at: _at(paidIn, 5, hour: 10),
          amount: double.parse(month.value.toStringAsFixed(2)),
          fromAccount: _checking,
          toCard: entry.key,
        );
      }
    }
  }

  // deferred purchases

  void _deferredPurchases() {
    _deferred(
      note: 'Laptop',
      total: 1499.9,
      cardId: _visa,
      cutDay: 20,
      termMonths: 12,
      graceMonths: 0,
      monthsAgo: 3,
      day: 7,
      category: 'Shopping',
    );
    _deferred(
      note: 'Phone',
      total: 799,
      cardId: _mastercard,
      cutDay: 10,
      termMonths: 9,
      graceMonths: 0,
      monthsAgo: 6,
      day: 18,
      category: 'Shopping',
    );
    _deferred(
      note: 'Sofa',
      total: 1280,
      cardId: _visa,
      cutDay: 20,
      termMonths: 24,
      graceMonths: 2,
      monthsAgo: 1,
      day: 12,
      category: 'Housing',
    );
  }

  /// Same steps as `TransactionsCubit.create` for a deferred card purchase.
  void _deferred({
    required String note,
    required double total,
    required String cardId,
    required int cutDay,
    required int termMonths,
    required int graceMonths,
    required int monthsAgo,
    required int day,
    required String category,
  }) {
    final purchase = _at(_monthStart(monthsAgo), day, hour: 16);
    final parts = splitEqualAmountParts(total, termMonths);
    final schedule = scheduleDeferredCreditInstallmentsLocal(
      purchaseLocal: purchase,
      graceMonths: graceMonths,
      termMonths: termMonths,
      cardCutDay: cutDay,
    );
    final header = _store.addCredit(
      transactedAt: purchase,
      graceMonths: graceMonths,
      termMonths: termMonths,
      description: note,
    );
    for (var i = 0; i < termMonths; i++) {
      _store.addTransaction(
        cardId: cardId,
        categoryId: _cat(category),
        tagId: _tg('Fun'),
        description: creditGroupPrefixedDescription(
          oneBasedCurrent: i + 1,
          total: termMonths,
          userNote: note,
        ),
        transactedAt: schedule[i],
        value: -parts[i],
        ignore: true,
        creditId: header.id,
      );
    }
  }

  // other features

  void _loans() {
    final car = _store.addLoan(
      accountId: _checking,
      name: 'Car loan',
      value: 12000,
      nominalInterestRate: 8.9,
      termMonths: 48,
      paymentDay: 15,
      firstPaymentDate: addCalendarMonths(
        DateTime(_now.year, _now.month, 15),
        -10,
      ),
    );
    _store.addCapitalPayment(
      loanId: car.id,
      value: 1000,
      paidAt: addCalendarMonths(DateTime(_now.year, _now.month, 20), -4),
    );
    _store.addLoan(
      accountId: _checking,
      name: 'Home improvement',
      value: 3000,
      termMonths: 18,
      paymentDay: 28,
      firstPaymentDate: addCalendarMonths(
        DateTime(_now.year, _now.month, 28),
        -5,
      ),
    );
  }

  void _assets() {
    _store.addAsset(
      name: 'Index fund',
      provider: 'Vanguard',
      value: 5000,
      boughtAt: addCalendarMonths(_now, -20),
    );
    _store.addAsset(
      name: 'Gold coin',
      provider: 'Local dealer',
      value: 1800,
      boughtAt: addCalendarMonths(_now, -36),
    );
    _store.addAsset(
      name: 'City bike',
      provider: 'Marketplace',
      value: 450,
      boughtAt: addCalendarMonths(_now, -48),
      endedAt: addCalendarMonths(_now, -8),
      soldValue: 300,
    );
  }

  void _recurringMovements() {
    void add(
      String name,
      double value,
      String category,
      String tag, {
      bool yearly = false,
      String? description,
    }) {
      _store.addRecurringMovement(
        name: name,
        description: description,
        value: value,
        categoryId: _cat(category),
        tagId: _tg(tag),
        yearlyPayment: yearly,
      );
    }

    add('Salary', 3450, 'Salary', 'Work');
    add('Rent', -1100, 'Housing', 'Essential');
    add('Internet', -59.9, 'Utilities', 'Subscription');
    add('Netflix', -15.49, 'Entertainment', 'Subscription');
    add('Spotify', -10.99, 'Entertainment', 'Subscription');
    add('Gym membership', -39, 'Health', 'Subscription');
    add(
      'Car insurance',
      -840,
      'Insurance',
      'Essential',
      yearly: true,
      description: 'Paid once a year',
    );
  }
}
