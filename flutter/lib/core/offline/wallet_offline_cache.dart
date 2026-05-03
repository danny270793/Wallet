import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logger/app_logger.dart';

/// One on-disk JSON cache file for the wallet offline layer.
class WalletCacheEntry {
  final String cacheKey;
  final int bytes;
  final DateTime modifiedAt;

  const WalletCacheEntry({
    required this.cacheKey,
    required this.bytes,
    required this.modifiedAt,
  });
}

/// JSON file cache under app support dir, one folder per [userId].
class WalletOfflineCache {
  Directory? _root;

  Future<Directory> _ensureRoot() async {
    final existing = _root;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/wallet_offline_cache');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _root = dir;
    return dir;
  }

  Future<File> _file(String userId, String key) async {
    final root = await _ensureRoot();
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    final userDir = Directory('${root.path}/$userId');
    if (!userDir.existsSync()) {
      userDir.createSync(recursive: true);
    }
    return File('${userDir.path}/$safeKey.json');
  }

  Future<void> saveList(
    String? userId,
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final f = await _file(userId, key);
      await f.writeAsString(jsonEncode({'items': items}));
    } catch (e, st) {
      AppLogger.error('offline cache list write failed', e, st);
    }
  }

  Future<List<Map<String, dynamic>>?> loadList(String? userId, String key) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final f = await _file(userId, key);
      if (!f.existsSync()) return null;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final raw = decoded['items'];
      if (raw is! List) return null;
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, st) {
      AppLogger.error('offline cache list read failed', e, st);
      return null;
    }
  }

  Future<void> saveItem(
    String? userId,
    String key,
    Map<String, dynamic> item,
  ) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final f = await _file(userId, key);
      await f.writeAsString(jsonEncode({'item': item}));
    } catch (e, st) {
      AppLogger.error('offline cache item write failed', e, st);
    }
  }

  Future<Map<String, dynamic>?> loadItem(String? userId, String key) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final f = await _file(userId, key);
      if (!f.existsSync()) return null;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final item = decoded['item'];
      if (item is! Map) return null;
      return Map<String, dynamic>.from(item);
    } catch (e, st) {
      AppLogger.error('offline cache item read failed', e, st);
      return null;
    }
  }

  Future<void> clearForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final root = await _ensureRoot();
      final userDir = Directory('${root.path}/$userId');
      if (userDir.existsSync()) {
        await userDir.delete(recursive: true);
      }
    } catch (e, st) {
      AppLogger.error('offline cache clear user failed', e, st);
    }
  }

  /// Lists `.json` cache files for [userId], newest first.
  Future<List<WalletCacheEntry>> listUserCacheFiles(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final root = await _ensureRoot();
      final userDir = Directory('${root.path}/$userId');
      if (!userDir.existsSync()) return [];
      final out = <WalletCacheEntry>[];
      for (final ent in userDir.listSync(followLinks: false)) {
        if (ent is! File) continue;
        final path = ent.path;
        final slash = path.lastIndexOf(Platform.pathSeparator);
        final name = slash < 0 ? path : path.substring(slash + 1);
        if (!name.endsWith('.json')) continue;
        final stat = await ent.stat();
        final key = name.substring(0, name.length - 5);
        out.add(WalletCacheEntry(
          cacheKey: key,
          bytes: stat.size,
          modifiedAt: stat.modified,
        ));
      }
      out.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return out;
    } catch (e, st) {
      AppLogger.error('offline cache list files failed', e, st);
      return [];
    }
  }
}

/// Stable cache key segments for repository responses.
abstract final class WalletOfflineCacheKeys {
  static const accounts = 'accounts';
  static const cards = 'cards';
  static const categories = 'categories';
  static const tags = 'tags';
  static const assets = 'assets';

  static String transactionsMonth(DateTime monthStartLocal) =>
      'tx_month_${monthStartLocal.year}_${monthStartLocal.month.toString().padLeft(2, '0')}';

  static String transactionsYear(DateTime yearStartLocal) =>
      'tx_year_${yearStartLocal.year}';

  static String transactionsByCredit(String creditId) => 'tx_credit_$creditId';

  static const transactionsHavingCreditGroup = 'tx_credit_groups_flat';

  static String walletCredit(String id) => 'wallet_credit_$id';
}
