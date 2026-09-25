import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/recurring_movement_entity.dart';

abstract class RecurringMovementsRemoteDatasource {
  Future<List<RecurringMovementEntity>> getRecurringMovements();
  Future<RecurringMovementEntity> createRecurringMovement({
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  });
  Future<RecurringMovementEntity> updateRecurringMovement({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  });
  Future<void> deleteRecurringMovement({required String id});
}

class RecurringMovementsSupabaseDatasource
    implements RecurringMovementsRemoteDatasource {
  final SupabaseClient _client;
  const RecurringMovementsSupabaseDatasource(this._client);

  static const _table = 'wallet_recurring_movements';
  static const _selectEmbedded =
      '*, wallet_categories(name), wallet_tags(name)';

  @override
  Future<List<RecurringMovementEntity>> getRecurringMovements() async {
    AppLogger.debug('getRecurringMovements called');
    final data = await _client
        .from(_table)
        .select(_selectEmbedded)
        .isFilter('deletedAt', null)
        .order('createdAt');
    return (data as List)
        .map((e) => RecurringMovementEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RecurringMovementEntity> createRecurringMovement({
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  }) async {
    AppLogger.debug('createRecurringMovement called: $name');
    final data = await _client
        .from(_table)
        .insert({
          'userId': _client.auth.currentUser!.id,
          'name': name,
          if (description != null) 'description': description,
          'value': value,
          'categoryId': categoryId,
          'tagId': tagId,
        })
        .select(_selectEmbedded)
        .single();
    return RecurringMovementEntity.fromJson(data);
  }

  @override
  Future<RecurringMovementEntity> updateRecurringMovement({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  }) async {
    AppLogger.debug('updateRecurringMovement called: $id');
    final data = await _client
        .from(_table)
        .update({
          'name': name,
          'description': description,
          'value': value,
          'categoryId': categoryId,
          'tagId': tagId,
        })
        .eq('id', id)
        .select(_selectEmbedded)
        .single();
    return RecurringMovementEntity.fromJson(data);
  }

  @override
  Future<void> deleteRecurringMovement({required String id}) async {
    AppLogger.debug('deleteRecurringMovement called: $id');
    final ok = await _client.rpc<bool>(
      'soft_delete_wallet_recurring_movement',
      params: {'p_id': id},
    );
    if (ok != true) {
      throw Exception(
        'soft_delete_wallet_recurring_movement: no row updated for $id',
      );
    }
  }
}
