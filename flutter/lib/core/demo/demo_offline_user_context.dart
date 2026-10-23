import '../offline/wallet_offline_user_context.dart';

/// Demo mode has no user id, so the offline cache neither reads nor writes
/// anything on disk (the cache ignores a null/empty user id).
class DemoOfflineUserContext implements WalletOfflineUserContext {
  const DemoOfflineUserContext();

  @override
  String? get userId => null;
}
