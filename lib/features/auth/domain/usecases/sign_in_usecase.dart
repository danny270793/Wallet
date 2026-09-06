import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUsecase {
  final AuthRepository _repository;

  const SignInUsecase(this._repository);

  Future<UserEntity> call({required String email, required String password}) =>
      _repository.signIn(email: email, password: password);
}
