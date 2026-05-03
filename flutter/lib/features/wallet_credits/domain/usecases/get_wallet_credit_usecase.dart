import '../entities/wallet_credit_entity.dart';
import '../repositories/wallet_credits_repository.dart';

class GetWalletCreditUsecase {
  final WalletCreditsRepository _repository;
  const GetWalletCreditUsecase(this._repository);

  Future<WalletCreditEntity?> call(String id) => _repository.getCredit(id);
}
