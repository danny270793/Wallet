import '../entities/account_entity.dart';
import '../repositories/accounts_repository.dart';

class CreateAccountUsecase {
  final AccountsRepository _repository;
  const CreateAccountUsecase(this._repository);

  Future<AccountEntity> call({required String name, String? description}) =>
      _repository.createAccount(name: name, description: description);
}
