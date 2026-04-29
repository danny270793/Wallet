import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/asset_entity.dart';

abstract class AssetsRemoteDatasource {
  Future<List<AssetEntity>> getAssets();
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
}
