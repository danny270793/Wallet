import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/sort_by_name.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/create_category_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';
import '../../domain/usecases/delete_category_usecase.dart';
import 'categories_state.dart';

class CategoriesCubit extends Cubit<CategoriesState> {
  final GetCategoriesUsecase _getCategories;
  final CreateCategoryUsecase _createCategory;
  final UpdateCategoryUsecase _updateCategory;
  final DeleteCategoryUsecase _deleteCategory;

  CategoriesCubit({
    required GetCategoriesUsecase getCategories,
    required CreateCategoryUsecase createCategory,
    required UpdateCategoryUsecase updateCategory,
    required DeleteCategoryUsecase deleteCategory,
  })  : _getCategories = getCategories,
        _createCategory = createCategory,
        _updateCategory = updateCategory,
        _deleteCategory = deleteCategory,
        super(const CategoriesInitial());

  Future<void> load() async {
    AppLogger.debug('loading categories');
    emit(const CategoriesLoading());
    try {
      final categories = sortedByName(await _getCategories(), (c) => c.name);
      AppLogger.info('categories loaded: ${categories.length}');
      emit(CategoriesLoaded(categories));
    } catch (e, s) {
      AppLogger.error('failed to load categories', e, s);
      emit(const CategoriesError());
    }
  }

  Future<void> create({required String name, String? description}) async {
    final current = _currentCategories();
    AppLogger.debug('creating category: $name');
    try {
      final category = await _createCategory(name: name, description: description);
      AppLogger.info('category created: ${category.id}');
      emit(CategoriesLoaded(sortedByName([...current, category], (c) => c.name)));
    } catch (e, s) {
      AppLogger.error('failed to create category', e, s);
      emit(CategoriesActionError(current));
    }
  }

  Future<void> update({required String id, required String name, String? description}) async {
    final current = _currentCategories();
    AppLogger.debug('updating category: $id');
    try {
      final updated = await _updateCategory(id: id, name: name, description: description);
      AppLogger.info('category updated: ${updated.id}');
      emit(CategoriesLoaded(
        sortedByName(
          current.map((a) => a.id == id ? updated : a).toList(),
          (c) => c.name,
        ),
      ));
    } catch (e, s) {
      AppLogger.error('failed to update category', e, s);
      emit(CategoriesActionError(current));
    }
  }

  Future<bool> delete({required String id}) async {
    final current = _currentCategories();
    AppLogger.debug('deleting category: $id');
    try {
      await _deleteCategory(id: id);
      AppLogger.info('category deleted: $id');
      emit(CategoriesLoaded(
        sortedByName(current.where((a) => a.id != id).toList(), (c) => c.name),
      ));
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete category', e, s);
      emit(CategoriesActionError(current));
      return false;
    }
  }

  List<CategoryEntity> _currentCategories() => switch (state) {
    CategoriesLoaded(:final categories) => categories,
    CategoriesActionError(:final categories) => categories,
    _ => [],
  };
}
