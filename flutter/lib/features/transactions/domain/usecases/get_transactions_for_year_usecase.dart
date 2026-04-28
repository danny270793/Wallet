import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class GetTransactionsForYearUsecase {
  final TransactionsRepository _repository;
  const GetTransactionsForYearUsecase(this._repository);

  Future<List<TransactionEntity>> call(DateTime yearStartLocal) =>
      _repository.getTransactionsForYear(DateTime(yearStartLocal.year, 1, 1));
}
