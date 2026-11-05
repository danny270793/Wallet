import '../repositories/transactions_repository.dart';

class MarkCreditInstallmentsPaidUsecase {
  final TransactionsRepository _repository;
  const MarkCreditInstallmentsPaidUsecase(this._repository);

  Future<void> call({
    required List<String> ids,
    required String paidByTransactionId,
  }) => _repository.markCreditInstallmentsPaid(
    ids: ids,
    paidByTransactionId: paidByTransactionId,
  );
}
