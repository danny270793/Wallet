import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

/// All-time search for the current user; matches transaction [description] (substring, case-insensitive).
class SearchTransactionsByDescriptionUsecase {
  final TransactionsRepository _repository;
  const SearchTransactionsByDescriptionUsecase(this._repository);

  Future<List<TransactionEntity>> call(String query, {int limit = 200}) =>
      _repository.searchTransactionsByDescription(query, limit: limit);
}
