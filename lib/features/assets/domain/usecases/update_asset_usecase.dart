import '../entities/asset_entity.dart';
import '../repositories/assets_repository.dart';

class UpdateAssetUsecase {
  final AssetsRepository _repository;
  const UpdateAssetUsecase(this._repository);

  Future<AssetEntity> call({
    required String id,
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) =>
      _repository.updateAsset(
        id: id,
        name: name,
        provider: provider,
        value: value,
        boughtAt: boughtAt,
        endedAt: endedAt,
        soldValue: soldValue,
      );
}
