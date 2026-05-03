import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../core/offline/wallet_offline_cache.dart';

String _formatBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String _shortCacheId(String raw) {
  if (raw.length <= 10) return raw;
  return '${raw.substring(0, 8)}…';
}

String _cacheEntryTitle(String key, AppLocalizations l10n) {
  switch (key) {
    case WalletOfflineCacheKeys.accounts:
      return l10n.accounts;
    case WalletOfflineCacheKeys.cards:
      return l10n.cards;
    case WalletOfflineCacheKeys.categories:
      return l10n.categories;
    case WalletOfflineCacheKeys.tags:
      return l10n.tags;
    case WalletOfflineCacheKeys.assets:
      return l10n.assets;
    case WalletOfflineCacheKeys.transactionsHavingCreditGroup:
      return l10n.settingsCacheKeyTxCreditGroups;
  }
  final month = RegExp(r'^tx_month_(\d{4})_(\d{2})$').firstMatch(key);
  if (month != null) {
    return l10n.settingsCacheKeyTxMonth(month[1]!, month[2]!);
  }
  final year = RegExp(r'^tx_year_(\d{4})$').firstMatch(key);
  if (year != null) {
    return l10n.settingsCacheKeyTxYear(year[1]!);
  }
  final txCredit = RegExp(r'^tx_credit_(.+)$').firstMatch(key);
  if (txCredit != null) {
    return l10n.settingsCacheKeyTxCredit(_shortCacheId(txCredit[1]!));
  }
  final walletCredit = RegExp(r'^wallet_credit_(.+)$').firstMatch(key);
  if (walletCredit != null) {
    return l10n.settingsCacheKeyWalletCredit(_shortCacheId(walletCredit[1]!));
  }
  return l10n.settingsCacheKeyRaw(key);
}

class SettingsCachePage extends StatefulWidget {
  const SettingsCachePage({super.key});

  @override
  State<SettingsCachePage> createState() => _SettingsCachePageState();
}

class _SettingsCachePageState extends State<SettingsCachePage> {
  List<WalletCacheEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final list = await getIt<WalletOfflineCache>().listUserCacheFiles(userId);
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final totalBytes = _entries.fold<int>(0, (s, e) => s + e.bytes);
    final localeName = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(localeName).add_jm();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsCachePageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _entries.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.paddingOf(context).top + 120,
                        ),
                        Center(
                          child: Text(
                            l10n.settingsCacheEmpty,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: _entries.length,
                      itemBuilder: (context, i) {
                        final e = _entries[i];
                        final dt = dateFormat.format(e.modifiedAt.toLocal());
                        final sz = _formatBytes(e.bytes);
                        return ListTile(
                          title: Text(_cacheEntryTitle(e.cacheKey, l10n)),
                          subtitle: Text(
                            l10n.settingsCacheRowSubtitle(dt, sz),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: _entries.isEmpty || _loading
          ? null
          : Material(
              elevation: 8,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatBytes(totalBytes),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsCacheBottomBarCaption,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
