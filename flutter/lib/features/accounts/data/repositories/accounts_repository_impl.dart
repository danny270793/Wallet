import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../datasources/accounts_remote_datasource.dart';

class AccountsRepositoryImpl implements AccountsRepository {
  final AccountsRemoteDatasource _datasource;
  const AccountsRepositoryImpl(this._datasource);

  @override
  Future<List<AccountEntity>> getAccounts() => _datasource.getAccounts();

  @override
  Future<AccountEntity> createAccount({required String name, String? description}) =>
      _datasource.createAccount(name: name, description: description);

  @override
  Future<AccountEntity> updateAccount({required String id, required String name, String? description}) =>
      _datasource.updateAccount(id: id, name: name, description: description);

  @override
  Future<void> deleteAccount({required String id}) => _datasource.deleteAccount(id: id);
}
