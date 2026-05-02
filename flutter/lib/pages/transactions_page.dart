import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/credit_group_description.dart';
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
import '../features/transactions/domain/usecases/search_transactions_by_description_usecase.dart';
import '../features/transactions/domain/usecases/get_transactions_by_credit_group_id_usecase.dart';
import '../features/wallet_credits/domain/usecases/get_wallet_credit_usecase.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../features/transactions/presentation/cubit/transactions_state.dart';
import '../features/categories/domain/usecases/delete_category_usecase.dart';
import '../features/tags/domain/usecases/delete_tag_usecase.dart';
import '../features/accounts/domain/usecases/delete_account_usecase.dart';
import '../features/cards/domain/usecases/delete_card_usecase.dart';
import '../features/categories/presentation/cubit/categories_cubit.dart';
import '../features/tags/presentation/cubit/tags_cubit.dart';
import '../features/accounts/presentation/cubit/accounts_cubit.dart';
import '../features/cards/presentation/cubit/cards_cubit.dart';
import '../widgets/account_editor_sheet.dart';
import '../widgets/card_editor_sheet.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/tag_editor_sheet.dart';
import '../widgets/grouped_transactions_list.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/transactions_month_scope.dart';
import '../widgets/transactions_totals_bar.dart';
import '../widgets/bottom_sheet_pinned_title.dart';

/// Swipe edit/delete for searchable id+name pickers (category, tag).
class SearchablePickerSwipeActions {
  const SearchablePickerSwipeActions({
    required this.onEditItem,
    required this.confirmDeleteItem,
    required this.deleteItem,
  });

  final Future<void> Function(
    BuildContext sheetContext,
    ({String id, String name}) item,
  )
  onEditItem;
  final Future<bool> Function(
    BuildContext sheetContext,
    ({String id, String name}) item,
  )
  confirmDeleteItem;
  final Future<bool> Function(({String id, String name}) item) deleteItem;
}

/// Swipe edit/delete for account vs card lists in payment method picker.
class PaymentMethodPickerSwipeActions {
  const PaymentMethodPickerSwipeActions({
    required this.editAccount,
    required this.confirmDeleteAccount,
    required this.deleteAccount,
    required this.editCard,
    required this.confirmDeleteCard,
    required this.deleteCard,
  });

  final Future<void> Function(BuildContext sheetContext, AccountEntity a)
  editAccount;
  final Future<bool> Function(BuildContext sheetContext, AccountEntity a)
  confirmDeleteAccount;
  final Future<bool> Function(AccountEntity a) deleteAccount;
  final Future<void> Function(BuildContext sheetContext, CardEntity c) editCard;
  final Future<bool> Function(BuildContext sheetContext, CardEntity c)
  confirmDeleteCard;
  final Future<bool> Function(CardEntity c) deleteCard;
}

Future<bool> _confirmDeletePickerTitle(
  BuildContext context,
  AppLocalizations l10n, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Encodes account vs card in unified payment-method picker sheet results.
const _paymentMethodPickAccountPrefix = 'a:';
const _paymentMethodPickCardPrefix = 'c:';

enum _PaymentMethodCreateChoice { account, card }

/// Parses a transaction amount: optional leading −, digits, optional fractional part.
/// Returns null if empty, not parseable, or not finite. If the string has a comma but no dot, the first comma is treated as the decimal separator.
double? _parseTransactionAmountInput(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains(',') && !s.contains('.')) {
    s = s.replaceFirst(',', '.');
  }
  final x = double.tryParse(s);
  if (x == null || !x.isFinite) return null;
  return x;
}

/// Allows optional leading minus, digits, and at most one `.` or `,` as decimal separator.
final class _DecimalAmountInputFormatter extends TextInputFormatter {
  const _DecimalAmountInputFormatter({this.allowNegative = true});

  final bool allowNegative;

  static String _filter(String input, {required bool allowNegative}) {
    if (input.isEmpty) return input;
    final buf = StringBuffer();
    var hasSep = false;
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (allowNegative && c == '-' && i == 0) {
        buf.write(c);
        continue;
      }
      final u = c.codeUnitAt(0);
      if (u >= 0x30 && u <= 0x39) {
        buf.write(c);
        continue;
      }
      if ((c == '.' || c == ',') && !hasSep) {
        buf.write(c);
        hasSep = true;
      }
    }
    return buf.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = _filter(newValue.text, allowNegative: allowNegative);
    if (filtered == newValue.text) return newValue;
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final mapped = _filter(
      newValue.text.substring(0, end),
      allowNegative: allowNegative,
    ).length;
    final off = mapped.clamp(0, filtered.length);
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: off),
    );
  }
}

const _transactionAmountInputFormatters = <TextInputFormatter>[
  _DecimalAmountInputFormatter(allowNegative: true),
];

const _transferAmountInputFormatters = <TextInputFormatter>[
  _DecimalAmountInputFormatter(allowNegative: false),
];

/// Speed dial: main control plus new-transaction and account transfer.
class TransactionsExpandableFab extends StatelessWidget {
  const TransactionsExpandableFab({
    super.key,
    required this.l10n,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onNewTransaction,
    required this.onTransfer,
    this.transferHeroTag = 'transactions_fab_transfer',
    this.newTransactionHeroTag = 'transactions_fab_new',
    this.toggleHeroTag = 'transactions_fab_toggle',
  });

