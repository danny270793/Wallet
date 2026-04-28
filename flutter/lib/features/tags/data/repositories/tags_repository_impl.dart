import '../../domain/entities/tag_entity.dart';
import '../../domain/repositories/tags_repository.dart';
import '../datasources/tags_remote_datasource.dart';

class TagsRepositoryImpl implements TagsRepository {
  final TagsRemoteDatasource _datasource;
  const TagsRepositoryImpl(this._datasource);

  @override
  Future<List<TagEntity>> getTags() => _datasource.getTags();

  @override
  Future<TagEntity> createTag({required String name, String? description}) =>
      _datasource.createTag(name: name, description: description);

  @override
  Future<TagEntity> updateTag({required String id, required String name, String? description}) =>
      _datasource.updateTag(id: id, name: name, description: description);

  @override
  Future<void> deleteTag({required String id}) => _datasource.deleteTag(id: id);
}
