import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/accounts/domain/usecases/get_accounts_usecase.dart';
import '../features/accounts/domain/entities/account_entity.dart';
import '../features/cards/domain/usecases/get_cards_usecase.dart';
import '../features/categories/domain/usecases/get_categories_usecase.dart';
import '../features/tags/domain/usecases/get_tags_usecase.dart';
import '../features/cards/domain/entities/card_entity.dart';
import '../features/categories/domain/entities/category_entity.dart';
import '../features/tags/domain/entities/tag_entity.dart';
import '../features/transactions/domain/entities/transaction_entity.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../features/transactions/presentation/cubit/transactions_state.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/transactions_month_scope.dart';
import '../widgets/transactions_totals_bar.dart';

/// Local calendar day (midnight) used as a group key for [transactedAt].
DateTime _calendarDayLocal(DateTime utcOrLocal) {
  final l = utcOrLocal.toLocal();
  return DateTime(l.year, l.month, l.day);
}

sealed class _GroupedTxRow {
  const _GroupedTxRow();
}

final class _DayMarker extends _GroupedTxRow {
  const _DayMarker(this.day);
  final DateTime day;
}

final class _TxMarker extends _GroupedTxRow {
  const _TxMarker(this.transaction);
  final TransactionEntity transaction;
}

List<_GroupedTxRow> _groupTransactionsByDay(List<TransactionEntity> list) {
  final byDay = <DateTime, List<TransactionEntity>>{};
  for (final t in list) {
    final k = _calendarDayLocal(t.transactedAt);
    byDay.putIfAbsent(k, () => []).add(t);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final d in days) {
    byDay[d]!.sort((a, b) => b.transactedAt.compareTo(a.transactedAt));
  }

  final entries = <_GroupedTxRow>[];
  for (final d in days) {
    entries.add(_DayMarker(d));
    for (final t in byDay[d]!) {
      entries.add(_TxMarker(t));
    }
  }
  return entries;
}

({double income, double outcome, double balance}) _transactionTotalsBreakdown(
  Iterable<TransactionEntity> txs, {
  required bool Function(TransactionEntity) include,
  required double Function(TransactionEntity) amount,
}) {
  var income = 0.0;
  var outcome = 0.0;
  var balance = 0.0;
  for (final t in txs) {
    if (!include(t)) continue;
    final v = amount(t);
    balance += v;
    if (v > 0) {
      income += v;
    } else if (v < 0) {
      outcome += -v;
    }
  }
  return (income: income, outcome: outcome, balance: balance);
}

class _TransactionsTotalsBarHost extends StatefulWidget {
  const _TransactionsTotalsBarHost({
    required this.l10n,
    required this.transactions,
  });

  final AppLocalizations l10n;
  final List<TransactionEntity> transactions;

  @override
  State<_TransactionsTotalsBarHost> createState() => _TransactionsTotalsBarHostState();
}

class _TransactionsTotalsBarHostState extends State<_TransactionsTotalsBarHost> {
  bool _altTotals = false;

