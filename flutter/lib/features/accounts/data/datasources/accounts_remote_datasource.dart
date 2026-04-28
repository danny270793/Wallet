import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/account_entity.dart';

abstract class AccountsRemoteDatasource {
  Future<List<AccountEntity>> getAccounts();
  Future<AccountEntity> createAccount({required String name, String? description});
  Future<AccountEntity> updateAccount({required String id, required String name, String? description});
  Future<void> deleteAccount({required String id});
}

class AccountsSupabaseDatasource implements AccountsRemoteDatasource {
  final SupabaseClient _client;
  const AccountsSupabaseDatasource(this._client);

  @override
  Future<List<AccountEntity>> getAccounts() async {
    AppLogger.debug('getAccounts called');
    final data = await _client
        .from('wallet_accounts_with_balance')
        .select()
        .isFilter('deletedAt', null)
        .order('createdAt');
    return (data as List).map((e) => AccountEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<AccountEntity> createAccount({required String name, String? description}) async {
    AppLogger.debug('createAccount called: $name');
    final data = await _client
        .from('wallet_accounts')
        .insert({
          'userId': _client.auth.currentUser!.id,
          'name': name,
          if (description != null) 'description': description,
        })
        .select()
        .single();
    return AccountEntity.fromJson(data);
  }

  @override
  Future<AccountEntity> updateAccount({
    required String id,
    required String name,
    String? description,
  }) async {
    AppLogger.debug('updateAccount called: $id');
    final data = await _client
        .from('wallet_accounts')
        .update({'name': name, 'description': description})
        .eq('id', id)
        .select()
        .single();
    return AccountEntity.fromJson(data);
  }

  @override
  Future<void> deleteAccount({required String id}) async {
    AppLogger.debug('deleteAccount called: $id');
    await _client
        .from('wallet_accounts')
        .update({'deletedAt': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
