import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote_load_failure.dart';
import '../../../../core/sort_by_name.dart';
import '../../domain/entities/recurring_movement_entity.dart';
import '../../domain/usecases/get_recurring_movements_usecase.dart';
import '../../domain/usecases/create_recurring_movement_usecase.dart';
import '../../domain/usecases/update_recurring_movement_usecase.dart';
import '../../domain/usecases/delete_recurring_movement_usecase.dart';
import 'recurring_movements_state.dart';

class RecurringMovementsCubit extends Cubit<RecurringMovementsState> {
  final GetRecurringMovementsUsecase _getRecurringMovements;
  final CreateRecurringMovementUsecase _createRecurringMovement;
  final UpdateRecurringMovementUsecase _updateRecurringMovement;
  final DeleteRecurringMovementUsecase _deleteRecurringMovement;

  RecurringMovementsCubit({
    required GetRecurringMovementsUsecase getRecurringMovements,
    required CreateRecurringMovementUsecase createRecurringMovement,
    required UpdateRecurringMovementUsecase updateRecurringMovement,
    required DeleteRecurringMovementUsecase deleteRecurringMovement,
  }) : _getRecurringMovements = getRecurringMovements,
       _createRecurringMovement = createRecurringMovement,
       _updateRecurringMovement = updateRecurringMovement,
       _deleteRecurringMovement = deleteRecurringMovement,
       super(const RecurringMovementsInitial());

  bool _preserveOfflineCacheFlag() => switch (state) {
    RecurringMovementsLoaded(:final servedFromOfflineCache) =>
      servedFromOfflineCache,
    RecurringMovementsActionError(:final servedFromOfflineCache) =>
      servedFromOfflineCache,
    _ => false,
  };

  List<RecurringMovementEntity> _sorted(List<RecurringMovementEntity> items) =>
      sortedByName(items, (m) => m.name);

  Future<void> load({bool showLoading = true}) async {
    AppLogger.debug('loading recurring movements');
    if (showLoading) emit(const RecurringMovementsLoading());
    try {
      final bundle = await _getRecurringMovements();
      final movements = _sorted(bundle.value);
      AppLogger.info('recurring movements loaded: ${movements.length}');
      emit(
        RecurringMovementsLoaded(
          movements,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to load recurring movements', e, s);
      emit(RecurringMovementsError(failure: classifyRemoteLoadError(e)));
    }
  }

  Future<void> create({
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  }) async {
    final current = _currentMovements();
    AppLogger.debug('creating recurring movement: $name');
    try {
      final movement = await _createRecurringMovement(
        name: name,
        description: description,
        value: value,
        categoryId: categoryId,
        tagId: tagId,
      );
      AppLogger.info('recurring movement created: ${movement.id}');
      emit(
        RecurringMovementsLoaded(
          _sorted([...current, movement]),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to create recurring movement', e, s);
      emit(
        RecurringMovementsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    }
  }

  Future<void> update({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  }) async {
    final current = _currentMovements();
    AppLogger.debug('updating recurring movement: $id');
    try {
      final updated = await _updateRecurringMovement(
        id: id,
        name: name,
        description: description,
        value: value,
        categoryId: categoryId,
        tagId: tagId,
      );
      AppLogger.info('recurring movement updated: ${updated.id}');
      emit(
        RecurringMovementsLoaded(
          _sorted(current.map((m) => m.id == id ? updated : m).toList()),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to update recurring movement', e, s);
      emit(
        RecurringMovementsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    }
  }

  Future<bool> delete({required String id}) async {
    final current = _currentMovements();
    AppLogger.debug('deleting recurring movement: $id');
    try {
      await _deleteRecurringMovement(id: id);
      AppLogger.info('recurring movement deleted: $id');
      emit(
        RecurringMovementsLoaded(
          _sorted(current.where((m) => m.id != id).toList()),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete recurring movement', e, s);
      emit(
        RecurringMovementsActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return false;
    }
  }

  List<RecurringMovementEntity> _currentMovements() => switch (state) {
    RecurringMovementsLoaded(:final movements) => movements,
    RecurringMovementsActionError(:final movements) => movements,
    _ => [],
  };
}
