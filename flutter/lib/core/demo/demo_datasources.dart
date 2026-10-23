import '../../features/accounts/data/datasources/accounts_remote_datasource.dart';
import '../../features/accounts/domain/entities/account_entity.dart';
import '../../features/assets/data/datasources/assets_remote_datasource.dart';
import '../../features/assets/domain/entities/asset_entity.dart';
import '../../features/cards/data/datasources/cards_remote_datasource.dart';
import '../../features/cards/domain/entities/card_entity.dart';
import '../../features/cards/domain/entities/card_type.dart';
import '../../features/categories/data/datasources/categories_remote_datasource.dart';
import '../../features/categories/domain/entities/category_entity.dart';
import '../../features/loans/data/datasources/loan_capital_payments_remote_datasource.dart';
import '../../features/loans/data/datasources/loans_remote_datasource.dart';
import '../../features/loans/domain/entities/loan_capital_payment_entity.dart';
import '../../features/loans/domain/entities/loan_entity.dart';
import '../../features/recurring_movements/data/datasources/recurring_movements_remote_datasource.dart';
import '../../features/recurring_movements/domain/entities/recurring_movement_entity.dart';
import '../../features/tags/data/datasources/tags_remote_datasource.dart';
import '../../features/tags/domain/entities/tag_entity.dart';
import '../../features/transactions/data/datasources/transactions_remote_datasource.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import '../../features/wallet_credits/data/datasources/wallet_credits_remote_datasource.dart';
import '../../features/wallet_credits/domain/entities/wallet_credit_entity.dart';
import 'demo_store.dart';

// Demo-mode implementations of the remote datasources. They read and write the
// in-memory [DemoStore] and never touch the network.

class AccountsDemoDatasource implements AccountsRemoteDatasource {
  const AccountsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<AccountEntity>> getAccounts() async => _store.accounts();

  @override
  Future<AccountEntity> createAccount({required String name}) async =>
      _store.addAccount(name);

  @override
  Future<AccountEntity> updateAccount({
    required String id,
    required String name,
  }) async => _store.updateAccount(id, name);

  @override
  Future<void> deleteAccount({required String id}) async =>
      _store.deleteAccount(id);
}

class CardsDemoDatasource implements CardsRemoteDatasource {
  const CardsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<CardEntity>> getCards() async => _store.cards();

  @override
  Future<CardEntity> createCard({
    required String name,
    required CardType type,
    double? nominalInterestRate,
    int cutDay = 24,
    int payDay = 24,
  }) async => _store.addCard(
    name: name,
    type: type,
    nominalInterestRate: nominalInterestRate,
    cutDay: cutDay,
    payDay: payDay,
  );

  @override
  Future<CardEntity> updateCard({
    required String id,
    required String name,
    required CardType type,
    double? nominalInterestRate,
    required int cutDay,
    required int payDay,
  }) async => _store.updateCard(
    id: id,
    name: name,
    type: type,
    nominalInterestRate: nominalInterestRate,
    cutDay: cutDay,
    payDay: payDay,
  );

  @override
  Future<void> deleteCard({required String id}) async => _store.deleteCard(id);
}

class CategoriesDemoDatasource implements CategoriesRemoteDatasource {
  const CategoriesDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<CategoryEntity>> getCategories() async => _store.categories();

  @override
  Future<CategoryEntity> createCategory({
    required String name,
    String? description,
  }) async => _store.addCategory(name, description: description);

  @override
  Future<CategoryEntity> updateCategory({
    required String id,
    required String name,
    String? description,
  }) async => _store.updateCategory(id, name, description);

  @override
  Future<void> deleteCategory({required String id}) async =>
      _store.deleteCategory(id);
}

class TagsDemoDatasource implements TagsRemoteDatasource {
  const TagsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<TagEntity>> getTags() async => _store.tags();

  @override
  Future<TagEntity> createTag({
    required String name,
    String? description,
  }) async => _store.addTag(name, description: description);

  @override
  Future<TagEntity> updateTag({
    required String id,
    required String name,
    String? description,
    bool hidden = false,
  }) async => _store.updateTag(
    id: id,
    name: name,
    description: description,
    hidden: hidden,
  );

  @override
  Future<void> deleteTag({required String id}) async => _store.deleteTag(id);
}

class LoansDemoDatasource implements LoansRemoteDatasource {
  const LoansDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<LoanEntity>> getLoans() async => _store.loans();

