import '../entities/tag_entity.dart';

abstract class TagsRepository {
  Future<List<TagEntity>> getTags();
  Future<TagEntity> createTag({required String name, String? description});
  Future<TagEntity> updateTag({required String id, required String name, String? description});
  Future<void> deleteTag({required String id});
}
