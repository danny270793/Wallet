import 'package:uuid/uuid.dart';

import '../../features/accounts/domain/entities/account_entity.dart';
import '../../features/assets/domain/entities/asset_entity.dart';
import '../../features/cards/domain/entities/card_entity.dart';
import '../../features/cards/domain/entities/card_type.dart';
import '../../features/categories/domain/entities/category_entity.dart';
import '../../features/loans/domain/entities/loan_capital_payment_entity.dart';
import '../../features/loans/domain/entities/loan_entity.dart';
import '../../features/recurring_movements/domain/entities/recurring_movement_entity.dart';
import '../../features/tags/domain/entities/tag_entity.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import '../../features/wallet_credits/domain/entities/wallet_credit_entity.dart';

/// In-memory copy of the `wallet_*` tables used while demo mode is active.
///
/// Mirrors what the Supabase datasources return: balances come from the same
/// sums as the `wallet_accounts_with_balance` / `wallet_cards_with_balance`
/// views, and transactions carry the embedded relation names. Lists keep
/// insertion order, which matches the `createdAt` ordering of the real queries.
class DemoStore {
  DemoStore();

  static const userId = 'demo-user';
  static const _uuid = Uuid();

  final _accounts = <AccountEntity>[];
  final _cards = <CardEntity>[];
  final _categories = <CategoryEntity>[];
  final _tags = <TagEntity>[];
  final _loans = <LoanEntity>[];
  final _capitalPayments = <LoanCapitalPaymentEntity>[];
  final _assets = <AssetEntity>[];
  final _recurring = <RecurringMovementEntity>[];
  final _credits = <WalletCreditEntity>[];
  final _transactions = <TransactionEntity>[];

  String newId() => _uuid.v4();

  DateTime _stamp() => DateTime.now().toUtc();

  int _indexOf<T>(List<T> rows, String id, String Function(T) idOf) {
    final i = rows.indexWhere((e) => idOf(e) == id);
    if (i < 0) throw StateError('demo: row not found: $id');
    return i;
  }

  static double _money(double v) => double.parse(v.toStringAsFixed(2));

  // accounts

  List<AccountEntity> accounts() => [
    for (final a in _accounts) _accountWithBalance(a),
  ];

  AccountEntity _accountWithBalance(AccountEntity a) => AccountEntity(
    id: a.id,
    userId: a.userId,
    name: a.name,
    createdAt: a.createdAt,
    updatedAt: a.updatedAt,
    balance: accountBalance(a.id),
  );

  /// Sum of every transaction value on the account (deferred rows included).
  double accountBalance(String accountId) {
    var sum = 0.0;
    for (final t in _transactions) {
      if (t.accountId == accountId) sum += t.value;
    }
    return _money(sum);
  }

  AccountEntity addAccount(String name, {DateTime? createdAt}) {
    final at = (createdAt ?? _stamp()).toUtc();
    final a = AccountEntity(
      id: newId(),
      userId: userId,
      name: name,
      createdAt: at,
      updatedAt: at,
    );
    _accounts.add(a);
    return _accountWithBalance(a);
  }

  AccountEntity updateAccount(String id, String name) {
    final i = _indexOf(_accounts, id, (e) => e.id);
    final old = _accounts[i];
    _accounts[i] = AccountEntity(
      id: old.id,
      userId: old.userId,
      name: name,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
    );
    return _accountWithBalance(_accounts[i]);
  }

  void deleteAccount(String id) {
    _accounts.removeAt(_indexOf(_accounts, id, (e) => e.id));
  }

  // cards

  List<CardEntity> cards() => [for (final c in _cards) _cardWithBalance(c)];

  CardEntity _cardWithBalance(CardEntity c) => CardEntity(
    id: c.id,
    userId: c.userId,
    name: c.name,
    type: c.type,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
    cutDay: c.cutDay,
    payDay: c.payDay,
    nominalInterestRate: c.nominalInterestRate,
    balance: cardBalance(c.id),
  );

  /// Sum of the card's transactions with no credit (deferred installments are
  /// excluded, like the SQL view).
  double cardBalance(String cardId) {
    var sum = 0.0;
    for (final t in _transactions) {
      if (t.cardId == cardId && t.creditId == null) sum += t.value;
    }
    return _money(sum);
  }

