import '../entities/category_entity.dart';
import '../repositories/categories_repository.dart';

class CreateCategoryUsecase {
  final CategoriesRepository _repository;
  const CreateCategoryUsecase(this._repository);

  Future<CategoryEntity> call({required String name, String? description}) =>
      _repository.createCategory(name: name, description: description);
}
