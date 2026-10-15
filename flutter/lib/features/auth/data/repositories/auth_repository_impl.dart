import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const AuthRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) => _datasource.signIn(email: email, password: password);

  @override
  Future<void> signOut() async {
    final uid = _offlineSession.userId;
    await _datasource.signOut();
    if (uid != null && uid.isNotEmpty) {
      await _offlineCache.clearForUser(uid);
    }
  }

  @override
  Future<void> updateEmail({required String newEmail}) =>
      _datasource.updateEmail(newEmail: newEmail);

  @override
  Future<void> updatePassword({required String newPassword}) =>
      _datasource.updatePassword(newPassword: newPassword);
}
