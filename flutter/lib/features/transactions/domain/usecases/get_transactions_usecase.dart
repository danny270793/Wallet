import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class GetTransactionsUsecase {
  final TransactionsRepository _repository;
  const GetTransactionsUsecase(this._repository);

  Future<List<TransactionEntity>> call() => _repository.getTransactions();
}
