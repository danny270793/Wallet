import 'package:uuid/uuid.dart';

import 'create_transaction_usecase.dart';

/// Creates two ledger rows: outflow on the source leg, inflow on the target leg.
/// Each leg sets exactly one of accountId or cardId. Both rows share [transactionGroupId] (new UUID).
class CreateAccountTransferUsecase {
  static const transferDescription = 'Transfer';

  final CreateTransactionUsecase _createTransaction;

  const CreateAccountTransferUsecase(this._createTransaction);

  Future<void> call({
    required String? sourceAccountId,
    required String? sourceCardId,
    required String? targetAccountId,
    required String? targetCardId,
    required double amount,
    required DateTime transactedAt,
  }) async {
    final sourceOk = (sourceAccountId != null) ^ (sourceCardId != null);
    final targetOk = (targetAccountId != null) ^ (targetCardId != null);
    if (!sourceOk || !targetOk) {
      throw ArgumentError('each leg must have exactly one of account or card');
    }
    final sourceKey = sourceAccountId != null ? 'a:$sourceAccountId' : 'c:${sourceCardId!}';
    final targetKey = targetAccountId != null ? 'a:$targetAccountId' : 'c:${targetCardId!}';
    if (sourceKey == targetKey) {
      throw ArgumentError('source and target payment method must differ');
    }
    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }
    final groupId = const Uuid().v4();
    await _createTransaction(
      accountId: sourceAccountId,
      cardId: sourceCardId,
      description: transferDescription,
      transactedAt: transactedAt,
      value: -amount,
      ignore: false,
      percentage: 100,
      transactionGroupId: groupId,
    );
    await _createTransaction(
      accountId: targetAccountId,
      cardId: targetCardId,
      description: transferDescription,
      transactedAt: transactedAt,
      value: amount,
      ignore: false,
      percentage: 100,
      transactionGroupId: groupId,
    );
  }
}
