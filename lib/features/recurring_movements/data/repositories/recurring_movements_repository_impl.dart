import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/offline_served_bundle.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/recurring_movement_entity.dart';
import '../../domain/repositories/recurring_movements_repository.dart';
import '../datasources/recurring_movements_remote_datasource.dart';

class RecurringMovementsRepositoryImpl implements RecurringMovementsRepository {
  final RecurringMovementsRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const RecurringMovementsRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<OfflineServedBundle<List<RecurringMovementEntity>>>
  getRecurringMovements() => fetchListWithOfflineCache(
    session: _offlineSession,
    cache: _offlineCache,
    cacheKey: WalletOfflineCacheKeys.recurringMovements,
    remote: _datasource.getRecurringMovements,
    fromJson: RecurringMovementEntity.fromJson,
    toJson: (e) => e.toJson(),
  );

  @override
  Future<RecurringMovementEntity> createRecurringMovement({
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  }) => _datasource.createRecurringMovement(
    name: name,
    description: description,
    value: value,
    categoryId: categoryId,
    tagId: tagId,
  );

  @override
  Future<RecurringMovementEntity> updateRecurringMovement({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  }) => _datasource.updateRecurringMovement(
    id: id,
    name: name,
    description: description,
    value: value,
    categoryId: categoryId,
    tagId: tagId,
  );

  @override
  Future<void> deleteRecurringMovement({required String id}) =>
      _datasource.deleteRecurringMovement(id: id);
}
