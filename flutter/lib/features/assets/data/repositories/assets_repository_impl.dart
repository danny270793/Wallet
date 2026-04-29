import '../../domain/entities/asset_entity.dart';
import '../../domain/repositories/assets_repository.dart';
import '../datasources/assets_remote_datasource.dart';

class AssetsRepositoryImpl implements AssetsRepository {
  final AssetsRemoteDatasource _datasource;
  const AssetsRepositoryImpl(this._datasource);

  @override
  Future<List<AssetEntity>> getAssets() => _datasource.getAssets();
}
