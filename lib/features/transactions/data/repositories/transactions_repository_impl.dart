import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/offline_served_bundle.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../datasources/transactions_remote_datasource.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  final TransactionsRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const TransactionsRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<OfflineServedBundle<List<TransactionEntity>>> getTransactionsForMonth(DateTime monthStartLocal) =>
      fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.transactionsMonth(monthStartLocal),
        remote: () => _datasource.getTransactionsForMonth(monthStartLocal),
        fromJson: TransactionEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<OfflineServedBundle<List<TransactionEntity>>> getTransactionsForYear(DateTime yearStartLocal) =>
      fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.transactionsYear(yearStartLocal),
        remote: () => _datasource.getTransactionsForYear(yearStartLocal),
        fromJson: TransactionEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<List<TransactionEntity>> searchTransactionsByDescription(String query, {int limit = 200}) =>
      _datasource.searchTransactionsByDescription(query, limit: limit);

  @override
  Future<OfflineServedBundle<List<TransactionEntity>>> getTransactionsByCreditGroupId(String creditId) =>
      fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.transactionsByCredit(creditId),
        remote: () => _datasource.getTransactionsByCreditGroupId(creditId),
        fromJson: TransactionEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<OfflineServedBundle<List<TransactionEntity>>> listTransactionsHavingCreditGroup() => fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.transactionsHavingCreditGroup,
        remote: _datasource.listTransactionsHavingCreditGroup,
        fromJson: TransactionEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

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
