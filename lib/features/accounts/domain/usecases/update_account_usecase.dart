import '../entities/account_entity.dart';
import '../repositories/accounts_repository.dart';

class UpdateAccountUsecase {
  final AccountsRepository _repository;
  const UpdateAccountUsecase(this._repository);

  Future<AccountEntity> call({
    required String id,
    required String name,
    String? description,
  }) => _repository.updateAccount(id: id, name: name, description: description);
}
