import '../entities/transaction_entity.dart';

abstract class TransactionsRepository {
  Future<List<TransactionEntity>> getTransactionsForMonth(DateTime monthStartLocal);
  Future<Map<String, double>> sumTransactionValuesByAccountId();
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
  });
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
  });
  Future<void> deleteTransaction({required String id});
}
