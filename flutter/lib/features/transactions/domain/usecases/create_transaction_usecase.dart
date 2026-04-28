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
    required DateTime transactedAt,
    required double value,
    required bool ignore,
    required double percentage,
  }) =>
      _repository.createTransaction(
        accountId: accountId,
        cardId: cardId,
        categoryId: categoryId,
        tagId: tagId,
        transactedAt: transactedAt,
        value: value,
        ignore: ignore,
        percentage: percentage,
      );
}
