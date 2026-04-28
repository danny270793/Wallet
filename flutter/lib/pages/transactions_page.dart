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
import '../widgets/swipeable_list_tile.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TransactionsCubit>()..load(),
      child: const _TransactionsView(),
    );
  }
}

class _TransactionsView extends StatelessWidget {
  const _TransactionsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<TransactionsCubit, TransactionsState>(
      listener: (context, state) {
        if (state is TransactionsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            _body(context, state, l10n),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _showTxDialog(context, l10n),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, TransactionsState state, AppLocalizations l10n) {
    Future<void> refresh() => context.read<TransactionsCubit>().load();

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

    final list = switch (state) {
      TransactionsLoaded(:final transactions) => transactions,
      TransactionsActionError(:final transactions) => transactions,
      _ => <TransactionEntity>[],
    };

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(child: Text(l10n.noTransactions)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: list.length,
        itemBuilder: (context, index) => _TransactionTile(transaction: list[index], l10n: l10n),
      ),
    );
  }

  void _showTxDialog(BuildContext context, AppLocalizations l10n, [TransactionEntity? tx]) {
    showDialog<void>(
      context: context,
      builder: (_) => _TransactionDialog(
        cubit: context.read<TransactionsCubit>(),
        l10n: l10n,
        transaction: tx,
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
    final dateLine = DateFormat.yMMMd(locale.toString()).format(localTime);

    Color valueColor() {
      if (transaction.value > 0) return const Color(0xFF1B8736);
      if (transaction.value < 0) return theme.colorScheme.error;
      return theme.colorScheme.onSurfaceVariant;
    }

    Widget titleSection() {
      final chunks = <Widget>[];
      if (transaction.description != null && transaction.description!.isNotEmpty) {
        chunks.add(
          Text(
            transaction.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        );
      }
      if (relationNames.isNotEmpty) {
        chunks.add(
          Padding(
            padding: EdgeInsets.only(top: transaction.description?.isNotEmpty == true ? 4 : 0),
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
          l10n.transactionAmountValue(transaction.value.toString()),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor(),
            height: 1.2,
          ),
        ),
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
      title: titleSection(),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          dateLine,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (transaction.ignore)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: l10n.transactionIgnore,
                child: Icon(
                  Icons.visibility_off_rounded,
                  size: 22,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          trailingPrices,
        ],
      ),
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

  const _TransactionDialog({required this.cubit, required this.l10n, this.transaction});

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
    _valueController = TextEditingController(text: t != null ? t.value.toString() : '0');
    _percentageController = TextEditingController(text: t != null ? t.percentage.toString() : '0');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _ignore = t?.ignore ?? false;
    _accountId = t?.accountId;
    _cardId = t?.cardId;
    _categoryId = t?.categoryId;
    _tagId = t?.tagId;
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
