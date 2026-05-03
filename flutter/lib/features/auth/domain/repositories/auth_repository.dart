import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> updateEmail({required String newEmail});
}
