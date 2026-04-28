import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/tag_entity.dart';

abstract class TagsRemoteDatasource {
  Future<List<TagEntity>> getTags();
  Future<TagEntity> createTag({required String name, String? description});
  Future<TagEntity> updateTag({required String id, required String name, String? description});
  Future<void> deleteTag({required String id});
}

class TagsSupabaseDatasource implements TagsRemoteDatasource {
  final SupabaseClient _client;
  const TagsSupabaseDatasource(this._client);

  @override
  Future<List<TagEntity>> getTags() async {
    AppLogger.debug('getTags called');
    final data = await _client
        .from('wallet_tags')
        .select()
        .isFilter('deletedAt', null)
        .order('createdAt');
    return (data as List).map((e) => TagEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<TagEntity> createTag({required String name, String? description}) async {
    AppLogger.debug('createTag called: $name');
    final data = await _client
        .from('wallet_tags')
        .insert({
          'userId': _client.auth.currentUser!.id,
          'name': name,
          if (description != null) 'description': description,
        })
        .select()
        .single();
    return TagEntity.fromJson(data);
  }

  @override
  Future<TagEntity> updateTag({
    required String id,
    required String name,
    String? description,
  }) async {
    AppLogger.debug('updateTag called: $id');
    final data = await _client
        .from('wallet_tags')
        .update({'name': name, 'description': description})
        .eq('id', id)
        .select()
        .single();
    return TagEntity.fromJson(data);
  }

  @override
  Future<void> deleteTag({required String id}) async {
    AppLogger.debug('deleteTag called: $id');
    await _client
        .from('wallet_tags')
        .update({'deletedAt': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
