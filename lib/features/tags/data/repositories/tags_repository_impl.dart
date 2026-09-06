import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/offline_served_bundle.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/repositories/tags_repository.dart';
import '../datasources/tags_remote_datasource.dart';

class TagsRepositoryImpl implements TagsRepository {
  final TagsRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const TagsRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<OfflineServedBundle<List<TagEntity>>> getTags() => fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.tags,
        remote: _datasource.getTags,
        fromJson: TagEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<TagEntity> createTag({required String name, String? description}) =>
      _datasource.createTag(name: name, description: description);

  @override
  Future<TagEntity> updateTag({
    required String id,
    required String name,
    String? description,
    bool hidden = false,
  }) =>
      _datasource.updateTag(id: id, name: name, description: description, hidden: hidden);

  @override
  Future<void> deleteTag({required String id}) => _datasource.deleteTag(id: id);
}
