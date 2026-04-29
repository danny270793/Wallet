import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class GetTransactionsByCreditGroupIdUsecase {
  final TransactionsRepository _repository;

  const GetTransactionsByCreditGroupIdUsecase(this._repository);

  Future<List<TransactionEntity>> call(String creditGroupId) =>
      _repository.getTransactionsByCreditGroupId(creditGroupId);
}
