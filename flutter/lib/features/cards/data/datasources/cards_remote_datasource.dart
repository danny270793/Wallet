import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/card_entity.dart';
import '../../domain/entities/card_type.dart';

abstract class CardsRemoteDatasource {
  Future<List<CardEntity>> getCards();
  Future<CardEntity> createCard({
    required String name,
    required CardType type,
    double? nominalInterestRate,
    int cutDay = 24,
    int payDay = 24,
  });
  Future<CardEntity> updateCard({
    required String id,
    required String name,
    required CardType type,
    double? nominalInterestRate,
    required int cutDay,
    required int payDay,
  });
  Future<void> deleteCard({required String id});
}

class CardsSupabaseDatasource implements CardsRemoteDatasource {
  final SupabaseClient _client;
  const CardsSupabaseDatasource(this._client);

  @override
  Future<List<CardEntity>> getCards() async {
    AppLogger.debug('getCards called');
    final data = await _client
        .from('wallet_cards_with_balance')
        .select(
          // Explicit columns: omit legacy balanceWeighted if present on older deployments.
          'id, userId, name, type, cutDay, payDay, nominalInterestRate, createdAt, updatedAt, deletedAt, balance',
        )
        .isFilter('deletedAt', null)
        .order('createdAt');
    return (data as List)
        .map((e) => CardEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CardEntity> createCard({
    required String name,
    required CardType type,
    double? nominalInterestRate,
    int cutDay = 24,
    int payDay = 24,
  }) async {
    AppLogger.debug('createCard called: $name');
    final data = await _client
        .from('wallet_cards')
        .insert({
          'userId': _client.auth.currentUser!.id,
          'name': name,
          'type': type.wireValue,
          'cutDay': cutDay,
          'payDay': payDay,
          'nominalInterestRate': nominalInterestRate,
        })
        .select()
        .single();
    return CardEntity.fromJson(data);
  }

  @override
  Future<CardEntity> updateCard({
    required String id,
    required String name,
    required CardType type,
    double? nominalInterestRate,
    required int cutDay,
    required int payDay,
  }) async {
    AppLogger.debug('updateCard called: $id');
    final data = await _client
        .from('wallet_cards')
        .update({
          'name': name,
          'type': type.wireValue,
          'nominalInterestRate': nominalInterestRate,
          'cutDay': cutDay,
          'payDay': payDay,
        })
        .eq('id', id)
        .select()
        .single();
    return CardEntity.fromJson(data);
  }

  @override
  Future<void> deleteCard({required String id}) async {
    AppLogger.debug('deleteCard called: $id');
    final ok = await _client.rpc<bool>(
      'soft_delete_wallet_card',
      params: {'p_id': id},
    );
    if (ok != true) {
      throw Exception('soft_delete_wallet_card: no row updated for $id');
    }
  }
}
