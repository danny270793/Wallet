import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/category_entity.dart';
import '../repositories/categories_repository.dart';

class GetCategoriesUsecase {
  final CategoriesRepository _repository;
  const GetCategoriesUsecase(this._repository);

  Future<OfflineServedBundle<List<CategoryEntity>>> call() =>
      _repository.getCategories();
}
