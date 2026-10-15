import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/asset_entity.dart';
import '../repositories/assets_repository.dart';

class GetAssetsUsecase {
  final AssetsRepository _repository;
  const GetAssetsUsecase(this._repository);

  Future<OfflineServedBundle<List<AssetEntity>>> call() =>
      _repository.getAssets();
}