  CardEntity addCard({
    required String name,
    required CardType type,
    double? nominalInterestRate,
    int cutDay = 24,
    int payDay = 24,
    DateTime? createdAt,
  }) {
    final at = (createdAt ?? _stamp()).toUtc();
    final c = CardEntity(
      id: newId(),
      userId: userId,
      name: name,
      type: type,
      createdAt: at,
      updatedAt: at,
      cutDay: cutDay,
      payDay: payDay,
      nominalInterestRate: nominalInterestRate,
    );
    _cards.add(c);
    return _cardWithBalance(c);
  }

  CardEntity updateCard({
    required String id,
    required String name,
    required CardType type,
    double? nominalInterestRate,
    required int cutDay,
    required int payDay,
  }) {
    final i = _indexOf(_cards, id, (e) => e.id);
    final old = _cards[i];
    _cards[i] = CardEntity(
      id: old.id,
      userId: old.userId,
      name: name,
      type: type,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
      cutDay: cutDay,
      payDay: payDay,
      nominalInterestRate: nominalInterestRate,
    );
    return _cardWithBalance(_cards[i]);
  }

  void deleteCard(String id) {
    _cards.removeAt(_indexOf(_cards, id, (e) => e.id));
  }

  // categories

  List<CategoryEntity> categories() => List.unmodifiable(_categories);

  CategoryEntity addCategory(
    String name, {
    String? description,
    DateTime? createdAt,
  }) {
    final at = (createdAt ?? _stamp()).toUtc();
    final c = CategoryEntity(
      id: newId(),
      userId: userId,
      name: name,
      description: _blankToNull(description),
      createdAt: at,
      updatedAt: at,
    );
    _categories.add(c);
    return c;
  }

  CategoryEntity updateCategory(String id, String name, String? description) {
    final i = _indexOf(_categories, id, (e) => e.id);
    final old = _categories[i];
    _categories[i] = CategoryEntity(
      id: old.id,
      userId: old.userId,
      name: name,
      description: _blankToNull(description),
      createdAt: old.createdAt,
      updatedAt: _stamp(),
    );
    return _categories[i];
  }

  void deleteCategory(String id) {
    _categories.removeAt(_indexOf(_categories, id, (e) => e.id));
  }

  // tags

  List<TagEntity> tags() => List.unmodifiable(_tags);

  TagEntity addTag(
    String name, {
    String? description,
    bool hidden = false,
    DateTime? createdAt,
  }) {
    final at = (createdAt ?? _stamp()).toUtc();
    final t = TagEntity(
      id: newId(),
      userId: userId,
      name: name,
      description: _blankToNull(description),
      hidden: hidden,
      createdAt: at,
      updatedAt: at,
    );
    _tags.add(t);
    return t;
  }

  TagEntity updateTag({
    required String id,
    required String name,
    String? description,
    bool hidden = false,
  }) {
    final i = _indexOf(_tags, id, (e) => e.id);
    final old = _tags[i];
    _tags[i] = TagEntity(
      id: old.id,
      userId: old.userId,
      name: name,
      description: _blankToNull(description),
      hidden: hidden,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
    );
    return _tags[i];
  }

  void deleteTag(String id) {
    _tags.removeAt(_indexOf(_tags, id, (e) => e.id));
  }

