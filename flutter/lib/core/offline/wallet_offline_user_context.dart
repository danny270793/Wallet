import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the signed-in user id for namespacing offline cache files.
abstract interface class WalletOfflineUserContext {
  String? get userId;
}

class SupabaseWalletOfflineUserContext implements WalletOfflineUserContext {
  final SupabaseClient _client;

  SupabaseWalletOfflineUserContext(this._client);

  @override
  String? get userId => _client.auth.currentUser?.id;
}
