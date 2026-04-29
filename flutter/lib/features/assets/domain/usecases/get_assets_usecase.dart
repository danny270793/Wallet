import '../entities/asset_entity.dart';
import '../repositories/assets_repository.dart';

class GetAssetsUsecase {
  final AssetsRepository _repository;
  const GetAssetsUsecase(this._repository);

  Future<List<AssetEntity>> call() => _repository.getAssets();
}
