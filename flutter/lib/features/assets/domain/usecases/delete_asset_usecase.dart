import '../repositories/assets_repository.dart';

class DeleteAssetUsecase {
  final AssetsRepository _repository;
  const DeleteAssetUsecase(this._repository);

  Future<void> call({required String id}) => _repository.deleteAsset(id: id);
}
