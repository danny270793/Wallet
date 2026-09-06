import '../entities/tag_entity.dart';
import '../repositories/tags_repository.dart';

class CreateTagUsecase {
  final TagsRepository _repository;
  const CreateTagUsecase(this._repository);

  Future<TagEntity> call({required String name, String? description}) =>
      _repository.createTag(name: name, description: description);
}
