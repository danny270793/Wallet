import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class ListTransactionsHavingCreditGroupUsecase {
  final TransactionsRepository _repository;

  const ListTransactionsHavingCreditGroupUsecase(this._repository);

  Future<List<TransactionEntity>> call() => _repository.listTransactionsHavingCreditGroup();
}
