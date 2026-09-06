import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class ListTransactionsHavingCreditGroupUsecase {
  final TransactionsRepository _repository;

  const ListTransactionsHavingCreditGroupUsecase(this._repository);

  Future<OfflineServedBundle<List<TransactionEntity>>> call() =>
      _repository.listTransactionsHavingCreditGroup();
}