  final AppLocalizations l10n;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onNewTransaction;
  final VoidCallback onTransfer;
  final String transferHeroTag;
  final String newTransactionHeroTag;
  final String toggleHeroTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isOpen) ...[
          Tooltip(
            message: l10n.transactionsFabTransfer,
            child: FloatingActionButton.small(
              heroTag: transferHeroTag,
              onPressed: () {
                onOpenChanged(false);
                onTransfer();
              },
              child: const Icon(Icons.swap_horiz_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Tooltip(
            message: l10n.newTransaction,
            child: FloatingActionButton.small(
              heroTag: newTransactionHeroTag,
              onPressed: () {
                onOpenChanged(false);
                onNewTransaction();
              },
              child: const Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: toggleHeroTag,
          onPressed: () => onOpenChanged(!isOpen),
          child: Icon(isOpen ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

class _AccountTransferBottomSheet extends StatefulWidget {
  const _AccountTransferBottomSheet({
    required this.cubit,
    required this.l10n,
    this.editingSource,
    this.editingTarget,
  }) : assert(
         (editingSource == null && editingTarget == null) ||
             (editingSource != null && editingTarget != null),
       );

  final TransactionsCubit cubit;
  final AppLocalizations l10n;
  final TransactionEntity? editingSource;
  final TransactionEntity? editingTarget;

  @override
  State<_AccountTransferBottomSheet> createState() =>
      _AccountTransferBottomSheetState();
}

class _AccountTransferBottomSheetState
    extends State<_AccountTransferBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _transactedAt;
  late final TextEditingController _valueController;
  late final TextEditingController _dateDisplayController;
  late final TextEditingController _timeDisplayController;
  late final TextEditingController _sourceDisplayController;
  late final TextEditingController _targetDisplayController;
  List<AccountEntity> _accounts = [];
  List<CardEntity> _cards = [];
  bool _loadingPaymentMethods = true;
  String? _sourcePickKey;
  String? _targetPickKey;
  bool _submitting = false;
  bool _ignorePair = false;

  bool get _isEditingPair =>
      widget.editingSource != null && widget.editingTarget != null;

  int get _paymentMethodCount => _accounts.length + _cards.length;

  @override
  void initState() {
    super.initState();
    final es = widget.editingSource;
    final et = widget.editingTarget;
    if (es != null && et != null) {
      _transactedAt = es.transactedAt.toLocal();
      _sourcePickKey = _entityToPickKey(es);
      _targetPickKey = _entityToPickKey(et);
      _valueController = TextEditingController(
        text: et.value.abs().toStringAsFixed(2),
      );
      _ignorePair = es.ignore || et.ignore;
    } else {
      _transactedAt = DateTime.now();
      _valueController = TextEditingController(text: '0');
    }
    _dateDisplayController = TextEditingController();
    _timeDisplayController = TextEditingController();
    _sourceDisplayController = TextEditingController();
    _targetDisplayController = TextEditingController();
    _loadPaymentMethods();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDateTimeControllers();
    });
  }

  String? _entityToPickKey(TransactionEntity e) {
    if (e.accountId != null)
      return '$_paymentMethodPickAccountPrefix${e.accountId}';
    if (e.cardId != null) return '$_paymentMethodPickCardPrefix${e.cardId}';
    return null;
  }

  void _syncDateTimeControllers() {
    final locale = Localizations.localeOf(context).toString();
    _dateDisplayController.text = DateFormat.yMd(locale).format(_transactedAt);
    _timeDisplayController.text = DateFormat.Hm(locale).format(_transactedAt);
  }

  ({String? accountId, String? cardId}) _parseTransferPickKey(String key) {
    if (key.startsWith(_paymentMethodPickAccountPrefix)) {
      return (
        accountId: key.substring(_paymentMethodPickAccountPrefix.length),
        cardId: null,
      );
    }
    if (key.startsWith(_paymentMethodPickCardPrefix)) {
      return (
        accountId: null,
        cardId: key.substring(_paymentMethodPickCardPrefix.length),
      );
    }
    return (accountId: null, cardId: null);
  }

  void _syncLegDisplayControllers() {
    String labelFor(String? key) {
      if (key == null) return '';
      if (key.startsWith(_paymentMethodPickAccountPrefix)) {
        final id = key.substring(_paymentMethodPickAccountPrefix.length);
        for (final a in _accounts) {
          if (a.id == id) return a.name;
        }
      } else if (key.startsWith(_paymentMethodPickCardPrefix)) {
        final id = key.substring(_paymentMethodPickCardPrefix.length);
        for (final c in _cards) {
          if (c.id == id) return c.name;
        }
      }
      return '';
    }

    _sourceDisplayController.text = labelFor(_sourcePickKey);
    _targetDisplayController.text = labelFor(_targetPickKey);
  }

  bool _pickKeyStillValid(String? key) {
    if (key == null) return false;
    final p = _parseTransferPickKey(key);
    if (p.accountId != null) return _accounts.any((a) => a.id == p.accountId);
    if (p.cardId != null) return _cards.any((c) => c.id == p.cardId);
    return false;
  }

  void _pruneStalePickKeysAndDefault() {
    if (!_pickKeyStillValid(_sourcePickKey)) _sourcePickKey = null;
    if (!_pickKeyStillValid(_targetPickKey)) _targetPickKey = null;
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final accounts = await getIt<GetAccountsUsecase>()();
      final cards = await getIt<GetCardsUsecase>()();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _cards = cards;
        _loadingPaymentMethods = false;
        _pruneStalePickKeysAndDefault();
      });
      _syncLegDisplayControllers();
    } catch (_) {
      if (mounted) setState(() => _loadingPaymentMethods = false);
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _dateDisplayController.dispose();
    _timeDisplayController.dispose();
    _sourceDisplayController.dispose();
    _targetDisplayController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _transactedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _transactedAt = DateTime(
        d.year,
        d.month,
        d.day,
        _transactedAt.hour,
        _transactedAt.minute,
      );
    });
    _syncDateTimeControllers();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _transactedAt = DateTime(
        _transactedAt.year,
        _transactedAt.month,
        _transactedAt.day,
        time.hour,
        time.minute,
      );
    });
    _syncDateTimeControllers();
  }

  Future<void> _pickTransferLeg({required bool source}) async {
    final l10n = widget.l10n;
    final raw = await showPaymentMethodPickerSheet(
      context,
      l10n: l10n,
      sheetTitle: source
          ? l10n.transferSourceAccount
          : l10n.transferTargetAccount,
      getAccounts: () => _accounts,
      getCards: () => _cards,
      onListsUpdated: (a, c) {
        if (!mounted) return;
        setState(() {
          _accounts = a;
          _cards = c;
          _pruneStalePickKeysAndDefault();
          _syncLegDisplayControllers();
        });
      },
    );
    if (!mounted || raw == null || raw.isEmpty) return;
    setState(() {
      if (source) {
        _sourcePickKey = raw;
      } else {
        _targetPickKey = raw;
      }
    });
    _syncLegDisplayControllers();
  }

  Future<void> _submit() async {
    if (_loadingPaymentMethods || _paymentMethodCount < 2) return;
    if (!_formKey.currentState!.validate()) return;
    if (_sourcePickKey == null || _targetPickKey == null) return;
    if (_sourcePickKey == _targetPickKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.transferAccountsMustDiffer)),
      );
      return;
    }
    final amount = _parseTransactionAmountInput(_valueController.text);
    if (amount == null || amount <= 0) return;

    final s = _parseTransferPickKey(_sourcePickKey!);
    final t = _parseTransferPickKey(_targetPickKey!);

    setState(() => _submitting = true);
    final ok = _isEditingPair
        ? await widget.cubit.updateAccountTransfer(
            source: widget.editingSource!,
            target: widget.editingTarget!,
            sourceAccountId: s.accountId,
            sourceCardId: s.cardId,
            targetAccountId: t.accountId,
            targetCardId: t.cardId,
            amount: amount,
            transactedAt: _transactedAt,
            ignore: _ignorePair,
          )
        : await widget.cubit.transferBetweenPaymentMethods(
            sourceAccountId: s.accountId,
            sourceCardId: s.cardId,
            targetAccountId: t.accountId,
            targetCardId: t.cardId,
            amount: amount,
            transactedAt: _transactedAt,
          );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return BottomSheetPinnedTitleScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      title: _isEditingPair ? l10n.editTransferTitle : l10n.transferSheetTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    controller: _dateDisplayController,
                    decoration: InputDecoration(
                      labelText: l10n.transferDateLabel,
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                      ),
                    ),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    controller: _timeDisplayController,
                    decoration: InputDecoration(
                      labelText: l10n.transferTimeLabel,
                      suffixIcon: const Icon(Icons.schedule, size: 20),
                    ),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingPaymentMethods)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.transferSourceAccount,
                      ),
                      child: const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.transferTargetAccount,
                      ),
                      child: const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (_paymentMethodCount < 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.transferNeedTwoAccounts,
                  textAlign: TextAlign.center,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      enableInteractiveSelection: false,
                      showCursor: false,
                      controller: _sourceDisplayController,
                      decoration: InputDecoration(
                        labelText: l10n.transferSourceAccount,
                        suffixIcon: const Icon(
                          Icons.expand_more_rounded,
                          size: 22,
                        ),
                      ),
                      validator: (_) =>
                          _sourcePickKey == null ? l10n.fieldRequired : null,
                      onTap: () => _pickTransferLeg(source: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      enableInteractiveSelection: false,
                      showCursor: false,
                      controller: _targetDisplayController,
                      decoration: InputDecoration(
                        labelText: l10n.transferTargetAccount,
                        suffixIcon: const Icon(
                          Icons.expand_more_rounded,
                          size: 22,
                        ),
                      ),
                      validator: (_) =>
                          _targetPickKey == null ? l10n.fieldRequired : null,
                      onTap: () => _pickTransferLeg(source: false),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valueController,
              decoration: InputDecoration(labelText: l10n.transactionAmount),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: _transferAmountInputFormatters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                final amt = _parseTransactionAmountInput(v);
                if (amt == null) return l10n.transactionAmountInvalidNumber;
                if (amt <= 0) return l10n.transferAmountMustBePositive;
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  _submitting ||
                      _loadingPaymentMethods ||
                      _paymentMethodCount < 2
                  ? null
                  : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

void showAccountTransferCreateBottomSheet(
  BuildContext context, {
  required AppLocalizations l10n,
}) {
  final cubit = context.read<TransactionsCubit>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => _AccountTransferBottomSheet(cubit: cubit, l10n: l10n),
  );
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
        child: TransactionsMonthCubitSync(
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

class _TransactionsView extends StatefulWidget {
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
  State<_TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<_TransactionsView> {
  bool _fabMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final monthNotifier = TransactionsMonthScope.of(context);
    final String title;
    if (widget.accountNameFilter != null &&
        widget.accountNameFilter!.isNotEmpty) {
      title = '${widget.accountNameFilter!} · ${l10n.transactions}';
    } else if (widget.cardNameFilter != null &&
        widget.cardNameFilter!.isNotEmpty) {
      title = '${widget.cardNameFilter!} · ${l10n.transactions}';
    } else if (widget.categoryNameFilter != null &&
        widget.categoryNameFilter!.isNotEmpty) {
      title = '${widget.categoryNameFilter!} · ${l10n.transactions}';
    } else if (widget.tagNameFilter != null &&
        widget.tagNameFilter!.isNotEmpty) {
      title = '${widget.tagNameFilter!} · ${l10n.transactions}';
    } else {
      title = l10n.transactions;
    }

    final isScoped =
        (widget.accountIdFilter != null &&
            widget.accountIdFilter!.isNotEmpty) ||
        (widget.cardIdFilter != null && widget.cardIdFilter!.isNotEmpty) ||
        (widget.categoryIdFilter != null &&
            widget.categoryIdFilter!.isNotEmpty) ||
        (widget.tagIdFilter != null && widget.tagIdFilter!.isNotEmpty);

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
              appBarBottom: TransactionsMonthAppBarBottom(
                notifier: monthNotifier,
              ),
              appBarActionsBeforeSettings: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.transactionsSearchTooltip,
                  onPressed: () async {
                    final searchCubit = context.read<TransactionsCubit>();
                    final tx = await showSearch<TransactionEntity?>(
                      context: context,
                      delegate: _TransactionSearchDelegate(
                        cubit: searchCubit,
                        l10n: l10n,
                        search: getIt<SearchTransactionsByDescriptionUsecase>(),
                        localTransactions: filtered,
                      ),
                    );
                    if (!context.mounted || tx == null) return;
                    _showTxDialog(
                      context,
                      l10n,
                      tx,
                      widget.accountIdFilter,
                      widget.cardIdFilter,
                      widget.categoryIdFilter,
                      widget.tagIdFilter,
                    );
                  },
                ),
              ],
              floatingActionButton: TransactionsExpandableFab(
                l10n: l10n,
                isOpen: _fabMenuOpen,
                onOpenChanged: (v) => setState(() => _fabMenuOpen = v),
                onNewTransaction: () => _showTxDialog(
                  context,
                  l10n,
                  null,
                  widget.accountIdFilter,
                  widget.cardIdFilter,
                  widget.categoryIdFilter,
                  widget.tagIdFilter,
                ),
                onTransfer: () =>
                    showAccountTransferCreateBottomSheet(context, l10n: l10n),
              ),
              bottomNavigationBar: showTotalsBar
                  ? TransactionsTotalsBarHost(
                      l10n: l10n,
                      transactions: filtered,
                    )
                  : null,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    ignoring: _fabMenuOpen,
                    child: _body(
                      context,
                      state,
                      l10n,
                      visibleMonth,
                      monthNotifier,
                      filtered,
                    ),
                  ),
                  if (_fabMenuOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _fabMenuOpen = false),
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                    ),
                ],
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
    if (widget.accountIdFilter != null && widget.accountIdFilter!.isNotEmpty) {
      list = list.where((t) => t.accountId == widget.accountIdFilter).toList();
    }
    if (widget.cardIdFilter != null && widget.cardIdFilter!.isNotEmpty) {
      list = list.where((t) => t.cardId == widget.cardIdFilter).toList();
    }
    if (widget.categoryIdFilter != null &&
        widget.categoryIdFilter!.isNotEmpty) {
      list = list
          .where((t) => t.categoryId == widget.categoryIdFilter)
          .toList();
    }
    if (widget.tagIdFilter != null && widget.tagIdFilter!.isNotEmpty) {
      list = list.where((t) => t.tagId == widget.tagIdFilter).toList();
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
    Future<void> pullRefresh() =>
        context.read<TransactionsCubit>().loadForMonth(
              monthNotifier.value,
              showLoading: false,
            );

    Future<void> reloadWithOverlay() =>
        context.read<TransactionsCubit>().loadForMonth(
              monthNotifier.value,
              showLoading: true,
            );

    if (state is TransactionsLoading || state is TransactionsInitial) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
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
        onRefresh: pullRefresh,
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
                      onPressed: reloadWithOverlay,
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

    return _monthListBody(
      context,
      l10n,
      visibleMonth,
      filteredList,
      pullRefresh,
      context.read<TransactionsCubit>(),
    );
  }

  Widget _monthListBody(
    BuildContext context,
    AppLocalizations l10n,
    DateTime visibleMonth,
    List<TransactionEntity> monthTransactions,
    Future<void> Function() refresh,
    TransactionsCubit cubit,
  ) {
    if (monthTransactions.isEmpty) {
      final locale = Localizations.localeOf(context);
      final monthYear = DateFormat.yMMMM(
        locale.toString(),
      ).format(visibleMonth);
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

    final rows = groupedTransactionsForList(monthTransactions);
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          return switch (rows[index]) {
            GroupedTxnDayMarker(:final day) => GroupedTxnDayHeader(day: day),
            GroupedTxnTxMarker(:final transaction) => GroupedTxnTransactionTile(
              transaction: transaction,
              l10n: l10n,
            ),
            GroupedTxnTransferPairMarker(:final source, :final target) =>
              GroupedTxnTransferPairTile(
                source: source,
                target: target,
                l10n: l10n,
              ),
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
    showTransactionEditorBottomSheet(
      context,
      l10n: l10n,
      cubit: context.read<TransactionsCubit>(),
      transaction: tx,
      preferredAccountId: preferredAccountId,
      preferredCardId: preferredCardId,
      preferredCategoryId: preferredCategoryId,
      preferredTagId: preferredTagId,
    );
  }
}

Future<void> showTransactionEditorBottomSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required TransactionsCubit cubit,
  TransactionEntity? transaction,
  String? preferredAccountId,
  String? preferredCardId,
  String? preferredCategoryId,
  String? preferredTagId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => _TransactionDialog(
      cubit: cubit,
      l10n: l10n,
      transaction: transaction,
      preferredAccountId: preferredAccountId,
      preferredCardId: preferredCardId,
      preferredCategoryId: preferredCategoryId,
      preferredTagId: preferredTagId,
    ),
  );
}

void showAccountTransferEditorBottomSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required TransactionEntity editingSource,
  required TransactionEntity editingTarget,
}) {
  final cubit = context.read<TransactionsCubit>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    builder: (_) => _AccountTransferBottomSheet(
      cubit: cubit,
      l10n: l10n,
      editingSource: editingSource,
      editingTarget: editingTarget,
    ),
  );
}

class _TransactionSearchDelegate extends SearchDelegate<TransactionEntity?> {
  _TransactionSearchDelegate({
    required this.cubit,
    required this.l10n,
    required this.search,
    required this.localTransactions,
  });

  final TransactionsCubit cubit;
  final AppLocalizations l10n;
  final SearchTransactionsByDescriptionUsecase search;

  /// Already-loaded list for the visible month (and scoped filters), for instant local search.
  final List<TransactionEntity> localTransactions;

  @override
  String get searchFieldLabel => l10n.transactionsSearchHint;

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _searchBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _searchBody(context);

  Widget _searchBody(BuildContext context) {
    return _TransactionSearchBody(
      cubit: cubit,
      l10n: l10n,
      query: query,
      localTransactions: localTransactions,
      search: search,
      onSelect: (t) => close(context, t),
    );
  }
}

List<TransactionEntity> _localTransactionsMatchingDescription(
  List<TransactionEntity> transactions,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return [];
  return transactions
      .where((t) => (t.description ?? '').toLowerCase().contains(needle))
      .toList();
}

List<TransactionEntity> _mergeTransactionListsByIdNewestFirst(
  List<TransactionEntity> a,
  List<TransactionEntity> b,
) {
  final byId = <String, TransactionEntity>{};
  for (final t in a) {
    byId[t.id] = t;
  }
  for (final t in b) {
    byId[t.id] = t;
  }
  final out = byId.values.toList()
    ..sort((x, y) => y.transactedAt.compareTo(x.transactedAt));
  return out;
}

class _TransactionSearchBody extends StatefulWidget {
  const _TransactionSearchBody({
    required this.cubit,
    required this.l10n,
    required this.query,
    required this.localTransactions,
    required this.search,
    required this.onSelect,
  });

  final TransactionsCubit cubit;
  final AppLocalizations l10n;
  final String query;
  final List<TransactionEntity> localTransactions;
  final SearchTransactionsByDescriptionUsecase search;
  final void Function(TransactionEntity t) onSelect;

  @override
  State<_TransactionSearchBody> createState() => _TransactionSearchBodyState();
}

class _TransactionSearchBodyState extends State<_TransactionSearchBody> {
  static const _debounceMs = 450;

  Timer? _debounce;
  Future<List<TransactionEntity>>? _remoteFuture;
  String? _remoteForQuery;

  @override
  void initState() {
    super.initState();
    _onQueryChanged();
  }

