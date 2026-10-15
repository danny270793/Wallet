import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote_load_failure.dart';
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
  }) : _getAssets = getAssets,
       _createAssetUsecase = createAsset,
       _updateAssetUsecase = updateAsset,
       _deleteAssetUsecase = deleteAsset,
       super(const AssetsInitial());

  bool _preserveOfflineCacheFlag() => switch (state) {
    AssetsLoaded(:final servedFromOfflineCache) => servedFromOfflineCache,
    AssetsActionError(:final servedFromOfflineCache) => servedFromOfflineCache,
    _ => false,
  };

  Future<void> load({bool showLoading = true}) async {
    AppLogger.debug('loading assets');
    if (showLoading) emit(const AssetsLoading());
    try {
      final bundle = await _getAssets();
      final assets = _sortedByBoughtAt(bundle.value);
      AppLogger.info('assets loaded: ${assets.length}');
      emit(
        AssetsLoaded(
          assets,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to load assets', e, s);
      emit(AssetsError(failure: classifyRemoteLoadError(e)));
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
      emit(
        AssetsLoaded(
          _sortedByBoughtAt([...current, asset]),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to create asset', e, s);
      emit(
        AssetsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
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
          _sortedByBoughtAt(
            current.map((a) => a.id == id ? asset : a).toList(),
          ),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to update asset', e, s);
      emit(
        AssetsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    }
  }

  Future<bool> delete({required String id}) async {
    final current = _currentAssets();
    AppLogger.debug('deleting asset: $id');
    try {
      await _deleteAssetUsecase(id: id);
      emit(
        AssetsLoaded(
          _sortedByBoughtAt(current.where((a) => a.id != id).toList()),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete asset', e, s);
      emit(
        AssetsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return false;
    }
  }

  List<AssetEntity> _currentAssets() => switch (state) {
    AssetsLoaded(:final assets) => assets,
    AssetsActionError(:final assets) => assets,
    _ => [],
  };

  /// Newest purchase first ([boughtAt] descending).
  static List<AssetEntity> _sortedByBoughtAt(List<AssetEntity> assets) {
    final out = List<AssetEntity>.of(assets);
    out.sort((a, b) => b.boughtAt.compareTo(a.boughtAt));
    return out;
  }
}
