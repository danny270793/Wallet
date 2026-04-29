import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/sort_by_name.dart';
import '../../domain/usecases/get_assets_usecase.dart';
import 'assets_state.dart';

class AssetsCubit extends Cubit<AssetsState> {
  final GetAssetsUsecase _getAssets;

  AssetsCubit({required GetAssetsUsecase getAssets})
      : _getAssets = getAssets,
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
}
