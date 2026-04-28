import '../entities/tag_entity.dart';
import '../repositories/tags_repository.dart';

class GetTagsUsecase {
  final TagsRepository _repository;
  const GetTagsUsecase(this._repository);

  Future<List<TagEntity>> call() => _repository.getTags();
}
