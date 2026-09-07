import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/category_entity.dart';

abstract class CategoriesRemoteDatasource {
  Future<List<CategoryEntity>> getCategories();
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

class CategoriesSupabaseDatasource implements CategoriesRemoteDatasource {
  final SupabaseClient _client;
  const CategoriesSupabaseDatasource(this._client);

  @override
  Future<List<CategoryEntity>> getCategories() async {
    AppLogger.debug('getCategories called');
    final data = await _client
        .from('wallet_categories')
        .select()
        .isFilter('deletedAt', null)
        .order('createdAt');
    return (data as List)
        .map((e) => CategoryEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CategoryEntity> createCategory({
    required String name,
    String? description,
  }) async {
    AppLogger.debug('createCategory called: $name');
    final data = await _client
        .from('wallet_categories')
        .insert({
          'userId': _client.auth.currentUser!.id,
          'name': name,
          if (description != null) 'description': description,
        })
        .select()
        .single();
    return CategoryEntity.fromJson(data);
  }

  @override
  Future<CategoryEntity> updateCategory({
    required String id,
    required String name,
    String? description,
  }) async {
    AppLogger.debug('updateCategory called: $id');
    final data = await _client
        .from('wallet_categories')
        .update({'name': name, 'description': description})
        .eq('id', id)
        .select()
        .single();
    return CategoryEntity.fromJson(data);
  }

  @override
  Future<void> deleteCategory({required String id}) async {
    AppLogger.debug('deleteCategory called: $id');
    final ok = await _client.rpc<bool>(
      'soft_delete_wallet_category',
      params: {'p_id': id},
    );
    if (ok != true) {
      throw Exception('soft_delete_wallet_category: no row updated for $id');
    }
  }
}
