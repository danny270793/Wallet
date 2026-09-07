import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/account_entity.dart';

abstract class AccountsRepository {
  Future<OfflineServedBundle<List<AccountEntity>>> getAccounts();
  Future<AccountEntity> createAccount({
    required String name,
    String? description,
  });
  Future<AccountEntity> updateAccount({
    required String id,
    required String name,
    String? description,
  });
  Future<void> deleteAccount({required String id});
}
