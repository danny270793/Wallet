import 'package:supabase_flutter/supabase_flutter.dart';

/// Inserts rows into [wallet_actions] (RLS: anon without user, authenticated with own userId).
class WalletActionsDatasource {
  WalletActionsDatasource(this._client);

  final SupabaseClient _client;

  Future<void> insert({
    required String type,
    String? customTitle,
    Map<String, dynamic>? customPayload,
    String? errorMessage,
    String? errorStack,
    required String appVersion,
    required String? userId,
    required String os,
  }) async {
    await _client.from('wallet_actions').insert({
      'type': type,
      'customTitle': customTitle,
      'customPayload': customPayload,
      'errorMessage': errorMessage,
      'errorStack': errorStack,
      'appVersion': appVersion,
      'userId': userId,
      'os': os,
    });
  }
}
