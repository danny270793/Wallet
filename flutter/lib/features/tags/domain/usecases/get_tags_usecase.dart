import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/tag_entity.dart';
import '../repositories/tags_repository.dart';

class GetTagsUsecase {
  final TagsRepository _repository;
  const GetTagsUsecase(this._repository);

  Future<OfflineServedBundle<List<TagEntity>>> call() => _repository.getTags();
}
