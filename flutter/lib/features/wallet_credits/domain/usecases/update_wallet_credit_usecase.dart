import '../entities/wallet_credit_entity.dart';
import '../repositories/wallet_credits_repository.dart';

class UpdateWalletCreditUsecase {
  final WalletCreditsRepository _repository;
  const UpdateWalletCreditUsecase(this._repository);

  Future<WalletCreditEntity> call({
    required String id,
    required int graceMonths,
    required int termMonths,
  }) =>
      _repository.updateCreditGracing(
        id: id,
        graceMonths: graceMonths,
        termMonths: termMonths,
      );
}
