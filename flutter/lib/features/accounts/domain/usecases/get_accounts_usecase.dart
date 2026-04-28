import '../entities/account_entity.dart';
import '../repositories/accounts_repository.dart';

class GetAccountsUsecase {
  final AccountsRepository _repository;
  const GetAccountsUsecase(this._repository);

  Future<List<AccountEntity>> call() => _repository.getAccounts();
}
