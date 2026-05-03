import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/transaction_entity.dart';

abstract class TransactionsRepository {
  Future<OfflineServedBundle<List<TransactionEntity>>> getTransactionsForMonth(DateTime monthStartLocal);
  /// All non-deleted transactions with [transactedAt] before Jan 1 of the year after
  /// [yearStartLocal] (i.e. full history through the end of that calendar year), newest first.
  Future<OfflineServedBundle<List<TransactionEntity>>> getTransactionsForYear(DateTime yearStartLocal);
  Future<List<TransactionEntity>> searchTransactionsByDescription(String query, {int limit = 200});
  Future<OfflineServedBundle<List<TransactionEntity>>> getTransactionsByCreditGroupId(String creditId);

  Future<OfflineServedBundle<List<TransactionEntity>>> listTransactionsHavingCreditGroup();

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
