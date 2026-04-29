import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/sort_by_name.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/usecases/create_asset_usecase.dart';
import '../../domain/usecases/delete_asset_usecase.dart';
import '../../domain/usecases/get_assets_usecase.dart';
import '../../domain/usecases/update_asset_usecase.dart';
import 'assets_state.dart';

class AssetsCubit extends Cubit<AssetsState> {
  final GetAssetsUsecase _getAssets;
  final CreateAssetUsecase _createAssetUsecase;
  final UpdateAssetUsecase _updateAssetUsecase;
  final DeleteAssetUsecase _deleteAssetUsecase;

  AssetsCubit({
    required GetAssetsUsecase getAssets,
    required CreateAssetUsecase createAsset,
    required UpdateAssetUsecase updateAsset,
    required DeleteAssetUsecase deleteAsset,
  })  : _getAssets = getAssets,
        _createAssetUsecase = createAsset,
        _updateAssetUsecase = updateAsset,
        _deleteAssetUsecase = deleteAsset,
        super(const AssetsInitial());

  Future<void> load({bool showLoading = true}) async {
    AppLogger.debug('loading assets');
    if (showLoading) emit(const AssetsLoading());
    try {
      final assets = sortedByName(await _getAssets(), (a) => a.name);
      AppLogger.info('assets loaded: ${assets.length}');
      emit(AssetsLoaded(assets));
    } catch (e, s) {
      AppLogger.error('failed to load assets', e, s);
      emit(const AssetsError());
    }
  }

  Future<void> create({
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) async {
    final current = _currentAssets();
    AppLogger.debug('creating asset: $name');
    try {
      final asset = await _createAssetUsecase(
        name: name,
        provider: provider,
        value: value,
        boughtAt: boughtAt,
        endedAt: endedAt,
        soldValue: soldValue,
      );
      AppLogger.info('asset created: ${asset.id}');
      emit(AssetsLoaded(sortedByName([...current, asset], (a) => a.name)));
    } catch (e, s) {
      AppLogger.error('failed to create asset', e, s);
      emit(AssetsActionError(current));
    }
  }

  Future<void> update({
    required String id,
    required String name,
    required String provider,
    required double value,
    required DateTime boughtAt,
    DateTime? endedAt,
    double? soldValue,
  }) async {
    final current = _currentAssets();
    AppLogger.debug('updating asset: $id');
    try {
      final asset = await _updateAssetUsecase(
        id: id,
        name: name,
        provider: provider,
        value: value,
        boughtAt: boughtAt,
        endedAt: endedAt,
        soldValue: soldValue,
      );
      emit(
        AssetsLoaded(
          sortedByName(
            current.map((a) => a.id == id ? asset : a).toList(),
            (a) => a.name,
          ),
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to update asset', e, s);
      emit(AssetsActionError(current));
    }
  }

  Future<bool> delete({required String id}) async {
    final current = _currentAssets();
    AppLogger.debug('deleting asset: $id');
    try {
      await _deleteAssetUsecase(id: id);
      emit(
        AssetsLoaded(
          sortedByName(current.where((a) => a.id != id).toList(), (a) => a.name),
        ),
      );
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete asset', e, s);
      emit(AssetsActionError(current));
      return false;
    }
  }

  List<AssetEntity> _currentAssets() => switch (state) {
    AssetsLoaded(:final assets) => assets,
    AssetsActionError(:final assets) => assets,
    _ => [],
  };
}