  @override
  Widget build(BuildContext context) {
    final txs = widget.transactions;
    double weighted(TransactionEntity t) => t.value * t.percentage / 100.0;

    final weightedAll = _transactionTotalsBreakdown(
      txs,
      include: (_) => true,
      amount: weighted,
    );
    final weightedExcludingIgnored = _transactionTotalsBreakdown(
      txs,
      include: (t) => !t.ignore,
      amount: weighted,
    );

    if (!_altTotals) {
      return TransactionsTotalsBar(
        l10n: widget.l10n,
        income: weightedAll.income,
        outcome: weightedAll.outcome,
        balance: weightedAll.balance,
        onDoubleTap: () => setState(() => _altTotals = true),
      );
    }
    return TransactionsTotalsBar(
      l10n: widget.l10n,
      primarySubtitle: widget.l10n.transactionsTotalsExcludingIgnoredHint,
      income: weightedExcludingIgnored.income,
      outcome: weightedExcludingIgnored.outcome,
      balance: weightedExcludingIgnored.balance,
      onDoubleTap: () => setState(() => _altTotals = false),
    );
  }
}

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({
    super.key,
    this.accountIdFilter,
    this.accountNameFilter,
    this.cardIdFilter,
    this.cardNameFilter,
    this.categoryIdFilter,
    this.categoryNameFilter,
    this.tagIdFilter,
    this.tagNameFilter,
  });

  /// When set, only transactions for this account are shown (current month still applies).
  final String? accountIdFilter;
  final String? accountNameFilter;
  final String? cardIdFilter;
  final String? cardNameFilter;
  final String? categoryIdFilter;
  final String? categoryNameFilter;
  final String? tagIdFilter;
  final String? tagNameFilter;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TransactionsCubit>(),
      child: TransactionsMonthHost(
        child: _TransactionsMonthLoadSync(
          child: _TransactionsView(
            accountIdFilter: accountIdFilter,
            accountNameFilter: accountNameFilter,
            cardIdFilter: cardIdFilter,
            cardNameFilter: cardNameFilter,
            categoryIdFilter: categoryIdFilter,
            categoryNameFilter: categoryNameFilter,
            tagIdFilter: tagIdFilter,
            tagNameFilter: tagNameFilter,
          ),
        ),
      ),
    );
  }
}

class _TransactionsMonthLoadSync extends StatefulWidget {
  const _TransactionsMonthLoadSync({required this.child});

  final Widget child;

  @override
  State<_TransactionsMonthLoadSync> createState() =>
      _TransactionsMonthLoadSyncState();
}

class _TransactionsMonthLoadSyncState extends State<_TransactionsMonthLoadSync> {
  ValueNotifier<DateTime>? _notifier;
  VoidCallback? _listener;

