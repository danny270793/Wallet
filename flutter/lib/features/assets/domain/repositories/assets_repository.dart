import '../entities/asset_entity.dart';

abstract class AssetsRepository {
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
