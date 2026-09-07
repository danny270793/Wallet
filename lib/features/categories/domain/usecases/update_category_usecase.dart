import '../entities/category_entity.dart';
import '../repositories/categories_repository.dart';

class UpdateCategoryUsecase {
  final CategoriesRepository _repository;
  const UpdateCategoryUsecase(this._repository);

  Future<CategoryEntity> call({
    required String id,
    required String name,
    String? description,
  }) =>
      _repository.updateCategory(id: id, name: name, description: description);
}
