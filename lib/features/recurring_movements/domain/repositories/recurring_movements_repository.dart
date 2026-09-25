import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/recurring_movement_entity.dart';

abstract class RecurringMovementsRepository {
  Future<OfflineServedBundle<List<RecurringMovementEntity>>>
  getRecurringMovements();
  Future<RecurringMovementEntity> createRecurringMovement({
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  });
  Future<RecurringMovementEntity> updateRecurringMovement({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  });
  Future<void> deleteRecurringMovement({required String id});
}
