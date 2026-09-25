import '../entities/recurring_movement_entity.dart';
import '../repositories/recurring_movements_repository.dart';

class UpdateRecurringMovementUsecase {
  final RecurringMovementsRepository _repository;
  const UpdateRecurringMovementUsecase(this._repository);

  Future<RecurringMovementEntity> call({
    required String id,
    required String name,
    String? description,
    required double value,
    required String categoryId,
    required String tagId,
  }) => _repository.updateRecurringMovement(
    id: id,
    name: name,
    description: description,
    value: value,
    categoryId: categoryId,
    tagId: tagId,
  );
}
