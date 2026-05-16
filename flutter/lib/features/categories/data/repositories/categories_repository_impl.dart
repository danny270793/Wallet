import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/offline_served_bundle.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/categories_repository.dart';
import '../datasources/categories_remote_datasource.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  final CategoriesRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const CategoriesRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<OfflineServedBundle<List<CategoryEntity>>> getCategories() => fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.categories,
        remote: _datasource.getCategories,
        fromJson: CategoryEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<CategoryEntity> createCategory({required String name, String? description}) =>
      _datasource.createCategory(name: name, description: description);

  @override
  Future<CategoryEntity> updateCategory({required String id, required String name, String? description}) =>
      _datasource.updateCategory(id: id, name: name, description: description);

  @override
  Future<void> deleteCategory({required String id}) => _datasource.deleteCategory(id: id);
}
