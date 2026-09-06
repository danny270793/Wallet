import '../repositories/accounts_repository.dart';

class DeleteAccountUsecase {
  final AccountsRepository _repository;
  const DeleteAccountUsecase(this._repository);

  Future<void> call({required String id}) => _repository.deleteAccount(id: id);
}
