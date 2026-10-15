import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/category_entity.dart';

abstract class CategoriesRepository {
  Future<OfflineServedBundle<List<CategoryEntity>>> getCategories();
  Future<CategoryEntity> createCategory({
    required String name,
    String? description,
  });
  Future<CategoryEntity> updateCategory({
    required String id,
    required String name,
    String? description,
  });
  Future<void> deleteCategory({required String id});
}
