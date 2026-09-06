import '../entities/asset_entity.dart';
import '../repositories/assets_repository.dart';

class CreateAssetUsecase {
  final AssetsRepository _repository;
  const CreateAssetUsecase(this._repository);

  Future<AssetEntity> call({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) =>
      _repository.createAsset(
        name: name,
        provider: provider,
        value: value,
        boughtAt: boughtAt,
        endedAt: endedAt,
        soldValue: soldValue,
      );
}
