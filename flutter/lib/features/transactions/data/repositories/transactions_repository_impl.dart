import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../datasources/transactions_remote_datasource.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  final TransactionsRemoteDatasource _datasource;
  const TransactionsRepositoryImpl(this._datasource);

  @override
  Future<List<TransactionEntity>> getTransactionsForMonth(DateTime monthStartLocal) =>
      _datasource.getTransactionsForMonth(monthStartLocal);

  @override
  Future<List<TransactionEntity>> getTransactionsForYear(DateTime yearStartLocal) =>
      _datasource.getTransactionsForYear(yearStartLocal);

  @override
  Future<List<TransactionEntity>> searchTransactionsByDescription(String query, {int limit = 200}) =>
      _datasource.searchTransactionsByDescription(query, limit: limit);

  @override
  Future<List<TransactionEntity>> getTransactionsByCreditGroupId(String creditId) =>
      _datasource.getTransactionsByCreditGroupId(creditId);

  @override
  Future<List<TransactionEntity>> listTransactionsHavingCreditGroup() =>
      _datasource.listTransactionsHavingCreditGroup();

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
  }) =>
      _datasource.createTransaction(
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
  }) =>
      _datasource.updateTransaction(
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
  Future<void> deleteTransaction({required String id}) => _datasource.deleteTransaction(id: id);
}
