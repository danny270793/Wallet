import '../entities/asset_entity.dart';

abstract class AssetsRepository {
  Future<List<AssetEntity>> getAssets();
}
