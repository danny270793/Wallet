import '../repositories/categories_repository.dart';

class DeleteCategoryUsecase {
  final CategoriesRepository _repository;
  const DeleteCategoryUsecase(this._repository);

  Future<void> call({required String id}) => _repository.deleteCategory(id: id);
}
