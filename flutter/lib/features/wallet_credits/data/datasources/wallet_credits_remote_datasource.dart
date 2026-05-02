import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/wallet_credit_entity.dart';

abstract class WalletCreditsRemoteDatasource {
  Future<WalletCreditEntity> insertCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  });

  Future<WalletCreditEntity?> fetchCredit(String id);

  Future<WalletCreditEntity> updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
  });
}

class WalletCreditsSupabaseDatasource implements WalletCreditsRemoteDatasource {
  final SupabaseClient _client;
  const WalletCreditsSupabaseDatasource(this._client);

  static const _select =
      'id,userId,transactedAt,graceMonths,termMonths,description,createdAt,updatedAt,deletedAt';

  @override
  Future<WalletCreditEntity> insertCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  }) async {
    AppLogger.debug('insertCredit');
    final row = <String, dynamic>{
      'userId': _client.auth.currentUser!.id,
      'transactedAt': transactedAt.toUtc().toIso8601String(),
      'graceMonths': graceMonths,
      'termMonths': termMonths,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    };
    final data = await _client
        .from('wallet_credits')
        .insert(row)
        .select(_select)
        .single();
    return WalletCreditEntity.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<WalletCreditEntity?> fetchCredit(String id) async {
    if (id.isEmpty) return null;
    final data = await _client.from('wallet_credits').select(_select).eq('id', id).maybeSingle();
    if (data == null) return null;
    return WalletCreditEntity.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<WalletCreditEntity> updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
  }) async {
    AppLogger.debug('updateCreditGracing: $id');
    final data = await _client
        .from('wallet_credits')
        .update({
          'graceMonths': graceMonths,
          'termMonths': termMonths,
        })
        .eq('id', id)
        .select(_select)
        .single();
    return WalletCreditEntity.fromJson(Map<String, dynamic>.from(data));
  }
}