  @override
  void didUpdateWidget(covariant _TransactionSearchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _onQueryChanged();
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final q = widget.query.trim();
    if (q.isEmpty) {
      setState(() {
        _remoteFuture = null;
        _remoteForQuery = null;
      });
      return;
    }
    setState(() {
      _remoteFuture = null;
      _remoteForQuery = null;
    });
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      final trimmed = widget.query.trim();
      if (trimmed.isEmpty) return;
      setState(() {
        _remoteFuture = widget.search(trimmed);
        _remoteForQuery = trimmed;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query.trim();
    if (q.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.l10n.transactionsSearchTypeQuery,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final local = _localTransactionsMatchingDescription(
      widget.localTransactions,
      q,
    );

    if (_remoteFuture == null) {
      if (local.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return _transactionSearchResultsList(
        context,
        cubit: widget.cubit,
        l10n: widget.l10n,
        list: local,
        onSelect: widget.onSelect,
        top: null,
      );
    }

    return FutureBuilder<List<TransactionEntity>>(
      key: ValueKey(_remoteForQuery),
      future: _remoteFuture,
      builder: (context, snapshot) {
        final forQuery = widget.query.trim();
        final staleRemote =
            _remoteForQuery != null && _remoteForQuery != forQuery;

        if (snapshot.connectionState == ConnectionState.waiting &&
            !staleRemote) {
          if (local.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return _transactionSearchResultsList(
            context,
            cubit: widget.cubit,
            l10n: widget.l10n,
            list: local,
            onSelect: widget.onSelect,
            top: const LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.hasError && !staleRemote) {
          if (local.isNotEmpty) {
            return _transactionSearchResultsList(
              context,
              cubit: widget.cubit,
              l10n: widget.l10n,
              list: local,
              onSelect: widget.onSelect,
              top: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.l10n.unexpectedError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          return Center(child: Text(widget.l10n.unexpectedError));
        }

        if (staleRemote || !snapshot.hasData) {
          return _transactionSearchResultsList(
            context,
            cubit: widget.cubit,
            l10n: widget.l10n,
            list: local,
            onSelect: widget.onSelect,
            top: null,
          );
        }

        final list = snapshot.data!;
        if (list.isEmpty) {
          return Center(child: Text(widget.l10n.transactionsSearchNoResults));
        }
        return _transactionSearchResultsList(
          context,
          cubit: widget.cubit,
          l10n: widget.l10n,
          list: list,
          onSelect: widget.onSelect,
          top: null,
        );
      },
    );
  }
}

Widget _transactionSearchResultsList(
  BuildContext context, {
  required TransactionsCubit cubit,
  required AppLocalizations l10n,
  required List<TransactionEntity> list,
  required void Function(TransactionEntity t) onSelect,
  required Widget? top,
}) {
  if (list.isEmpty) {
    return Center(child: Text(l10n.transactionsSearchNoResults));
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ?top,
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final t = list[i];
            return GroupedTxnTransactionTile(
              cubit: cubit,
              transaction: t,
              l10n: l10n,
              onTap: () => onSelect(t),
            );
          },
        ),
      ),
    ],
  );
}

/// Picks an id from a searchable list. Items are shown in alphabetical order by [name].
/// Returns `null` if dismissed, `''` if [allowNone] and user cleared.
///
/// Use [getItems] so each build reads the parent's current lists. The modal sheet [builder] can rerun
/// when the parent rebuilds after [reloadItems]; snapshots in the outer closure would stay stale.
Future<String?> _showSearchableIdPickerSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required String title,
  required String searchHint,
  required String noResultsMessage,
  required String emptyMessage,
  required bool allowNone,
  required List<({String id, String name})> Function() getItems,
  Future<void> Function(BuildContext sheetContext)? onAddPressed,
  String? addTooltip,
  Future<void> Function()? reloadItems,
  SearchablePickerSwipeActions? swipe,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (sheetContext) => _SearchableIdPickerSheet(
      l10n: l10n,
      sheetContext: sheetContext,
      title: title,
      searchHint: searchHint,
      noResultsMessage: noResultsMessage,
      emptyMessage: emptyMessage,
      allowNone: allowNone,
      getItems: getItems,
      onAddPressed: onAddPressed,
      addTooltip: addTooltip,
      reloadItems: reloadItems,
      swipe: swipe,
    ),
  );
}

/// Search/filter state lives here—not in [showModalBottomSheet]'s [builder], which can rebuild when
/// the keyboard opens ([MediaQuery] view inset changes) and would reset stray locals otherwise.
class _SearchableIdPickerSheet extends StatefulWidget {
  const _SearchableIdPickerSheet({
    required this.l10n,
    required this.sheetContext,
    required this.title,
    required this.searchHint,
    required this.noResultsMessage,
    required this.emptyMessage,
    required this.allowNone,
    required this.getItems,
    this.onAddPressed,
    this.addTooltip,
    this.reloadItems,
    this.swipe,
  });

  final AppLocalizations l10n;
  final BuildContext sheetContext;
  final String title;
  final String searchHint;
  final String noResultsMessage;
  final String emptyMessage;
  final bool allowNone;
  final List<({String id, String name})> Function() getItems;
  final Future<void> Function(BuildContext sheetContext)? onAddPressed;
  final String? addTooltip;
  final Future<void> Function()? reloadItems;
  final SearchablePickerSwipeActions? swipe;

  @override
  State<_SearchableIdPickerSheet> createState() => _SearchableIdPickerSheetState();
}

class _SearchableIdPickerSheetState extends State<_SearchableIdPickerSheet> {
  bool _showSearchField = false;
  String _searchFilter = '';

  List<({String id, String name})> _visible() {
    final items = [...widget.getItems()]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final q = _searchFilter.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _refreshItems() async {
    final r = widget.reloadItems;
    if (r == null) return;
    await r();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sheetContext = widget.sheetContext;
    final allItems = widget.getItems();
    final list = _visible();

    final themeSheet = Theme.of(sheetContext);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.55,
        ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              automaticallyImplyLeading: false,
              elevation: 0,
              scrolledUnderElevation: 4,
              backgroundColor: modalBottomSheetSurfaceColor(sheetContext),
              shadowColor: Theme.of(sheetContext).colorScheme.shadow,
              leading: modalBottomSheetBackButton(sheetContext),
              title: Text(widget.title, style: themeSheet.textTheme.titleLarge),
              actions: [
                IconButton(
                  tooltip: widget.l10n.transferAccountSearch,
                  icon: Icon(
                    _showSearchField
                        ? Icons.search_off_outlined
                        : Icons.search,
                  ),
                  onPressed: () {
                    setState(() {
                      _showSearchField = !_showSearchField;
                      if (!_showSearchField) _searchFilter = '';
                    });
                  },
                ),
                if (widget.onAddPressed != null)
                  IconButton(
                    tooltip: widget.addTooltip ?? '',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () async {
                      await widget.onAddPressed!(sheetContext);
                      await _refreshItems();
                    },
                  ),
              ],
            ),
            if (widget.allowNone)
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text(widget.l10n.none),
                  leading: const Icon(Icons.clear),
                  onTap: () => Navigator.of(sheetContext).pop(''),
                ),
              ),
            if (_showSearchField)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search, size: 22),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _searchFilter = v),
                  ),
                ),
              ),
            if (allItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(widget.emptyMessage)),
              )
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(widget.noResultsMessage)),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final e = list[index];
                  final swipe = widget.swipe;
                  if (swipe == null) {
                    return ListTile(
                      title: Text(e.name),
                      onTap: () => Navigator.of(sheetContext).pop(e.id),
                    );
                  }
                  final actions = swipe;
                  return SwipeableListTile(
                    itemKey: e.id,
                    title: Text(e.name),
                    onTap: () => Navigator.of(sheetContext).pop(e.id),
                    onEdit: () {
                      Future(() async {
                        await actions.onEditItem(sheetContext, e);
                        if (!sheetContext.mounted) return;
                        await _refreshItems();
                      });
                    },
                    confirmDelete: () =>
                        actions.confirmDeleteItem(sheetContext, e),
                    onDelete: () async {
                      final ok = await actions.deleteItem(e);
                      if (ok) await _refreshItems();
                      return ok;
                    },
                  );
                }, childCount: list.length),
              ),
          ],
        ),
      ),
    );
  }
}