  @override
  void dispose() {
    if (_notifier != null && _listener != null) {
      _notifier!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TransactionsMonthScope.of(context);
    if (_notifier != notifier) {
      if (_notifier != null && _listener != null) {
        _notifier!.removeListener(_listener!);
      }
      _notifier = notifier;
      _listener = () {
        context.read<TransactionsCubit>().loadForMonth(notifier.value);
      };
      notifier.addListener(_listener!);
      context.read<TransactionsCubit>().loadForMonth(notifier.value);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TransactionsView extends StatelessWidget {
  const _TransactionsView({
    this.accountIdFilter,
    this.accountNameFilter,
    this.cardIdFilter,
    this.cardNameFilter,
    this.categoryIdFilter,
    this.categoryNameFilter,
    this.tagIdFilter,
    this.tagNameFilter,
  });

  final String? accountIdFilter;
  final String? accountNameFilter;
  final String? cardIdFilter;
  final String? cardNameFilter;
  final String? categoryIdFilter;
  final String? categoryNameFilter;
  final String? tagIdFilter;
  final String? tagNameFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final monthNotifier = TransactionsMonthScope.of(context);
    final String title;
    if (accountNameFilter != null && accountNameFilter!.isNotEmpty) {
      title = '${accountNameFilter!} · ${l10n.transactions}';
    } else if (cardNameFilter != null && cardNameFilter!.isNotEmpty) {
      title = '${cardNameFilter!} · ${l10n.transactions}';
    } else if (categoryNameFilter != null && categoryNameFilter!.isNotEmpty) {
      title = '${categoryNameFilter!} · ${l10n.transactions}';
    } else if (tagNameFilter != null && tagNameFilter!.isNotEmpty) {
      title = '${tagNameFilter!} · ${l10n.transactions}';
    } else {
      title = l10n.transactions;
    }

    final isScoped = (accountIdFilter != null && accountIdFilter!.isNotEmpty) ||
        (cardIdFilter != null && cardIdFilter!.isNotEmpty) ||
        (categoryIdFilter != null && categoryIdFilter!.isNotEmpty) ||
        (tagIdFilter != null && tagIdFilter!.isNotEmpty);

    return BlocConsumer<TransactionsCubit, TransactionsState>(
      listener: (context, state) {
        if (state is TransactionsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        return ValueListenableBuilder<DateTime>(
          valueListenable: monthNotifier,
          builder: (context, visibleMonth, _) {
            final filtered = _filteredTransactions(state);
            final showTotalsBar =
                state is TransactionsLoaded || state is TransactionsActionError;

            return ShellScaffold(
              title: title,
              useDrawer: !isScoped,
              appBarBottom: TransactionsMonthAppBarBottom(notifier: monthNotifier),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _showTxDialog(
                  context,
                  l10n,
                  null,
                  accountIdFilter,
                  cardIdFilter,
                  categoryIdFilter,
                  tagIdFilter,
                ),
                child: const Icon(Icons.add),
              ),
              bottomNavigationBar: showTotalsBar
                  ? _TransactionsTotalsBarHost(
                      l10n: l10n,
                      transactions: filtered,
                    )
                  : null,
              body: _body(
                context,
                state,
                l10n,
                visibleMonth,
                monthNotifier,
                filtered,
              ),
            );
          },
        );
      },
    );
  }

  List<TransactionEntity> _filteredTransactions(TransactionsState state) {
    final rawList = switch (state) {
      TransactionsLoaded(:final transactions) => transactions,
      TransactionsActionError(:final transactions) => transactions,
      _ => <TransactionEntity>[],
    };
    var list = rawList;
    if (accountIdFilter != null && accountIdFilter!.isNotEmpty) {
      list = list.where((t) => t.accountId == accountIdFilter).toList();
    }
    if (cardIdFilter != null && cardIdFilter!.isNotEmpty) {
      list = list.where((t) => t.cardId == cardIdFilter).toList();
    }
    if (categoryIdFilter != null && categoryIdFilter!.isNotEmpty) {
      list = list.where((t) => t.categoryId == categoryIdFilter).toList();
    }
    if (tagIdFilter != null && tagIdFilter!.isNotEmpty) {
      list = list.where((t) => t.tagId == tagIdFilter).toList();
    }
    return list;
  }

  Widget _body(
    BuildContext context,
    TransactionsState state,
    AppLocalizations l10n,
    DateTime visibleMonth,
    ValueNotifier<DateTime> monthNotifier,
    List<TransactionEntity> filteredList,
  ) {
    Future<void> refresh() =>
        context.read<TransactionsCubit>().loadForMonth(monthNotifier.value);

    if (state is TransactionsLoading || state is TransactionsInitial) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    if (state is TransactionsError) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.unexpectedError),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _monthListBody(context, l10n, visibleMonth, filteredList, refresh);
  }

  Widget _monthListBody(
    BuildContext context,
    AppLocalizations l10n,
    DateTime visibleMonth,
    List<TransactionEntity> monthTransactions,
    Future<void> Function() refresh,
  ) {
    if (monthTransactions.isEmpty) {
      final locale = Localizations.localeOf(context);
      final monthYear = DateFormat.yMMMM(locale.toString()).format(visibleMonth);
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.3,
              child: Center(child: Text(l10n.noTransactionsInMonth(monthYear))),
            ),
          ],
        ),
      );
    }

    final rows = _groupTransactionsByDay(monthTransactions);
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          return switch (rows[index]) {
            _DayMarker(:final day) => _TransactionDayHeader(day: day),
            _TxMarker(:final transaction) =>
              _TransactionTile(transaction: transaction, l10n: l10n),
          };
        },
      ),
    );
  }

  void _showTxDialog(
    BuildContext context,
    AppLocalizations l10n, [
    TransactionEntity? tx,
    String? preferredAccountId,
    String? preferredCardId,
    String? preferredCategoryId,
    String? preferredTagId,
  ]) {
    showDialog<void>(
      context: context,
      builder: (_) => _TransactionDialog(
        cubit: context.read<TransactionsCubit>(),
        l10n: l10n,
        transaction: tx,
        preferredAccountId: preferredAccountId,
        preferredCardId: preferredCardId,
        preferredCategoryId: preferredCategoryId,
        preferredTagId: preferredTagId,
      ),
    );
  }
}

