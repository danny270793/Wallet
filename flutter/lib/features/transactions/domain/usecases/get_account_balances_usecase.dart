import '../repositories/transactions_repository.dart';

class GetAccountBalancesUsecase {
  final TransactionsRepository _repository;
  const GetAccountBalancesUsecase(this._repository);

  Future<Map<String, double>> call() => _repository.sumTransactionValuesByAccountId();
}
