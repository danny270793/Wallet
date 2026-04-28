import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/categories_repository.dart';
import '../datasources/categories_remote_datasource.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  final CategoriesRemoteDatasource _datasource;
  const CategoriesRepositoryImpl(this._datasource);

  @override
  Future<List<CategoryEntity>> getCategories() => _datasource.getCategories();

  @override
  Future<CategoryEntity> createCategory({required String name, String? description}) =>
      _datasource.createCategory(name: name, description: description);

  @override
  Future<CategoryEntity> updateCategory({required String id, required String name, String? description}) =>
      _datasource.updateCategory(id: id, name: name, description: description);

  @override
  Future<void> deleteCategory({required String id}) => _datasource.deleteCategory(id: id);
}
