import '../repositories/transactions_repository.dart';

class DeleteTransactionUsecase {
  final TransactionsRepository _repository;
  const DeleteTransactionUsecase(this._repository);

  Future<void> call({required String id}) =>
      _repository.deleteTransaction(id: id);
}
