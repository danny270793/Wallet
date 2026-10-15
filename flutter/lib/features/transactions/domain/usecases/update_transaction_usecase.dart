import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class UpdateTransactionUsecase {
  final TransactionsRepository _repository;
  const UpdateTransactionUsecase(this._repository);

  Future<TransactionEntity> call({
    required String id,
    String? accountId,
    String? cardId,
    String? categoryId,
    String? tagId,
    String? description,
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
    String? transferGroupId,
    String? creditId,
  }) => _repository.updateTransaction(
    id: id,
    accountId: accountId,
    cardId: cardId,
    categoryId: categoryId,
    tagId: tagId,
    description: description,
    transactedAt: transactedAt,
    value: value,
    ignore: ignore,
    percentage: percentage,
    transferGroupId: transferGroupId,
    creditId: creditId,
  );
}
