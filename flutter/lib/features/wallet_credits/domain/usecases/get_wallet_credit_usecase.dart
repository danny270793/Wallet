import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/wallet_credit_entity.dart';
import '../repositories/wallet_credits_repository.dart';

class GetWalletCreditUsecase {
  final WalletCreditsRepository _repository;
  const GetWalletCreditUsecase(this._repository);

  Future<OfflineServedBundle<WalletCreditEntity?>> call(String id) =>
      _repository.getCredit(id);
}
