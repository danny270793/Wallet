import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/asset_entity.dart';

abstract class AssetsRemoteDatasource {
  Future<List<AssetEntity>> getAssets();
  Future<AssetEntity> createAsset({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  });

  Future<AssetEntity> updateAsset({
    required String id,
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  });

  Future<void> deleteAsset({required String id});
}

class AssetsSupabaseDatasource implements AssetsRemoteDatasource {
  final SupabaseClient _client;
  const AssetsSupabaseDatasource(this._client);

  @override
  Future<List<AssetEntity>> getAssets() async {
    AppLogger.debug('getAssets called');
    final data = await _client
        .from('wallet_assets')
        .select()
        .isFilter('deletedAt', null)
        .order('boughtAt', ascending: false);
    return (data as List)
        .map((e) => AssetEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AssetEntity> createAsset({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) async {
    AppLogger.debug('createAsset called: $name');
    final row = <String, dynamic>{
      'userId': _client.auth.currentUser!.id,
      'name': name,
      'provider': provider,
      'value': value,
      'boughtAt': boughtAt.toUtc().toIso8601String(),
      if (endedAt case final e?) 'endedAt': e.toUtc().toIso8601String(),
      if (soldValue case final v?) 'soldValue': v,
    };
    final dynamic data =
        await _client.from('wallet_assets').insert(row).select().single();
    final map = Map<String, dynamic>.from(data as Map);
    return AssetEntity.fromJson(map);
  }

  @override
  Future<AssetEntity> updateAsset({
    required String id,
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) async {
    AppLogger.debug('updateAsset called: $id');
    final row = <String, dynamic>{
      'name': name,
      'provider': provider,
      'value': value,
      'boughtAt': boughtAt.toUtc().toIso8601String(),
      'endedAt': endedAt?.toUtc().toIso8601String(),
      'soldValue': soldValue,
    };
    final dynamic data =
        await _client.from('wallet_assets').update(row).eq('id', id).select().single();
    final map = Map<String, dynamic>.from(data as Map);
    return AssetEntity.fromJson(map);
  }

  @override
  Future<void> deleteAsset({required String id}) async {
    AppLogger.debug('deleteAsset called: $id');
    final ok = await _client.rpc<bool>(
      'soft_delete_wallet_asset',
      params: {'p_id': id},
    );
    if (ok != true) {
      throw Exception('soft_delete_wallet_asset: no row updated for $id');
    }
  }
}
