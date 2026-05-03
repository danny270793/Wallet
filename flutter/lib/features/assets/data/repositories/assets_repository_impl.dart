import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/repositories/assets_repository.dart';
import '../datasources/assets_remote_datasource.dart';

class AssetsRepositoryImpl implements AssetsRepository {
  final AssetsRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const AssetsRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<List<AssetEntity>> getAssets() => fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.assets,
        remote: _datasource.getAssets,
        fromJson: AssetEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<AssetEntity> createAsset({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) =>
      _datasource.createAsset(
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
  }) =>
      _datasource.updateAsset(
        id: id,
        name: name,
        provider: provider,
        value: value,
        boughtAt: boughtAt,
        endedAt: endedAt,
        soldValue: soldValue,
      );

  @override
  Future<void> deleteAsset({required String id}) =>
      _datasource.deleteAsset(id: id);
}
