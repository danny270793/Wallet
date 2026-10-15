import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/recurring_movement_entity.dart';
import '../repositories/recurring_movements_repository.dart';

class GetRecurringMovementsUsecase {
  final RecurringMovementsRepository _repository;
  const GetRecurringMovementsUsecase(this._repository);

  Future<OfflineServedBundle<List<RecurringMovementEntity>>> call() =>
      _repository.getRecurringMovements();
}
