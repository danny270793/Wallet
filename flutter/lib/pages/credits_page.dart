import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/domain/usecases/list_transactions_having_credit_group_usecase.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../widgets/shell_scaffold.dart';
import 'transactions_page.dart' show showTransactionEditorBottomSheet;

/// Groups rows by [TransactionEntity.creditGroupId]; newest groups (by latest date) first.
List<({String id, List<TransactionEntity> rows})> groupedCreditLedger(
    List<TransactionEntity> flat) {
  final m = <String, List<TransactionEntity>>{};
  for (final t in flat) {
    final g = t.creditGroupId;
    if (g == null || g.isEmpty) continue;
    m.putIfAbsent(g, () => []).add(t);
  }
  for (final rows in m.values) {
    rows.sort((a, b) => a.transactedAt.compareTo(b.transactedAt));
  }
  final out = <({String id, List<TransactionEntity> rows})>[];
  DateTime newest(List<TransactionEntity> r) {
    DateTime mx = r.first.transactedAt;
    for (final x in r) {
      if (x.transactedAt.isAfter(mx)) mx = x.transactedAt;
    }
    return mx;
  }

  final keys = m.keys.toList()..sort((a, b) => newest(m[b]!).compareTo(newest(m[a]!)));
  for (final k in keys) {
    final rows = m[k]!;
    out.add((id: k, rows: rows));
  }
  return out;
}

class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  bool _loading = true;
  Object? _error;
  List<TransactionEntity> _flat = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await getIt<ListTransactionsHavingCreditGroupUsecase>()();
      if (!mounted) return;
      setState(() {
        _flat = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor(TransactionEntity t, AppLocalizations l10n) async {
    final cubit = context.read<TransactionsCubit>();
    await showTransactionEditorBottomSheet(
      context,
      l10n: l10n,
      cubit: cubit,
      transaction: t,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    if (_error != null && !_loading) {
      return ShellScaffold(
        title: l10n.creditsTitle,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.unexpectedError,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final groups = groupedCreditLedger(_flat);

    return ShellScaffold(
      title: l10n.creditsTitle,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 120),
                children: const [
                  Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              )
            : groups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: MediaQuery.paddingOf(context).top + 40),
                  Text(
                    l10n.creditsEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final g = groups[i];
                  final rows = g.rows;
                  final total =
                      rows.fold<double>(0, (a, t) => a + t.value);
                  final label = rows.first.description ?? '';
                  final truncated = label.length > 80
                      ? '${label.substring(0, 80)}…'
                      : label;
                  final pay = rows.first.accountName ??
                      rows.first.cardName ??
                      '—';
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ExpansionTile(
                      initiallyExpanded: i == 0,
                      title: Text(
                        truncated.isEmpty ? l10n.creditsUntitledGroup : truncated,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$pay · ${l10n.creditsInstallmentsCount(rows.length)} · '
                        '${l10n.transactionAmountValue(total.abs().toStringAsFixed(2))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      children: [
                        for (final t in rows)
                          ListTile(
                            dense: true,
                            leading: Text(
                              DateFormat.Hm(locale.toString())
                                  .format(t.transactedAt.toLocal()),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            title: Text(
                              t.description ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              l10n.transactionAmountValue(
                                t.value.toStringAsFixed(2),
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _openEditor(t, l10n),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
