import '../entities/tag_entity.dart';
import '../repositories/tags_repository.dart';

class UpdateTagUsecase {
  final TagsRepository _repository;
  const UpdateTagUsecase(this._repository);

  Future<TagEntity> call({
    required String id,
    required String name,
    String? description,
    bool hidden = false,
  }) =>
      _repository.updateTag(id: id, name: name, description: description, hidden: hidden);
}
