import '../entities/transaction_entity.dart';
import '../repositories/transactions_repository.dart';

class CreateTransactionUsecase {
  final TransactionsRepository _repository;
  const CreateTransactionUsecase(this._repository);

  Future<TransactionEntity> call({
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
    String? creditGroupId,
    String? creditId,
  }) =>
      _repository.createTransaction(
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
        creditGroupId: creditGroupId,
        creditId: creditId,
      );
}
