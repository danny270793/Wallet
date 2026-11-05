import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class ListTransactionsHavingCreditGroupUsecase {
  final TransactionsRepository _repository;

  const ListTransactionsHavingCreditGroupUsecase(this._repository);

  /// [includePaid] also returns installments paid early (they stay on the card's
  /// balance); lists and credit totals leave them out.
  Future<OfflineServedBundle<List<TransactionEntity>>> call({
    bool includePaid = false,
  }) => _repository.listTransactionsHavingCreditGroup(includePaid: includePaid);
}
