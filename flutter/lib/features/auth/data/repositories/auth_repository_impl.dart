import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _datasource;

  const AuthRepositoryImpl(this._datasource);

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) =>
      _datasource.signIn(email: email, password: password);
}
