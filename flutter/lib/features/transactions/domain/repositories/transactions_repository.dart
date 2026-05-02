import '../entities/transaction_entity.dart';

abstract class TransactionsRepository {
  Future<List<TransactionEntity>> getTransactionsForMonth(DateTime monthStartLocal);
  Future<List<TransactionEntity>> getTransactionsForYear(DateTime yearStartLocal);
  Future<List<TransactionEntity>> searchTransactionsByDescription(String query, {int limit = 200});
  Future<List<TransactionEntity>> getTransactionsByCreditGroupId(String creditId);

  Future<List<TransactionEntity>> listTransactionsHavingCreditGroup();

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
    String? transferGroupId,
    String? creditId,
  });
  Future<void> deleteTransaction({required String id});
}
