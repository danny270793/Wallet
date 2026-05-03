import '../remote_load_failure.dart';
import 'device_connectivity.dart';
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

  Future<OfflineServedBundle<List<E>>?> loadFromCache() async {
    final raw = await cache.loadList(userId, cacheKey);
    if (raw == null) return null;
    return OfflineServedBundle(
      value: raw.map(fromJson).toList(),
      servedFromOfflineCache: true,
    );
  }

  // Fast path: OS reports no data connection — prefer disk immediately.
  if (!await deviceReportsOnline()) {
    final cached = await loadFromCache();
    if (cached != null) return cached;
    // Fall through: connectivity can be wrong (e.g. VPN); still try remote.
  }

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
    final cached = await loadFromCache();
    final deviceOffline = !await deviceReportsOnline();
    final networkFailure =
        classifyRemoteLoadError(e) == RemoteLoadFailure.networkUnavailable;

    // Saved snapshot + offline banner, not only the error panel, when we can.
    if (cached != null && (networkFailure || deviceOffline)) {
      return cached;
    }

    if (deviceOffline && cached == null) {
      throw const NoDeviceConnectivityException();
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

  Future<OfflineServedBundle<T?>?> loadFromCache() async {
    final raw = await cache.loadItem(userId, cacheKey);
    if (raw == null) return null;
    return OfflineServedBundle(
      value: fromJson(raw),
      servedFromOfflineCache: true,
    );
  }

  if (!await deviceReportsOnline()) {
    final cached = await loadFromCache();
    if (cached != null) return cached;
  }

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
    final cached = await loadFromCache();
    final deviceOffline = !await deviceReportsOnline();
    final networkFailure =
        classifyRemoteLoadError(e) == RemoteLoadFailure.networkUnavailable;

    if (cached != null && (networkFailure || deviceOffline)) {
      return cached;
    }

    if (deviceOffline && cached == null) {
      throw const NoDeviceConnectivityException();
    }

    rethrow;
  }
}