  String? _blankToNull(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  // loans

  List<LoanEntity> loans() => List.unmodifiable(_loans);

  LoanEntity addLoan({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
    DateTime? createdAt,
  }) {
    final at = (createdAt ?? _stamp()).toUtc();
    final l = LoanEntity(
      id: newId(),
      userId: userId,
      accountId: accountId,
      name: name,
      value: value,
      nominalInterestRate: nominalInterestRate,
      termMonths: termMonths,
      paymentDay: paymentDay,
      firstPaymentDate: firstPaymentDate,
      createdAt: at,
      updatedAt: at,
    );
    _loans.add(l);
    return l;
  }

  LoanEntity updateLoan({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) {
    final i = _indexOf(_loans, id, (e) => e.id);
    final old = _loans[i];
    _loans[i] = LoanEntity(
      id: old.id,
      userId: old.userId,
      accountId: accountId,
      name: name,
      value: value,
      nominalInterestRate: nominalInterestRate,
      termMonths: termMonths,
      paymentDay: paymentDay,
      firstPaymentDate: firstPaymentDate,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
    );
    return _loans[i];
  }

  void deleteLoan(String id) {
    _loans.removeAt(_indexOf(_loans, id, (e) => e.id));
    _capitalPayments.removeWhere((p) => p.loanId == id);
  }

  List<LoanCapitalPaymentEntity> capitalPayments() {
    final out = [..._capitalPayments];
    out.sort((a, b) => a.paidAt.compareTo(b.paidAt));
    return out;
  }

  LoanCapitalPaymentEntity addCapitalPayment({
    required String loanId,
    required double value,
    required DateTime paidAt,
  }) {
    final p = LoanCapitalPaymentEntity(
      id: newId(),
      userId: userId,
      loanId: loanId,
      value: value,
      paidAt: DateTime(paidAt.year, paidAt.month, paidAt.day),
      createdAt: _stamp(),
    );
    _capitalPayments.add(p);
    return p;
  }

  void deleteCapitalPayment(String id) {
    _capitalPayments.removeAt(_indexOf(_capitalPayments, id, (e) => e.id));
  }

  // assets (newest purchase first, like the real query)

  List<AssetEntity> assets() {
    final out = [..._assets];
    out.sort((a, b) => b.boughtAt.compareTo(a.boughtAt));
    return out;
  }

  AssetEntity addAsset({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
    DateTime? createdAt,
  }) {
    final at = (createdAt ?? _stamp()).toUtc();
    final a = AssetEntity(
      id: newId(),
      userId: userId,
      name: name,
      provider: provider,
      value: value,
      boughtAt: boughtAt.toUtc(),
      endedAt: endedAt?.toUtc(),
      soldValue: soldValue,
      createdAt: at,
      updatedAt: at,
    );
    _assets.add(a);
    return a;
  }

  AssetEntity updateAsset({
    required String id,
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) {
    final i = _indexOf(_assets, id, (e) => e.id);
    final old = _assets[i];
    _assets[i] = AssetEntity(
      id: old.id,
      userId: old.userId,
      name: name,
      provider: provider,
      value: value,
      boughtAt: boughtAt.toUtc(),
      endedAt: endedAt?.toUtc(),
      soldValue: soldValue,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
    );
    return _assets[i];
  }

  void deleteAsset(String id) {
    _assets.removeAt(_indexOf(_assets, id, (e) => e.id));
  }

  // recurring movements

  List<RecurringMovementEntity> recurringMovements() => [
    for (final r in _recurring) _recurringWithNames(r),
  ];

  RecurringMovementEntity _recurringWithNames(RecurringMovementEntity r) =>
      RecurringMovementEntity(
        id: r.id,
        userId: r.userId,
        name: r.name,
        description: r.description,
        value: r.value,
        categoryId: r.categoryId,
        tagId: r.tagId,
        categoryName: _categoryName(r.categoryId),
        tagName: _tagName(r.tagId),
        yearlyPayment: r.yearlyPayment,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  RecurringMovementEntity addRecurringMovement({
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
    required bool yearlyPayment,
    DateTime? createdAt,
  }) {
    final at = (createdAt ?? _stamp()).toUtc();
    final r = RecurringMovementEntity(
      id: newId(),
      userId: userId,
      name: name,
      description: _blankToNull(description),
      value: value,
      categoryId: categoryId,
      tagId: tagId,
      yearlyPayment: yearlyPayment,
      createdAt: at,
      updatedAt: at,
    );
    _recurring.add(r);
    return _recurringWithNames(r);
  }

  RecurringMovementEntity updateRecurringMovement({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
    required bool yearlyPayment,
  }) {
    final i = _indexOf(_recurring, id, (e) => e.id);
    final old = _recurring[i];
    _recurring[i] = RecurringMovementEntity(
      id: old.id,
      userId: old.userId,
      name: name,
      description: _blankToNull(description),
      value: value,
      categoryId: categoryId,
      tagId: tagId,
      yearlyPayment: yearlyPayment,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
    );
    return _recurringWithNames(_recurring[i]);
  }

  void deleteRecurringMovement(String id) {
    _recurring.removeAt(_indexOf(_recurring, id, (e) => e.id));
  }

  // wallet credits (headers of deferred purchases)

  WalletCreditEntity addCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  }) {
    final at = _stamp();
    final c = WalletCreditEntity(
      id: newId(),
      userId: userId,
      transactedAt: transactedAt.toUtc(),
      graceMonths: graceMonths,
      termMonths: termMonths,
      description: _blankToNull(description),
      createdAt: at,
      updatedAt: at,
    );
    _credits.add(c);
    return c;
  }

  WalletCreditEntity? credit(String id) {
    for (final c in _credits) {
      if (c.id == id) return c;
    }
    return null;
  }

  WalletCreditEntity updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
    DateTime? transactedAt,
  }) {
    final i = _indexOf(_credits, id, (e) => e.id);
    final old = _credits[i];
    _credits[i] = WalletCreditEntity(
      id: old.id,
      userId: old.userId,
      transactedAt: transactedAt?.toUtc() ?? old.transactedAt,
      graceMonths: graceMonths,
      termMonths: termMonths,
      description: old.description,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
      deletedAt: old.deletedAt,
    );
    return _credits[i];
  }

