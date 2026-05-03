import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/offline_served_bundle.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../datasources/accounts_remote_datasource.dart';

class AccountsRepositoryImpl implements AccountsRepository {
  final AccountsRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const AccountsRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<OfflineServedBundle<List<AccountEntity>>> getAccounts() => fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.accounts,
        remote: _datasource.getAccounts,
        fromJson: AccountEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<AccountEntity> createAccount({required String name, String? description}) =>
      _datasource.createAccount(name: name, description: description);

  @override
  Future<AccountEntity> updateAccount({required String id, required String name, String? description}) =>
      _datasource.updateAccount(id: id, name: name, description: description);

  @override
  Future<void> deleteAccount({required String id}) => _datasource.deleteAccount(id: id);
}