/// Returns `a:id` or `c:id`. [onListsUpdated] should update parent state (e.g. [setState]).
///
/// Use [getAccounts]/[getCards] so each build reads fresh lists after the parent reloads via
/// [onListsUpdated]. The modal [builder] can rerun when the parent rebuilds.
Future<String?> showPaymentMethodPickerSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required String sheetTitle,
  required List<AccountEntity> Function() getAccounts,
  required List<CardEntity> Function() getCards,
  required void Function(List<AccountEntity> accounts, List<CardEntity> cards)
  onListsUpdated,
  PaymentMethodPickerSwipeActions? paymentSwipe,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (sheetContext) {
      var showSearchField = false;
      var searchFilter = '';

      return StatefulBuilder(
        builder: (context, setPickerState) {
          Future<void> refreshPicker() async {
            final freshAccounts = await getIt<GetAccountsUsecase>()();
            final freshCards = await getIt<GetCardsUsecase>()();
            onListsUpdated(freshAccounts, freshCards);
            setPickerState(() {});
          }

          List<AccountEntity> visibleAccounts() {
            final q = searchFilter.trim().toLowerCase();
            final pickerAccounts = getAccounts();
            if (q.isEmpty) return pickerAccounts;
            return pickerAccounts
                .where((a) => a.name.toLowerCase().contains(q))
                .toList();
          }

          List<CardEntity> visibleCards() {
            final q = searchFilter.trim().toLowerCase();
            final pickerCards = getCards();
            if (q.isEmpty) return pickerCards;
            return pickerCards
                .where((c) => c.name.toLowerCase().contains(q))
                .toList();
          }

          final vAccounts = visibleAccounts();
          final vCards = visibleCards();
          final pickerAccountsSnapshot = getAccounts();
          final pickerCardsSnapshot = getCards();
          final hasAny =
              pickerAccountsSnapshot.isNotEmpty ||
              pickerCardsSnapshot.isNotEmpty;
          final filteredEmpty = vAccounts.isEmpty && vCards.isEmpty;

          final sheetTheme = Theme.of(sheetContext);
          final titleSmallPrimary = sheetTheme.textTheme.titleSmall?.copyWith(
            color: sheetTheme.colorScheme.primary,
          );

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.55,
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    centerTitle: true,
                    automaticallyImplyLeading: false,
                    elevation: 0,
                    scrolledUnderElevation: 4,
                    backgroundColor: modalBottomSheetSurfaceColor(sheetContext),
                    shadowColor: Theme.of(sheetContext).colorScheme.shadow,
                    leading: modalBottomSheetBackButton(sheetContext),
                    title: Text(
                      sheetTitle,
                      style: sheetTheme.textTheme.titleLarge,
                    ),
                    actions: [
                      IconButton(
                        tooltip: l10n.transferAccountSearch,
                        icon: Icon(
                          showSearchField
                              ? Icons.search_off_outlined
                              : Icons.search,
                        ),
                        onPressed: () {
                          setPickerState(() {
                            showSearchField = !showSearchField;
                            if (!showSearchField) searchFilter = '';
                          });
                        },
                      ),
                      IconButton(
                        tooltip: l10n.paymentMethodAddChoiceTitle,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          final choice =
                              await showModalBottomSheet<
                                _PaymentMethodCreateChoice
                              >(
                                context: sheetContext,
                                showDragHandle: false,
                                isScrollControlled: true,
                                builder: (ctx) => BottomSheetPinnedTitleScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    24 + MediaQuery.paddingOf(ctx).bottom,
                                  ),
                                  title: l10n.paymentMethodAddChoiceTitle,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.account_balance_wallet_outlined,
                                        ),
                                        title: Text(l10n.newAccount),
                                        onTap: () => Navigator.pop(
                                          ctx,
                                          _PaymentMethodCreateChoice.account,
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.credit_card_outlined,
                                        ),
                                        title: Text(l10n.newCard),
                                        onTap: () => Navigator.pop(
                                          ctx,
                                          _PaymentMethodCreateChoice.card,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                          if (!sheetContext.mounted) return;
                          switch (choice) {
                            case _PaymentMethodCreateChoice.account:
                              await showAccountEditorBottomSheet(
                                sheetContext,
                                l10n,
                              );
                            case _PaymentMethodCreateChoice.card:
                              await showCardEditorBottomSheet(
                                sheetContext,
                                l10n,
                              );
                            case null:
                              return;
                          }
                          await refreshPicker();
                        },
                      ),
                    ],
                  ),
                  if (showSearchField)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: l10n.transferAccountSearchHint,
                            prefixIcon: const Icon(Icons.search, size: 22),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.search,
                          onChanged: (v) =>
                              setPickerState(() => searchFilter = v),
                        ),
                      ),
                    ),
                  if (!hasAny)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '${l10n.noAccounts}\n${l10n.noCards}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else if (filteredEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          l10n.transactionPaymentMethodSearchNoResults,
                        ),
                      ),
                    )
                  else
                    SliverList.list(
                      children: [
                        if (vCards.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(l10n.cards, style: titleSmallPrimary),
                          ),
                          ...vCards.map((c) {
                            final sw = paymentSwipe;
                            if (sw == null) {
                              return ListTile(
                                leading: const Icon(Icons.credit_card_outlined),
                                title: Text(c.name),
                                onTap: () => Navigator.of(
                                  sheetContext,
                                ).pop('$_paymentMethodPickCardPrefix${c.id}'),
                              );
                            }
                            return SwipeableListTile(
                              itemKey: c.id,
                              leading: const Icon(Icons.credit_card_outlined),
                              title: Text(c.name),
                              onTap: () => Navigator.of(
                                sheetContext,
                              ).pop('$_paymentMethodPickCardPrefix${c.id}'),
                              onEdit: () {
                                Future(() async {
                                  await sw.editCard(sheetContext, c);
                                  if (!sheetContext.mounted) return;
                                  await refreshPicker();
                                });
                              },
                              confirmDelete: () =>
                                  sw.confirmDeleteCard(sheetContext, c),
                              onDelete: () async {
                                final ok = await sw.deleteCard(c);
                                if (ok) await refreshPicker();
                                return ok;
                              },
                            );
                          }),
                        ],
                        if (vAccounts.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(
                              l10n.accounts,
                              style: titleSmallPrimary,
                            ),
                          ),
                          ...vAccounts.map((a) {
                            final sw = paymentSwipe;
                            if (sw == null) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                title: Text(a.name),
                                onTap: () => Navigator.of(sheetContext).pop(
                                  '$_paymentMethodPickAccountPrefix${a.id}',
                                ),
                              );
                            }
                            return SwipeableListTile(
                              itemKey: a.id,
                              leading: const Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                              title: Text(a.name),
                              onTap: () => Navigator.of(
                                sheetContext,
                              ).pop('$_paymentMethodPickAccountPrefix${a.id}'),
                              onEdit: () {
                                Future(() async {
                                  await sw.editAccount(sheetContext, a);
                                  if (!sheetContext.mounted) return;
                                  await refreshPicker();
                                });
                              },
                              confirmDelete: () =>
                                  sw.confirmDeleteAccount(sheetContext, a),
                              onDelete: () async {
                                final ok = await sw.deleteAccount(a);
                                if (ok) await refreshPicker();
                                return ok;
                              },
                            );
                          }),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
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
  final _valueFieldKey = GlobalKey<FormFieldState<String>>();
  final _percentageFieldKey = GlobalKey<FormFieldState<String>>();
  final _paymentMethodFieldKey = GlobalKey<FormFieldState<String>>();
  final _categoryFieldKey = GlobalKey<FormFieldState<String>>();
  final _tagFieldKey = GlobalKey<FormFieldState<String>>();
  late DateTime _transactedAt;
  late final TextEditingController _valueController;
  late final TextEditingController _percentageController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateDisplayController;
  late final TextEditingController _timeDisplayController;
  late final TextEditingController _paymentMethodDisplayController;
  late final TextEditingController _categoryDisplayController;
  late final TextEditingController _tagDisplayController;
  bool _ignore = false;
  bool _loading = false;
  bool _loadingLookups = true;

  bool get _isCreditGroupEdit {
    final k = widget.transaction?.creditLedgerGroupingKey;
    return k != null && k.isNotEmpty;
  }

  List<AccountEntity> _accounts = [];
  List<CardEntity> _cards = [];
  List<CategoryEntity> _categories = [];
  List<TagEntity> _tags = [];

  String? _accountId;
  String? _cardId;
  String? _categoryId;
  String? _tagId;

  bool _deferred = false;
  late final TextEditingController _graceMonthsController;
  late final TextEditingController _termMonthsController;

  /// True while fetching group installments to show summed amount (edit + creditId).
  bool _loadingCreditGroupTotal = false;

  /// New deferred card installments are saved with ignore=true regardless of toggle.
  bool get _creatingDeferredInstallments =>
      widget.transaction == null && _deferred && _cardId != null;

  /// Credits (deferred installments) ignore totals; Ignore is locked for create/installments and edit.
  bool get _ignoreSwitchLocked =>
      _creatingDeferredInstallments || _isCreditGroupEdit;

  bool get _ignoreSwitchShowsOn =>
      _creatingDeferredInstallments ? true : _ignore;

  Timer? _descriptionSuggestDebounce;
  List<TransactionEntity> _descriptionSuggestionMatches = const [];
  bool _descriptionSuggestLoading = false;

  /// After selecting a suggestion, hide the list until the description text changes.
  bool _dismissSuggestionsUntilDescriptionChange = false;
  String? _descriptionSnapshotWhenSuggestionsDismissed;

  static const _descriptionSuggestDebounceMs = 400;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _transactedAt = t?.transactedAt.toLocal() ?? DateTime.now();
    if (t != null) {
      _valueController = TextEditingController(
        text: t.value.toStringAsFixed(2),
      );
      _percentageController = TextEditingController(
        text: t.percentage.toString(),
      );
    } else {
      _valueController = TextEditingController();
      _percentageController = TextEditingController();
    }
    _descriptionController = TextEditingController(
      text: (t != null &&
              (t.creditLedgerGroupingKey?.isNotEmpty ?? false))
          ? stripLeadingCreditInstallmentDescription(t.description)
          : (t?.description ?? ''),
    );
    _dateDisplayController = TextEditingController();
    _timeDisplayController = TextEditingController();
    _paymentMethodDisplayController = TextEditingController();
    _categoryDisplayController = TextEditingController();
    _tagDisplayController = TextEditingController();
    _graceMonthsController = TextEditingController();
    _termMonthsController = TextEditingController();
    _deferred = t != null && (t.creditLedgerGroupingKey?.isNotEmpty ?? false);
    _ignore = t?.ignore ?? false;
    _accountId = t?.accountId ?? widget.preferredAccountId;
    _cardId = t?.cardId ?? widget.preferredCardId;
    _categoryId = t?.categoryId ?? widget.preferredCategoryId;
    _tagId = t?.tagId ?? widget.preferredTagId;
    _loadingCreditGroupTotal = t?.creditLedgerGroupingKey != null &&
        t!.creditLedgerGroupingKey!.isNotEmpty;

    _loadLookups();
    _descriptionController.addListener(_onDescriptionTextChangedForSuggestions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDateTimeDisplay();
      if (widget.transaction?.creditLedgerGroupingKey != null &&
          widget.transaction!.creditLedgerGroupingKey!.isNotEmpty) {
        Future.microtask(() => _loadCreditGroupTotal());
      }
      if (widget.transaction != null) return;
      var strippedAutofillZeros = false;
      final v = _valueController.text.trim();
      if (v == '0' ||
          v == '0.00' ||
          v == '0.0' ||
          v == '-0' ||
          v == '-0.00' ||
          v == '-0.0') {
        _valueController.clear();
        strippedAutofillZeros = true;
      }
      final p = _percentageController.text.trim();
      if (p == '0' || p == '0.0') {
        _percentageController.clear();
        strippedAutofillZeros = true;
      }
      if (strippedAutofillZeros && mounted) setState(() {});
    });
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
          if (_accountId != null && !_accounts.any((a) => a.id == _accountId))
            _accountId = null;
          if (_cardId != null && !_cards.any((c) => c.id == _cardId))
            _cardId = null;
          if (_accountId != null && _cardId != null) _cardId = null;
          if (_categoryId != null &&
              !_categories.any((c) => c.id == _categoryId))
            _categoryId = null;
          if (_tagId != null && !_tags.any((t) => t.id == _tagId))
            _tagId = null;
          _loadingLookups = false;
          _syncRelationDisplays();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLookups = false);
      }
    }
  }

  Future<void> _loadCreditGroupTotal() async {
    final gid = widget.transaction?.creditLedgerGroupingKey;
    if (gid == null || gid.isEmpty || !mounted) return;
    try {
      final list = await getIt<GetTransactionsByCreditGroupIdUsecase>()(gid);
      if (!mounted) return;
      list.sort((a, b) => a.transactedAt.compareTo(b.transactedAt));
      final sum = list.fold<double>(0, (a, e) => a + e.value);
      final creditId = widget.transaction?.creditId;
      final wc = creditId != null && creditId.isNotEmpty
          ? await getIt<GetWalletCreditUsecase>()(creditId)
          : null;
      if (!mounted) return;
      setState(() {
        _valueController.text = sum.toStringAsFixed(2);
        if (widget.transaction?.creditLedgerGroupingKey != null &&
            widget.transaction!.creditLedgerGroupingKey!.isNotEmpty) {
          if (wc != null) {
            _termMonthsController.text = '${wc.termMonths}';
            _graceMonthsController.text = '${wc.graceMonths}';
          } else {
            _termMonthsController.text =
                list.isEmpty ? '' : '${list.length}';
            _graceMonthsController.text = '\u2014';
          }
        }
        _loadingCreditGroupTotal = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCreditGroupTotal = false);
      }
    }
  }

  void _syncDateTimeDisplay() {
    final locale = Localizations.localeOf(context).toString();
    _dateDisplayController.text = DateFormat.yMd(locale).format(_transactedAt);
    _timeDisplayController.text = DateFormat.Hm(locale).format(_transactedAt);
  }

  void _syncRelationDisplays() {
    String? accountName(String? id) {
      if (id == null) return null;
      for (final a in _accounts) {
        if (a.id == id) return a.name;
      }
      return null;
    }

    String? cardName(String? id) {
      if (id == null) return null;
      for (final c in _cards) {
        if (c.id == id) return c.name;
      }
      return null;
    }

    String? categoryName(String? id) {
      if (id == null) return null;
      for (final c in _categories) {
        if (c.id == id) return c.name;
      }
      return null;
    }

    String? tagName(String? id) {
      if (id == null) return null;
      for (final t in _tags) {
        if (t.id == id) return t.name;
      }
      return null;
    }

    final payName = accountName(_accountId) ?? cardName(_cardId);
    _paymentMethodDisplayController.text = payName ?? '';
    _categoryDisplayController.text = categoryName(_categoryId) ?? '';
    _tagDisplayController.text = tagName(_tagId) ?? '';
  }

  void _onDescriptionTextChangedForSuggestions() {
    if (widget.transaction != null) return;
    if (_dismissSuggestionsUntilDescriptionChange) {
      if (_descriptionController.text ==
          _descriptionSnapshotWhenSuggestionsDismissed) {
        return;
      }
      _dismissSuggestionsUntilDescriptionChange = false;
      _descriptionSnapshotWhenSuggestionsDismissed = null;
    }
    _descriptionSuggestDebounce?.cancel();
    final q = _descriptionController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _descriptionSuggestionMatches = const [];
        _descriptionSuggestLoading = false;
        _dismissSuggestionsUntilDescriptionChange = false;
        _descriptionSnapshotWhenSuggestionsDismissed = null;
      });
      return;
    }
    final local = switch (widget.cubit.state) {
      TransactionsLoaded(:final transactions) =>
        _localTransactionsMatchingDescription(transactions, q),
      _ => <TransactionEntity>[],
    };
    setState(() {
      _descriptionSuggestionMatches = local;
      _descriptionSuggestLoading = true;
    });
    _descriptionSuggestDebounce = Timer(
      const Duration(milliseconds: _descriptionSuggestDebounceMs),
      () => _loadDescriptionSuggestionsRemote(q),
    );
  }

  Future<void> _loadDescriptionSuggestionsRemote(String q) async {
    if (!mounted || widget.transaction != null) return;
    if (_descriptionController.text.trim() != q) return;
    if (_dismissSuggestionsUntilDescriptionChange &&
        _descriptionController.text ==
            _descriptionSnapshotWhenSuggestionsDismissed) {
      return;
    }
    try {
      final remote = await getIt<SearchTransactionsByDescriptionUsecase>()(
        q,
        limit: 80,
      );
      if (!mounted || widget.transaction != null) return;
      if (_descriptionController.text.trim() != q) return;
      final local = switch (widget.cubit.state) {
        TransactionsLoaded(:final transactions) =>
          _localTransactionsMatchingDescription(transactions, q),
        _ => <TransactionEntity>[],
      };
      final merged = _mergeTransactionListsByIdNewestFirst(local, remote);
      setState(() {
        _descriptionSuggestionMatches = merged;
        _descriptionSuggestLoading = false;
      });
    } catch (_) {
      if (!mounted || widget.transaction != null) return;
      if (_descriptionController.text.trim() != q) return;
      setState(() => _descriptionSuggestLoading = false);
    }
  }

  void _applyTransactionSuggestion(TransactionEntity t) {
    if (_loadingLookups) return;
    _descriptionSuggestDebounce?.cancel();
    final appliedDescription = t.description ?? '';
    setState(() {
      if (_accountId == null && _cardId == null) {
        _accountId = t.accountId;
        _cardId = t.cardId;
        if (_accountId != null && _cardId != null) {
          _cardId = null;
        }
      }
      _categoryId ??= t.categoryId;
      _tagId ??= t.tagId;
      _ignore = t.ignore;
      final valueRaw = _valueController.text.trim();
      final valueParsed = _parseTransactionAmountInput(valueRaw);
      if (valueRaw.isEmpty || valueParsed == null || valueParsed == 0) {
        _valueController.text = t.value.toStringAsFixed(2);
      }
      final pct = double.tryParse(_percentageController.text.trim());
      if (pct == null || pct == 0) {
        _percentageController.text = t.percentage.toString();
      }
      _syncRelationDisplays();
      _descriptionSuggestionMatches = const [];
      _descriptionSuggestLoading = false;
      _dismissSuggestionsUntilDescriptionChange = true;
      _descriptionSnapshotWhenSuggestionsDismissed = appliedDescription;
      _descriptionController.text = appliedDescription;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _valueFieldKey.currentState?.validate();
      _percentageFieldKey.currentState?.validate();
      _paymentMethodFieldKey.currentState?.validate();
      _categoryFieldKey.currentState?.validate();
      _tagFieldKey.currentState?.validate();
    });
  }

  Widget _descriptionSuggestionSection(BuildContext context) {
    if (widget.transaction != null) return const SizedBox.shrink();
    if (_dismissSuggestionsUntilDescriptionChange &&
        _descriptionController.text ==
            _descriptionSnapshotWhenSuggestionsDismissed) {
      return const SizedBox.shrink();
    }
    final q = _descriptionController.text.trim();
    if (q.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = widget.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_descriptionSuggestLoading && _descriptionSuggestionMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (!_descriptionSuggestLoading &&
            _descriptionSuggestionMatches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              l10n.transactionsSearchNoResults,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_descriptionSuggestLoading)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _descriptionSuggestionMatches.length,
                    itemBuilder: (context, i) {
                      final t = _descriptionSuggestionMatches[i];
                      return GroupedTxnTransactionTile(
                        cubit: widget.cubit,
                        transaction: t,
                        l10n: l10n,
                        onTap: _loadingLookups
                            ? null
                            : () => _applyTransactionSuggestion(t),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _descriptionSuggestDebounce?.cancel();
    _descriptionController.removeListener(
      _onDescriptionTextChangedForSuggestions,
    );
    _valueController.dispose();
    _percentageController.dispose();
    _descriptionController.dispose();
    _dateDisplayController.dispose();
    _timeDisplayController.dispose();
    _paymentMethodDisplayController.dispose();
    _categoryDisplayController.dispose();
    _tagDisplayController.dispose();
    _graceMonthsController.dispose();
    _termMonthsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _transactedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _transactedAt = DateTime(
        d.year,
        d.month,
        d.day,
        _transactedAt.hour,
        _transactedAt.minute,
      );
    });
    _syncDateTimeDisplay();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _transactedAt = DateTime(
        _transactedAt.year,
        _transactedAt.month,
        _transactedAt.day,
        time.hour,
        time.minute,
      );
    });
    _syncDateTimeDisplay();
  }

  Future<void> _pickPaymentMethod() async {
    if (_loadingLookups) return;
    final l10n = widget.l10n;
    final raw = await showPaymentMethodPickerSheet(
      context,
      l10n: l10n,
      sheetTitle: l10n.transactionPaymentMethod,
      getAccounts: () => _accounts,
      getCards: () => _cards,
      onListsUpdated: (a, c) {
        if (!mounted) return;
        setState(() {
          _accounts = a;
          _cards = c;
          if (_accountId != null && !_accounts.any((x) => x.id == _accountId))
            _accountId = null;
          if (_cardId != null && !_cards.any((x) => x.id == _cardId))
            _cardId = null;
          if (_accountId != null && _cardId != null) _cardId = null;
          _syncRelationDisplays();
        });
      },
      paymentSwipe: PaymentMethodPickerSwipeActions(
        editAccount: (sheetCtx, a) async => showAccountEditorBottomSheet(
          sheetCtx,
          l10n,
          account: a,
          cubit: getIt<AccountsCubit>(),
        ),
        confirmDeleteAccount: (sheetCtx, a) => _confirmDeletePickerTitle(
          sheetCtx,
          l10n,
          title: l10n.deleteAccount,
          message: l10n.confirmDeleteAccount(a.name),
        ),
        deleteAccount: (a) async {
          try {
            await getIt<DeleteAccountUsecase>()(id: a.id);
            return true;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
            }
            return false;
          }
        },
        editCard: (sheetCtx, c) async => showCardEditorBottomSheet(
          sheetCtx,
          l10n,
          card: c,
          cubit: getIt<CardsCubit>(),
        ),
        confirmDeleteCard: (sheetCtx, c) => _confirmDeletePickerTitle(
          sheetCtx,
          l10n,
          title: l10n.deleteCard,
          message: l10n.confirmDeleteCard(c.name),
        ),
        deleteCard: (c) async {
          try {
            await getIt<DeleteCardUsecase>()(id: c.id);
            return true;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
            }
            return false;
          }
        },
      ),
    );
    if (!mounted || raw == null || raw.isEmpty) return;
    setState(() {
      if (raw.startsWith(_paymentMethodPickAccountPrefix)) {
        _accountId = raw.substring(_paymentMethodPickAccountPrefix.length);
        _cardId = null;
        if (widget.transaction == null) {
          _deferred = false;
        }
      } else if (raw.startsWith(_paymentMethodPickCardPrefix)) {
        _cardId = raw.substring(_paymentMethodPickCardPrefix.length);
        _accountId = null;
        if (_deferred) {
          _ignore = true;
        }
      }
    });
    _syncRelationDisplays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paymentMethodFieldKey.currentState?.validate();
    });
  }

  Future<void> _pickCategory() async {
    if (_loadingLookups) return;
    final l10n = widget.l10n;
    final selectedId = await _showSearchableIdPickerSheet(
      context,
      l10n: l10n,
      title: l10n.transactionCategory,
      searchHint: l10n.transferAccountSearchHint,
      noResultsMessage: l10n.transferAccountSearchNoResults,
      emptyMessage: l10n.noCategories,
      allowNone: false,
      getItems: () => _categories.map((c) => (id: c.id, name: c.name)).toList(),
      addTooltip: l10n.newCategory,
      onAddPressed: (sheetContext) =>
          showCategoryEditorBottomSheet(sheetContext, l10n),
      reloadItems: () async {
        final cats = await getIt<GetCategoriesUsecase>()();
        if (mounted) {
          setState(() {
            _categories = cats;
            if (_categoryId != null && !cats.any((c) => c.id == _categoryId)) {
              _categoryId = null;
            }
            _syncRelationDisplays();
          });
        }
      },
      swipe: SearchablePickerSwipeActions(
        onEditItem: (sheetCtx, item) async {
          final cat = _categories.firstWhere((c) => c.id == item.id);
          await showCategoryEditorBottomSheet(
            sheetCtx,
            l10n,
            category: cat,
            cubit: getIt<CategoriesCubit>(),
          );
        },
        confirmDeleteItem: (sheetCtx, item) => _confirmDeletePickerTitle(
          sheetCtx,
          l10n,
          title: l10n.deleteCategory,
          message: l10n.confirmDeleteCategory(item.name),
        ),
        deleteItem: (item) async {
          try {
            await getIt<DeleteCategoryUsecase>()(id: item.id);
            return true;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
            }
            return false;
          }
        },
      ),
    );
    if (!mounted || selectedId == null || selectedId.isEmpty) return;
    setState(() {
      _categoryId = selectedId;
    });
    _syncRelationDisplays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _categoryFieldKey.currentState?.validate();
    });
  }

  Future<void> _pickTag() async {
    if (_loadingLookups) return;
    final l10n = widget.l10n;
    final selectedId = await _showSearchableIdPickerSheet(
      context,
      l10n: l10n,
      title: l10n.transactionTag,
      searchHint: l10n.transferAccountSearchHint,
      noResultsMessage: l10n.transferAccountSearchNoResults,
      emptyMessage: l10n.noTags,
      allowNone: false,
      getItems: () => _tags.map((t) => (id: t.id, name: t.name)).toList(),
      addTooltip: l10n.newTag,
      onAddPressed: (sheetContext) =>
          showTagEditorBottomSheet(sheetContext, l10n),
      reloadItems: () async {
        final tags = await getIt<GetTagsUsecase>()();
        if (mounted) {
          setState(() {
            _tags = tags;
            if (_tagId != null && !tags.any((t) => t.id == _tagId)) {
              _tagId = null;
            }
            _syncRelationDisplays();
          });
        }
      },
      swipe: SearchablePickerSwipeActions(
        onEditItem: (sheetCtx, item) async {
          final tag = _tags.firstWhere((t) => t.id == item.id);
          await showTagEditorBottomSheet(
            sheetCtx,
            l10n,
            tag: tag,
            cubit: getIt<TagsCubit>(),
          );
        },
        confirmDeleteItem: (sheetCtx, item) => _confirmDeletePickerTitle(
          sheetCtx,
          l10n,
          title: l10n.deleteTag,
          message: l10n.confirmDeleteTag(item.name),
        ),
        deleteItem: (item) async {
          try {
            await getIt<DeleteTagUsecase>()(id: item.id);
            return true;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
            }
            return false;
          }
        },
      ),
    );
    if (!mounted || selectedId == null || selectedId.isEmpty) return;
    setState(() {
      _tagId = selectedId;
    });
    _syncRelationDisplays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tagFieldKey.currentState?.validate();
    });
  }

  Future<void> _submit() async {
    if (_loadingLookups) return;
    if (!_formKey.currentState!.validate()) return;
    final value = _parseTransactionAmountInput(_valueController.text);
    final pct = double.tryParse(_percentageController.text.trim());
    if (value == null || value == 0 || pct == null || pct < 0 || pct > 100)
      return;
    final desc = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    setState(() => _loading = true);
    try {
      if (widget.transaction == null) {
        if (_deferred && _cardId != null) {
          final grace =
              int.tryParse(_graceMonthsController.text.trim()) ?? 0;
          final term = int.parse(_termMonthsController.text.trim());
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
            deferredCredit: true,
            deferredGraceMonths: grace.clamp(0, 1200),
            deferredTermMonths: term,
          );
        } else {
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
        }
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
          transferGroupId: widget.transaction!.transferGroupId,
          creditId: widget.transaction!.creditId,
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
    final theme = Theme.of(context);

    return BottomSheetPinnedTitleScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      title: isEdit ? l10n.editTransaction : l10n.newTransaction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        enableInteractiveSelection: false,
                        showCursor: false,
                        controller: _dateDisplayController,
                        decoration: InputDecoration(
                          labelText: l10n.transferDateLabel,
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                          ),
                        ),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        enableInteractiveSelection: false,
                        showCursor: false,
                        controller: _timeDisplayController,
                        decoration: InputDecoration(
                          labelText: l10n.transferTimeLabel,
                          suffixIcon: const Icon(Icons.schedule, size: 20),
                        ),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l10n.accountDescription,
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                ),
                _descriptionSuggestionSection(context),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: (_loadingCreditGroupTotal &&
                              isEdit &&
                              _isCreditGroupEdit)
                          ? InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.transactionAmount,
                                helperText:
                                    l10n.transactionAmountCreditGroupHint,
                              ),
                              child: const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : TextFormField(
                              key: _valueFieldKey,
                              controller: _valueController,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: isEdit ? null : const <String>[],
                              decoration: InputDecoration(
                                labelText: l10n.transactionAmount,
                                helperText:
                                    (isEdit && _isCreditGroupEdit)
                                        ? l10n.transactionAmountCreditGroupHint
                                        : null,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              inputFormatters:
                                  _transactionAmountInputFormatters,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return l10n.fieldRequired;
                                }
                                final amt =
                                    _parseTransactionAmountInput(v);
                                if (amt == null) {
                                  return l10n.transactionAmountInvalidNumber;
                                }
                                if (amt == 0) {
                                  return l10n.transactionAmountMustBeNonZero;
                                }
                                return null;
                              },
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _loadingLookups
                          ? InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.transactionPaymentMethod,
                              ),
                              child: const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : TextFormField(
                              key: _paymentMethodFieldKey,
                              readOnly: true,
                              enableInteractiveSelection: false,
                              showCursor: false,
                              controller: _paymentMethodDisplayController,
                              decoration: InputDecoration(
                                labelText: l10n.transactionPaymentMethod,
                                suffixIcon: const Icon(
                                  Icons.expand_more_rounded,
                                  size: 22,
                                ),
                              ),
                              validator: (_) {
                                if (_accountId == null && _cardId == null) {
                                  return l10n.fieldRequired;
                                }
                                return null;
                              },
                              onTap: _pickPaymentMethod,
                            ),
                    ),
                  ],
                ),
                if (!_loadingLookups &&
                    _cardId != null &&
                    (widget.transaction == null || _isCreditGroupEdit)) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: _deferred,
                    onChanged: widget.transaction != null || _loadingLookups
                        ? null
                        : (checked) {
                            setState(() {
                              _deferred = checked ?? false;
                              if (!_deferred) {
                                _graceMonthsController.clear();
                                _termMonthsController.clear();
                              } else if (_cardId != null) {
                                _ignore = true;
                              }
                            });
                          },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.transactionDeferred),
                  ),
                  if (_deferred) ...[
                    const SizedBox(height: 4),
                    if (_isCreditGroupEdit && _loadingCreditGroupTotal)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.transactionGraceMonths,
                              ),
                              child: const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.transactionMesesPlazo,
                              ),
                              child: const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _graceMonthsController,
                              readOnly: _isCreditGroupEdit,
                              keyboardType: TextInputType.number,
                              inputFormatters: _isCreditGroupEdit
                                  ? const <TextInputFormatter>[]
                                  : <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.transactionGraceMonths,
                                helperText:
                                    _isCreditGroupEdit &&
                                            !(widget.transaction?.creditId
                                                    ?.isNotEmpty ??
                                                false)
                                        ? l10n.creditEditGraceNotApplicable
                                        : null,
                              ),
                              validator: (v) {
                                if (widget.transaction != null ||
                                    !_deferred ||
                                    _loadingLookups) {
                                  return null;
                                }
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return null;
                                final n = int.tryParse(t);
                                if (n == null || n < 0) {
                                  return l10n.transactionGraceMonthsInvalid;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _termMonthsController,
                              readOnly: _isCreditGroupEdit,
                              keyboardType: TextInputType.number,
                              inputFormatters: _isCreditGroupEdit
                                  ? const <TextInputFormatter>[]
                                  : <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.transactionMesesPlazo,
                              ),
                              validator: (v) {
                                if (widget.transaction != null ||
                                    !_deferred ||
                                    _loadingLookups) {
                                  return null;
                                }
                                if (v == null || v.trim().isEmpty) {
                                  return l10n.fieldRequired;
                                }
                                final n = int.tryParse(v.trim());
                                if (n == null || n < 2) {
                                  return l10n.transactionTermMonthsInvalid;
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _loadingLookups
                          ? InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.transactionCategory,
                              ),
                              child: const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : TextFormField(
                              key: _categoryFieldKey,
                              readOnly: true,
                              enableInteractiveSelection: false,
                              showCursor: false,
                              controller: _categoryDisplayController,
                              decoration: InputDecoration(
                                labelText: l10n.transactionCategory,
                                suffixIcon: const Icon(
                                  Icons.expand_more_rounded,
                                  size: 22,
                                ),
                              ),
                              validator: (_) {
                                if (_categoryId == null)
                                  return l10n.fieldRequired;
                                return null;
                              },
                              onTap: _pickCategory,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _loadingLookups
                          ? InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.transactionTag,
                              ),
                              child: const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : TextFormField(
                              key: _tagFieldKey,
                              readOnly: true,
                              enableInteractiveSelection: false,
                              showCursor: false,
                              controller: _tagDisplayController,
                              decoration: InputDecoration(
                                labelText: l10n.transactionTag,
                                suffixIcon: const Icon(
                                  Icons.expand_more_rounded,
                                  size: 22,
                                ),
                              ),
                              validator: (_) {
                                if (_tagId == null) return l10n.fieldRequired;
                                return null;
                              },
                              onTap: _pickTag,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: _percentageFieldKey,
                        controller: _percentageController,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: isEdit ? null : const <String>[],
                        decoration: InputDecoration(
                          labelText: l10n.transactionPercentage,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return l10n.fieldRequired;
                          final p = double.tryParse(v.trim());
                          if (p == null) return l10n.fieldRequired;
                          if (p < 0 || p > 100)
                            return l10n.transactionPercentageInvalidRange;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.transactionIgnore,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          Switch(
                            value: _ignoreSwitchShowsOn,
                            onChanged: _ignoreSwitchLocked
                                    ? null
                                    : (v) => setState(() => _ignore = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading || _loadingLookups ? null : _submit,
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}