  // transactions

  TransactionEntity addTransaction({
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    bool ignore = false,
    double percentage = 100,
    String? transferGroupId,
    String? creditId,
  }) {
    final at = _stamp();
    final t = TransactionEntity(
      id: newId(),
      userId: userId,
      accountId: accountId,
      cardId: cardId,
      categoryId: categoryId,
      tagId: tagId,
      description: description,
      transactedAt: transactedAt.toUtc(),
      value: value,
      ignore: ignore,
      percentage: percentage,
      transferGroupId: transferGroupId,
      creditId: creditId,
      createdAt: at,
      updatedAt: at,
    );
    _transactions.add(t);
    return _withNames(t);
  }

  TransactionEntity updateTransaction({
    required String id,
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
    String? transferGroupId,
    String? creditId,
  }) {
    final i = _indexOf(_transactions, id, (e) => e.id);
    final old = _transactions[i];
    _transactions[i] = TransactionEntity(
      id: old.id,
      userId: old.userId,
      accountId: accountId,
      cardId: cardId,
      categoryId: categoryId,
      tagId: tagId,
      description: description,
      transactedAt: transactedAt.toUtc(),
      value: value,
      ignore: ignore,
      percentage: percentage,
      transferGroupId: transferGroupId,
      creditId: creditId,
      createdAt: old.createdAt,
      updatedAt: _stamp(),
    );
    return _withNames(_transactions[i]);
  }

  void deleteTransaction(String id) {
    _transactions.removeAt(_indexOf(_transactions, id, (e) => e.id));
  }

  /// Rows with [transactedAt] in [monthStartLocal]'s calendar month, newest first.
  List<TransactionEntity> transactionsForMonth(DateTime monthStartLocal) {
    final start = DateTime(monthStartLocal.year, monthStartLocal.month, 1);
    final end = DateTime(monthStartLocal.year, monthStartLocal.month + 1, 1);
    return _newestFirst(
      _transactions.where(
        (t) => !t.transactedAt.isBefore(start) && t.transactedAt.isBefore(end),
      ),
    );
  }

  /// Full history through the end of [yearStartLocal]'s year, newest first.
  List<TransactionEntity> transactionsForYear(DateTime yearStartLocal) {
    final end = DateTime(yearStartLocal.year + 1, 1, 1);
    return _newestFirst(_transactions.where((t) => t.transactedAt.isBefore(end)));
  }

  List<TransactionEntity> searchTransactions(String query, {int limit = 200}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _newestFirst(
      _transactions.where(
        (t) => (t.description ?? '').toLowerCase().contains(q),
      ),
    ).take(limit).toList();
  }

  List<TransactionEntity> transactionsHavingCreditGroup() =>
      _newestFirst(_transactions.where((t) => t.creditId != null));

  /// Installments of one credit, oldest first.
  List<TransactionEntity> transactionsByCreditId(String creditId) {
    if (creditId.isEmpty) return const [];
    final out = [
      for (final t in _transactions)
        if (t.creditId == creditId) _withNames(t),
    ];
    out.sort((a, b) => a.transactedAt.compareTo(b.transactedAt));
    return out;
  }

  List<TransactionEntity> _newestFirst(Iterable<TransactionEntity> rows) {
    final out = [for (final t in rows) _withNames(t)];
    out.sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
    return out;
  }

  TransactionEntity _withNames(TransactionEntity t) => TransactionEntity(
    id: t.id,
    userId: t.userId,
    accountId: t.accountId,
    cardId: t.cardId,
    categoryId: t.categoryId,
    tagId: t.tagId,
    accountName: _accountName(t.accountId),
    cardName: _cardName(t.cardId),
    categoryName: _categoryName(t.categoryId),
    tagName: _tagName(t.tagId),
    description: t.description,
    transactedAt: t.transactedAt,
    value: t.value,
    ignore: t.ignore,
    percentage: t.percentage,
    transferGroupId: t.transferGroupId,
    creditId: t.creditId,
    creditTransactedAt: t.creditId == null ? null : credit(t.creditId!)?.transactedAt,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  );

  String? _accountName(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  String? _cardName(String? id) {
    if (id == null) return null;
    for (final c in _cards) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  String? _categoryName(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  String? _tagName(String? id) {
    if (id == null) return null;
    for (final t in _tags) {
      if (t.id == id) return t.name;
    }
    return null;
  }
}
