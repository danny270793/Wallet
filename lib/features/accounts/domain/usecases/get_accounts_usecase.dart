import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/account_entity.dart';
import '../repositories/accounts_repository.dart';

class GetAccountsUsecase {
  final AccountsRepository _repository;
  const GetAccountsUsecase(this._repository);

  Future<OfflineServedBundle<List<AccountEntity>>> call() => _repository.getAccounts();
}
