import 'package:uuid/uuid.dart';

import 'create_transaction_usecase.dart';

/// Creates two ledger rows: outflow on [sourceAccountId], inflow on [targetAccountId].
/// Both share the same [transactionGroupId] (new UUID).
class CreateAccountTransferUsecase {
  static const transferDescription = 'Transfer';

  final CreateTransactionUsecase _createTransaction;

  const CreateAccountTransferUsecase(this._createTransaction);

  Future<void> call({
    required String sourceAccountId,
    required String targetAccountId,
    required double amount,
    required DateTime transactedAt,
  }) async {
    if (sourceAccountId == targetAccountId) {
      throw ArgumentError('source and target account must differ');
    }
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    final groupId = const Uuid().v4();
    await _createTransaction(
      accountId: sourceAccountId,
      description: transferDescription,
      transactedAt: transactedAt,
      value: -amount,
      ignore: false,
      percentage: 100,
      transactionGroupId: groupId,
    );
    await _createTransaction(
      accountId: targetAccountId,
      description: transferDescription,
      transactedAt: transactedAt,
      value: amount,
      ignore: false,
      percentage: 100,
      transactionGroupId: groupId,
    );
  }
}
