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
  Future<Map<String, double>> sumTransactionValuesByAccountId() =>
      _datasource.sumTransactionValuesByAccountId();

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
      );

  @override
  Future<void> deleteTransaction({required String id}) => _datasource.deleteTransaction(id: id);
}
