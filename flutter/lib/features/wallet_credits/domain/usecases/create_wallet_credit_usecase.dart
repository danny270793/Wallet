import '../entities/wallet_credit_entity.dart';
import '../repositories/wallet_credits_repository.dart';

class CreateWalletCreditUsecase {
  final WalletCreditsRepository _repository;
  const CreateWalletCreditUsecase(this._repository);

  Future<WalletCreditEntity> call({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  }) => _repository.createCredit(
    transactedAt: transactedAt,
    graceMonths: graceMonths,
    termMonths: termMonths,
    description: description,
  );
}