class _TransactionDayHeader extends StatelessWidget {
  const _TransactionDayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = DateFormat('yyyy-MM-dd').format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final AppLocalizations l10n;

  const _TransactionTile({
    required this.transaction,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    final relationNames = _relationNames(transaction);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final localTime = transaction.transactedAt.toLocal();

    final weightedValue = transaction.value * transaction.percentage / 100.0;

    Color weightedColor() {
      if (weightedValue > 0) return const Color(0xFF1B8736);
      if (weightedValue < 0) return theme.colorScheme.error;
      return theme.colorScheme.onSurfaceVariant;
    }

    final notFullPercentage = (transaction.percentage - 100.0).abs() > 0.01;

    Widget titleSection() {
      final chunks = <Widget>[];
      final desc = transaction.description;
      final hasDesc = desc != null && desc.isNotEmpty;

      if (hasDesc) {
        if (notFullPercentage) {
          chunks.add(
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '(${transaction.percentage.toStringAsFixed(2)}%) ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: desc,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        } else {
          chunks.add(
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          );
        }
      } else if (notFullPercentage) {
        chunks.add(
          Text(
            '(${transaction.percentage.toStringAsFixed(2)}%)',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }

      if (relationNames.isNotEmpty) {
        chunks.add(
          Padding(
            padding: EdgeInsets.only(top: chunks.isNotEmpty ? 4 : 0),
            child: Text(
              relationNames.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }

      if (chunks.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: chunks,
      );
    }

    final trailingPrices = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          l10n.transactionAmountValue(weightedValue.toStringAsFixed(2)),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: weightedColor(),
            height: 1.2,
          ),
        ),
        if (notFullPercentage) ...[
          const SizedBox(height: 2),
          Text(
            l10n.transactionAmountValue(transaction.value.toStringAsFixed(2)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.1,
              decoration: TextDecoration.lineThrough,
              decorationColor: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          DateFormat.Hm(locale.toString()).format(localTime),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    void openEdit() {
      showDialog<void>(
        context: context,
        builder: (_) => _TransactionDialog(cubit: cubit, l10n: l10n, transaction: transaction),
      );
    }

    return SwipeableListTile(
      itemKey: transaction.id,
      leading: transaction.ignore
          ? Tooltip(
              message: l10n.transactionIgnoredBadge,
              child: Icon(
                Icons.do_not_disturb_on_outlined,
                size: 22,
                color: theme.colorScheme.tertiary,
              ),
            )
          : null,
      title: titleSection(),
      trailing: trailingPrices,
      onEdit: openEdit,
      confirmDelete: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteTransaction),
            content: Text(l10n.confirmDeleteTransaction),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDeleted: () => cubit.delete(id: transaction.id),
    );
  }

  /// Account, card, category, tag labels from embedded FK names (aligned with datasource order).
  static List<String> _relationNames(TransactionEntity t) => [
        if (t.accountName?.isNotEmpty == true) t.accountName!,
        if (t.cardName?.isNotEmpty == true) t.cardName!,
        if (t.categoryName?.isNotEmpty == true) t.categoryName!,
        if (t.tagName?.isNotEmpty == true) t.tagName!,
      ];

}

class _TransactionDialog extends StatefulWidget {
  final TransactionsCubit cubit;
  final AppLocalizations l10n;
  final TransactionEntity? transaction;
  final String? preferredAccountId;
  final String? preferredCardId;
  final String? preferredCategoryId;
  final String? preferredTagId;

  const _TransactionDialog({
    required this.cubit,
    required this.l10n,
    this.transaction,
    this.preferredAccountId,
    this.preferredCardId,
    this.preferredCategoryId,
    this.preferredTagId,
  });

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _transactedAt;
  late final TextEditingController _valueController;
  late final TextEditingController _percentageController;
  late final TextEditingController _descriptionController;
  bool _ignore = false;
  bool _loading = false;
  bool _loadingLookups = true;

  List<AccountEntity> _accounts = [];
  List<CardEntity> _cards = [];
  List<CategoryEntity> _categories = [];
  List<TagEntity> _tags = [];

  String? _accountId;
  String? _cardId;
  String? _categoryId;
  String? _tagId;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _transactedAt = t?.transactedAt.toLocal() ?? DateTime.now();
    _valueController = TextEditingController(
      text: t != null ? t.value.toStringAsFixed(2) : '0.00',
    );
    _percentageController = TextEditingController(text: t != null ? t.percentage.toString() : '0');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _ignore = t?.ignore ?? false;
    _accountId = t?.accountId ?? widget.preferredAccountId;
    _cardId = t?.cardId ?? widget.preferredCardId;
    _categoryId = t?.categoryId ?? widget.preferredCategoryId;
    _tagId = t?.tagId ?? widget.preferredTagId;
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final accounts = await getIt<GetAccountsUsecase>()();
      final cards = await getIt<GetCardsUsecase>()();
      final categories = await getIt<GetCategoriesUsecase>()();
      final tags = await getIt<GetTagsUsecase>()();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _cards = cards;
          _categories = categories;
          _tags = tags;
          if (_accountId != null && !_accounts.any((a) => a.id == _accountId)) _accountId = null;
          if (_cardId != null && !_cards.any((c) => c.id == _cardId)) _cardId = null;
          if (_categoryId != null && !_categories.any((c) => c.id == _categoryId)) _categoryId = null;
          if (_tagId != null && !_tags.any((t) => t.id == _tagId)) _tagId = null;
          _loadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLookups = false);
      }
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _percentageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _transactedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _transactedAt = DateTime(d.year, d.month, d.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final value = double.tryParse(_valueController.text.trim());
    final pct = double.tryParse(_percentageController.text.trim());
    if (value == null || pct == null) return;
    final desc = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    setState(() => _loading = true);
    try {
      if (widget.transaction == null) {
        await widget.cubit.create(
          accountId: _accountId,
          cardId: _cardId,
          categoryId: _categoryId,
          tagId: _tagId,
          description: desc,
          transactedAt: _transactedAt,
          value: value,
          ignore: _ignore,
          percentage: pct,
        );
      } else {
        await widget.cubit.update(
          id: widget.transaction!.id,
          accountId: _accountId,
          cardId: _cardId,
          categoryId: _categoryId,
          tagId: _tagId,
          description: desc,
          transactedAt: _transactedAt,
          value: value,
          ignore: _ignore,
          percentage: pct,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final isEdit = widget.transaction != null;
    final fmt = DateFormat.yMd().add_Hm();

    return AlertDialog(
      title: Text(isEdit ? l10n.editTransaction : l10n.newTransaction),
      content: _loadingLookups
          ? const SizedBox(
              width: 280,
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.transactionDateTime),
                      subtitle: Text(fmt.format(_transactedAt)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_calendar_outlined),
                        onPressed: _pickDateTime,
                      ),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: _accountId,
                      decoration: InputDecoration(labelText: l10n.transactionAccount),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.none)),
                        ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: _cardId,
                      decoration: InputDecoration(labelText: l10n.transactionCard),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.none)),
                        ..._cards.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _cardId = v),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(labelText: l10n.transactionCategory),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.none)),
                        ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: _tagId,
                      decoration: InputDecoration(labelText: l10n.transactionTag),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.none)),
                        ..._tags.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: (v) => setState(() => _tagId = v),
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: l10n.accountDescription),
                      maxLines: 3,
                    ),
                    TextFormField(
                      controller: _valueController,
                      decoration: InputDecoration(labelText: l10n.transactionAmount),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                        if (double.tryParse(v.trim()) == null) return l10n.fieldRequired;
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _percentageController,
                      decoration: InputDecoration(labelText: l10n.transactionPercentage),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                        if (double.tryParse(v.trim()) == null) return l10n.fieldRequired;
                        return null;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.transactionIgnore),
                      value: _ignore,
                      onChanged: (v) => setState(() => _ignore = v),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _loading || _loadingLookups ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _loading || _loadingLookups ? null : _submit,
          child: _loading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
