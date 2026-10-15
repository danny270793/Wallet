import '../repositories/tags_repository.dart';

class DeleteTagUsecase {
  final TagsRepository _repository;
  const DeleteTagUsecase(this._repository);

  Future<void> call({required String id}) => _repository.deleteTag(id: id);
}
