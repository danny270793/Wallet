import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class GetTransactionsByCreditGroupIdUsecase {
  final TransactionsRepository _repository;

  const GetTransactionsByCreditGroupIdUsecase(this._repository);

  /// Rows sharing the given [creditId] (FK to wallet_credits), ordered by date.
  Future<OfflineServedBundle<List<TransactionEntity>>> call(String creditId) =>
      _repository.getTransactionsByCreditGroupId(creditId);
}
