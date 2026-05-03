import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/wallet_credit_entity.dart';
import '../../domain/repositories/wallet_credits_repository.dart';
import '../datasources/wallet_credits_remote_datasource.dart';

class WalletCreditsRepositoryImpl implements WalletCreditsRepository {
  final WalletCreditsRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const WalletCreditsRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<WalletCreditEntity> createCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  }) =>
      _datasource.insertCredit(
        transactedAt: transactedAt,
        graceMonths: graceMonths,
        termMonths: termMonths,
        description: description,
      );

  @override
  Future<WalletCreditEntity?> getCredit(String id) => fetchNullableWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.walletCredit(id),
        remote: () => _datasource.fetchCredit(id),
        fromJson: WalletCreditEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<WalletCreditEntity> updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
    DateTime? transactedAt,
  }) =>
      _datasource.updateCreditGracing(
        id: id,
        graceMonths: graceMonths,
        termMonths: termMonths,
        transactedAt: transactedAt,
      );
}
