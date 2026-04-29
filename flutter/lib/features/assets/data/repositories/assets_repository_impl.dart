import '../../domain/entities/asset_entity.dart';
import '../../domain/repositories/assets_repository.dart';
import '../datasources/assets_remote_datasource.dart';

class AssetsRepositoryImpl implements AssetsRepository {
  final AssetsRemoteDatasource _datasource;
  const AssetsRepositoryImpl(this._datasource);

  @override
  Future<List<AssetEntity>> getAssets() => _datasource.getAssets();

  @override
  Future<AssetEntity> createAsset({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) =>
      _datasource.createAsset(
        name: name,
        provider: provider,
        value: value,
        boughtAt: boughtAt,
        endedAt: endedAt,
        soldValue: soldValue,
      );

  @override
  Future<AssetEntity> updateAsset({
    required String id,
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) =>
      _datasource.updateAsset(
        id: id,
        name: name,
        provider: provider,
        value: value,
        boughtAt: boughtAt,
        endedAt: endedAt,
        soldValue: soldValue,
      );

  @override
  Future<void> deleteAsset({required String id}) =>
      _datasource.deleteAsset(id: id);
}
