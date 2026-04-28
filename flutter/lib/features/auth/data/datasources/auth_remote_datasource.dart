import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthRemoteDatasource {
  Future<UserEntity> signIn({required String email, required String password});
}

class AuthSupabaseDatasource implements AuthRemoteDatasource {
  final SupabaseClient _client;

  const AuthSupabaseDatasource(this._client);

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthException('Sign in failed');
    return UserEntity(id: user.id, email: user.email ?? '');
  }
}
