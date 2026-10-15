import '../repositories/recurring_movements_repository.dart';

class DeleteRecurringMovementUsecase {
  final RecurringMovementsRepository _repository;
  const DeleteRecurringMovementUsecase(this._repository);

  Future<void> call({required String id}) =>
      _repository.deleteRecurringMovement(id: id);
}
