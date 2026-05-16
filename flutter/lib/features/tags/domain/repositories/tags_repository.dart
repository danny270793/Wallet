import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/tag_entity.dart';

abstract class TagsRepository {
  Future<OfflineServedBundle<List<TagEntity>>> getTags();
  Future<TagEntity> createTag({required String name, String? description});
  Future<TagEntity> updateTag({required String id, required String name, String? description});
  Future<void> deleteTag({required String id});
}
