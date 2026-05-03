import '../remote_load_failure.dart';
import 'offline_served_bundle.dart';
import 'wallet_offline_cache.dart';
import 'wallet_offline_user_context.dart';

Future<OfflineServedBundle<List<E>>> fetchListWithOfflineCache<E>({
  required WalletOfflineUserContext session,
  required WalletOfflineCache cache,
  required String cacheKey,
  required Future<List<E>> Function() remote,
  required E Function(Map<String, dynamic>) fromJson,
  required Map<String, dynamic> Function(E) toJson,
}) async {
  final userId = session.userId;
  try {
    final list = await remote();
    if (userId != null && userId.isNotEmpty) {
      await cache.saveList(
        userId,
        cacheKey,
        list.map(toJson).toList(),
      );
    }
    return OfflineServedBundle(
      value: list,
      servedFromOfflineCache: false,
    );
  } catch (e) {
    if (classifyRemoteLoadError(e) != RemoteLoadFailure.networkUnavailable) {
      rethrow;
    }
    final raw = await cache.loadList(userId, cacheKey);
    if (raw != null) {
      return OfflineServedBundle(
        value: raw.map(fromJson).toList(),
        servedFromOfflineCache: true,
      );
    }
    rethrow;
  }
}

Future<OfflineServedBundle<T?>> fetchNullableWithOfflineCache<T>({
  required WalletOfflineUserContext session,
  required WalletOfflineCache cache,
  required String cacheKey,
  required Future<T?> Function() remote,
  required T Function(Map<String, dynamic>) fromJson,
  required Map<String, dynamic> Function(T) toJson,
}) async {
  final userId = session.userId;
  try {
    final value = await remote();
    if (value != null && userId != null && userId.isNotEmpty) {
      await cache.saveItem(userId, cacheKey, toJson(value));
    }
    return OfflineServedBundle(
      value: value,
      servedFromOfflineCache: false,
    );
  } catch (e) {
    if (classifyRemoteLoadError(e) != RemoteLoadFailure.networkUnavailable) {
      rethrow;
    }
    final raw = await cache.loadItem(userId, cacheKey);
    if (raw != null) {
      return OfflineServedBundle(
        value: fromJson(raw),
        servedFromOfflineCache: true,
      );
    }
    rethrow;
  }
}