  @override
  Future<LoanEntity> createLoan({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) async => _store.addLoan(
    accountId: accountId,
    name: name,
    value: value,
    nominalInterestRate: nominalInterestRate,
    termMonths: termMonths,
    paymentDay: paymentDay,
    firstPaymentDate: firstPaymentDate,
  );

  @override
  Future<LoanEntity> updateLoan({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) async => _store.updateLoan(
    id: id,
    accountId: accountId,
    name: name,
    value: value,
    nominalInterestRate: nominalInterestRate,
    termMonths: termMonths,
    paymentDay: paymentDay,
    firstPaymentDate: firstPaymentDate,
  );

  @override
  Future<void> deleteLoan({required String id}) async => _store.deleteLoan(id);
}

class LoanCapitalPaymentsDemoDatasource
    implements LoanCapitalPaymentsRemoteDatasource {
  const LoanCapitalPaymentsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<LoanCapitalPaymentEntity>> getCapitalPayments() async =>
      _store.capitalPayments();

  @override
  Future<LoanCapitalPaymentEntity> createCapitalPayment({
    required String loanId,
    required double value,
    required DateTime paidAt,
  }) async =>
      _store.addCapitalPayment(loanId: loanId, value: value, paidAt: paidAt);

  @override
  Future<void> deleteCapitalPayment({required String id}) async =>
      _store.deleteCapitalPayment(id);
}

class AssetsDemoDatasource implements AssetsRemoteDatasource {
  const AssetsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<AssetEntity>> getAssets() async => _store.assets();

  @override
  Future<AssetEntity> createAsset({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) async => _store.addAsset(
    name: name,
    provider: provider,
    value: value,
    boughtAt: boughtAt,
    endedAt: endedAt,
    soldValue: soldValue,
  );

  @override
  Future<AssetEntity> updateAsset({
    required String id,
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) async => _store.updateAsset(
    id: id,
    name: name,
    provider: provider,
    value: value,
    boughtAt: boughtAt,
    endedAt: endedAt,
    soldValue: soldValue,
  );

  @override
  Future<void> deleteAsset({required String id}) async =>
      _store.deleteAsset(id);
}

class RecurringMovementsDemoDatasource
    implements RecurringMovementsRemoteDatasource {
  const RecurringMovementsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<RecurringMovementEntity>> getRecurringMovements() async =>
      _store.recurringMovements();

  @override
  Future<RecurringMovementEntity> createRecurringMovement({
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
    required bool yearlyPayment,
  }) async => _store.addRecurringMovement(
    name: name,
    description: description,
    value: value,
    categoryId: categoryId,
    tagId: tagId,
    yearlyPayment: yearlyPayment,
  );

  @override
  Future<RecurringMovementEntity> updateRecurringMovement({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
    required bool yearlyPayment,
  }) async => _store.updateRecurringMovement(
    id: id,
    name: name,
    description: description,
    value: value,
    categoryId: categoryId,
    tagId: tagId,
    yearlyPayment: yearlyPayment,
  );

  @override
  Future<void> deleteRecurringMovement({required String id}) async =>
      _store.deleteRecurringMovement(id);
}

class WalletCreditsDemoDatasource implements WalletCreditsRemoteDatasource {
  const WalletCreditsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<WalletCreditEntity> insertCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  }) async => _store.addCredit(
    transactedAt: transactedAt,
    graceMonths: graceMonths,
    termMonths: termMonths,
    description: description,
  );

  @override
  Future<WalletCreditEntity?> fetchCredit(String id) async =>
      id.isEmpty ? null : _store.credit(id);

  @override
  Future<WalletCreditEntity> updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
    DateTime? transactedAt,
  }) async => _store.updateCreditGracing(
    id: id,
    graceMonths: graceMonths,
    termMonths: termMonths,
    transactedAt: transactedAt,
  );
}

class TransactionsDemoDatasource implements TransactionsRemoteDatasource {
  const TransactionsDemoDatasource(this._store);

  final DemoStore _store;

  @override
  Future<List<TransactionEntity>> getTransactionsForMonth(
    DateTime monthStartLocal,
  ) async => _store.transactionsForMonth(monthStartLocal);

  @override
  Future<List<TransactionEntity>> getTransactionsForYear(
    DateTime yearStartLocal,
  ) async => _store.transactionsForYear(yearStartLocal);

  @override
  Future<List<TransactionEntity>> searchTransactionsByDescription(
    String query, {
    int limit = 200,
  }) async => _store.searchTransactions(query, limit: limit);

  @override
  Future<List<TransactionEntity>> listTransactionsHavingCreditGroup() async =>
      _store.transactionsHavingCreditGroup();

  @override
  Future<List<TransactionEntity>> getTransactionsByCreditGroupId(
    String creditId,
  ) async => _store.transactionsByCreditId(creditId);

  @override
  Future<TransactionEntity> createTransaction({
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
  }) async => _store.addTransaction(
    accountId: accountId,
    cardId: cardId,
    categoryId: categoryId,
    tagId: tagId,
    description: description,
    transactedAt: transactedAt,
    value: value,
    ignore: ignore,
    percentage: percentage,
    transferGroupId: transferGroupId,
    creditId: creditId,
  );

  @override
  Future<TransactionEntity> updateTransaction({
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
  }) async => _store.updateTransaction(
    id: id,
    accountId: accountId,
    cardId: cardId,
    categoryId: categoryId,
    tagId: tagId,
    description: description,
    transactedAt: transactedAt,
    value: value,
    ignore: ignore,
    percentage: percentage,
    transferGroupId: transferGroupId,
    creditId: creditId,
  );

  @override
  Future<void> deleteTransaction({required String id}) async =>
      _store.deleteTransaction(id);
}
