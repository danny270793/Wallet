import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../core/offline/wallet_offline_cache.dart';
import '../widgets/bottom_sheet_pinned_title.dart';

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

enum _CacheSortBy {
  date,
  size,
  name,
}

String _cacheSortLabel(AppLocalizations l10n, _CacheSortBy by) => switch (by) {
      _CacheSortBy.date => l10n.settingsCacheSortByDate,
      _CacheSortBy.size => l10n.settingsCacheSortBySize,
      _CacheSortBy.name => l10n.settingsCacheSortByName,
    };

class SettingsCachePage extends StatefulWidget {
  const SettingsCachePage({super.key});

  @override
  State<SettingsCachePage> createState() => _SettingsCachePageState();
}

class _SettingsCachePageState extends State<SettingsCachePage> {
  List<WalletCacheEntry> _entries = [];
  bool _loading = true;
  _CacheSortBy _sortBy = _CacheSortBy.date;

  List<WalletCacheEntry> _sortedEntries(AppLocalizations l10n) {
    final copy = List<WalletCacheEntry>.from(_entries);
    switch (_sortBy) {
      case _CacheSortBy.date:
        copy.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case _CacheSortBy.size:
        copy.sort((a, b) => b.bytes.compareTo(a.bytes));
      case _CacheSortBy.name:
        copy.sort(
          (a, b) => _cacheEntryTitle(a.cacheKey, l10n).toLowerCase().compareTo(
                _cacheEntryTitle(b.cacheKey, l10n).toLowerCase(),
              ),
        );
    }
    return copy;
  }

  Future<void> _showSortSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (sheetContext) => BottomSheetPinnedTitleScrollView(
        padding: EdgeInsets.zero,
        title: l10n.settingsCacheSortSheetTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in _CacheSortBy.values)
              ListTile(
                title: Text(_cacheSortLabel(l10n, option)),
                trailing: _sortBy == option
                    ? Icon(
                        Icons.check,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _sortBy = option);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

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
    final displayEntries = _sortedEntries(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsCachePageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_loading && _entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              tooltip: l10n.settingsCacheSortTooltip,
              onPressed: () => _showSortSheet(context, l10n),
            ),
        ],
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
                      itemCount: displayEntries.length,
                      itemBuilder: (context, i) {
                        final e = displayEntries[i];
                        final dt = dateFormat.format(e.modifiedAt.toLocal());
                        final sz = _formatBytes(e.bytes);
                        return ListTile(
                          title: Text(_cacheEntryTitle(e.cacheKey, l10n)),
                          subtitle: Text(
                            dt,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Text(
                            sz,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
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
