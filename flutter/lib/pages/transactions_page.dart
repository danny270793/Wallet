import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../features/transactions/domain/usecases/search_transactions_by_description_usecase.dart';
import '../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../features/transactions/presentation/cubit/transactions_state.dart';
import '../widgets/account_editor_sheet.dart';
import '../widgets/card_editor_sheet.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/tag_editor_sheet.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/transaction_delete_dialogs.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/transaction_month_totals.dart';
import '../widgets/transactions_month_scope.dart';
import '../widgets/transactions_totals_bar.dart';

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
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final filtered = _filter(newValue.text, allowNegative: allowNegative);
    if (filtered == newValue.text) return newValue;
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final mapped = _filter(newValue.text.substring(0, end), allowNegative: allowNegative).length;
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

final class _TransferPairMarker extends _GroupedTxRow {
  const _TransferPairMarker({required this.source, required this.target});
  final TransactionEntity source;
  final TransactionEntity target;
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
    final dayList = byDay[d]!;
    final byGroup = <String, List<TransactionEntity>>{};
    for (final t in dayList) {
      final g = t.transactionGroupId;
      if (g != null && g.isNotEmpty) {
        byGroup.putIfAbsent(g, () => []).add(t);
      }
    }
    final usedIds = <String>{};
    for (final t in dayList) {
      final gid = t.transactionGroupId;
      if (gid == null || gid.isEmpty) {
        entries.add(_TxMarker(t));
        continue;
      }
      if (usedIds.contains(t.id)) continue;
      final peers = byGroup[gid]!;
      if (peers.length == 2) {
        TransactionEntity? src;
        TransactionEntity? tgt;
        for (final p in peers) {
          if (p.value < 0) src = p;
          if (p.value > 0) tgt = p;
        }
        if (src != null &&
            tgt != null &&
            (src.value.abs() - tgt.value.abs()).abs() < 0.0001) {
          entries.add(_TransferPairMarker(source: src, target: tgt));
          usedIds.add(src.id);
          usedIds.add(tgt.id);
          continue;
        }
      }
      entries.add(_TxMarker(t));
    }
  }
  return entries;
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

    final weightedAll = transactionMonthTotalsBreakdown(
      txs,
      include: (_) => true,
      amount: weighted,
    );
    final weightedExcludingIgnored = transactionMonthTotalsBreakdown(
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
  State<_AccountTransferBottomSheet> createState() => _AccountTransferBottomSheetState();
}

class _AccountTransferBottomSheetState extends State<_AccountTransferBottomSheet> {
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
      _valueController = TextEditingController(text: et.value.abs().toStringAsFixed(2));
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
    if (e.accountId != null) return '$_paymentMethodPickAccountPrefix${e.accountId}';
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
      _transactedAt = DateTime(d.year, d.month, d.day, _transactedAt.hour, _transactedAt.minute);
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
      sheetTitle: source ? l10n.transferSourceAccount : l10n.transferTargetAccount,
      accounts: _accounts,
      cards: _cards,
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditingPair ? l10n.editTransferTitle : l10n.transferSheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
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
                        child: Text(l10n.transferNeedTwoAccounts, textAlign: TextAlign.center),
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
                                suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
                              ),
                              validator: (_) => _sourcePickKey == null ? l10n.fieldRequired : null,
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
                                suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
                              ),
                              validator: (_) => _targetPickKey == null ? l10n.fieldRequired : null,
                              onTap: () => _pickTransferLeg(source: false),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _valueController,
                      decoration: InputDecoration(labelText: l10n.transactionAmount),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
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
                          _submitting || _loadingPaymentMethods || _paymentMethodCount < 2 ? null : _submit,
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
            ],
          ),
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
    showDragHandle: true,
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
    if (widget.accountNameFilter != null && widget.accountNameFilter!.isNotEmpty) {
      title = '${widget.accountNameFilter!} · ${l10n.transactions}';
    } else if (widget.cardNameFilter != null && widget.cardNameFilter!.isNotEmpty) {
      title = '${widget.cardNameFilter!} · ${l10n.transactions}';
    } else if (widget.categoryNameFilter != null && widget.categoryNameFilter!.isNotEmpty) {
      title = '${widget.categoryNameFilter!} · ${l10n.transactions}';
    } else if (widget.tagNameFilter != null && widget.tagNameFilter!.isNotEmpty) {
      title = '${widget.tagNameFilter!} · ${l10n.transactions}';
    } else {
      title = l10n.transactions;
    }

    final isScoped = (widget.accountIdFilter != null && widget.accountIdFilter!.isNotEmpty) ||
        (widget.cardIdFilter != null && widget.cardIdFilter!.isNotEmpty) ||
        (widget.categoryIdFilter != null && widget.categoryIdFilter!.isNotEmpty) ||
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
              appBarBottom: TransactionsMonthAppBarBottom(notifier: monthNotifier),
              appBarActionsBeforeSettings: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.transactionsSearchTooltip,
                  onPressed: () async {
                    final tx = await showSearch<TransactionEntity?>(
                      context: context,
                      delegate: _TransactionSearchDelegate(
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
                onTransfer: () => showAccountTransferCreateBottomSheet(context, l10n: l10n),
              ),
              bottomNavigationBar: showTotalsBar
                  ? _TransactionsTotalsBarHost(
                      l10n: l10n,
                      transactions: filtered,
                    )
                  : null,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  _body(
                    context,
                    state,
                    l10n,
                    visibleMonth,
                    monthNotifier,
                    filtered,
                  ),
                  if (_fabMenuOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _fabMenuOpen = false),
                        child: const SizedBox.expand(),
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
    if (widget.categoryIdFilter != null && widget.categoryIdFilter!.isNotEmpty) {
      list = list.where((t) => t.categoryId == widget.categoryIdFilter).toList();
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
            _TransferPairMarker(:final source, :final target) =>
              _TransferPairTile(source: source, target: target, l10n: l10n),
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

void showTransactionEditorBottomSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required TransactionsCubit cubit,
  TransactionEntity? transaction,
  String? preferredAccountId,
  String? preferredCardId,
  String? preferredCategoryId,
  String? preferredTagId,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
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
    showDragHandle: true,
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
    required this.l10n,
    required this.search,
    required this.localTransactions,
  });

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

class _TransactionSearchBody extends StatefulWidget {
  const _TransactionSearchBody({
    required this.l10n,
    required this.query,
    required this.localTransactions,
    required this.search,
    required this.onSelect,
  });

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

    final local = _localTransactionsMatchingDescription(widget.localTransactions, q);

    if (_remoteFuture == null) {
      if (local.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return _transactionSearchResultsList(
        context,
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
        final staleRemote = _remoteForQuery != null && _remoteForQuery != forQuery;

        if (snapshot.connectionState == ConnectionState.waiting && !staleRemote) {
          if (local.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return _transactionSearchResultsList(
            context,
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
  required AppLocalizations l10n,
  required List<TransactionEntity> list,
  required void Function(TransactionEntity t) onSelect,
  required Widget? top,
}) {
  if (list.isEmpty) {
    return Center(child: Text(l10n.transactionsSearchNoResults));
  }
  final locale = Localizations.localeOf(context).toString();
  final dateFmt = DateFormat.yMMMd(locale).add_Hm();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ?top,
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final t = list[i];
            final desc = t.description?.isNotEmpty == true ? t.description! : l10n.none;
            final weighted = t.value * t.percentage / 100.0;
            final amt = l10n.transactionAmountValue(weighted.toStringAsFixed(2));
            final pay = t.accountName ?? t.cardName ?? l10n.none;
            final sub = '${dateFmt.format(t.transactedAt.toLocal())} · $pay';
            return ListTile(
              title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text(
                amt,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              onTap: () => onSelect(t),
            );
          },
        ),
      ),
    ],
  );
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

class _TransferPairTile extends StatelessWidget {
  const _TransferPairTile({
    required this.source,
    required this.target,
    required this.l10n,
  });

  final TransactionEntity source;
  final TransactionEntity target;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final timeLocal = source.transactedAt.toLocal();
    final timeStr = DateFormat.Hm(locale.toString()).format(timeLocal);
    final amountStr = l10n.transactionAmountValue(target.value.toStringAsFixed(2));
    final gid = source.transactionGroupId;
    String payLabel(TransactionEntity t) => t.accountName ?? t.cardName ?? '—';

    final title = Text(
      payLabel(target),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    );

    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          payLabel(source),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          timeStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    final trailing = Text(
      amountStr,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    void openEdit() {
      showAccountTransferEditorBottomSheet(
        context,
        l10n: l10n,
        editingSource: source,
        editingTarget: target,
      );
    }

    Widget tile = SwipeableListTile(
      itemKey: gid != null && gid.isNotEmpty ? 'pair_$gid' : '${source.id}|${target.id}',
      leading: Icon(
        Icons.swap_vert_rounded,
        size: 26,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onEdit: openEdit,
      confirmDelete: () => confirmDeleteTransferPairDialog(context, l10n),
      onDelete: () => cubit.deleteMany([source.id, target.id]),
    );

    if (source.ignore || target.ignore) {
      tile = Opacity(opacity: 0.52, child: tile);
      tile = Tooltip(message: l10n.transactionIgnoredBadge, child: tile);
    }
    return tile;
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
      showTransactionEditorBottomSheet(
        context,
        l10n: l10n,
        cubit: cubit,
        transaction: transaction,
      );
    }

    Widget tile = SwipeableListTile(
      itemKey: transaction.id,
      title: titleSection(),
      trailing: trailingPrices,
      onEdit: openEdit,
      confirmDelete: () => confirmDeleteTransactionDialog(context, l10n),
      onDelete: () => cubit.delete(id: transaction.id),
    );

    if (transaction.ignore) {
      // Whole-row muted look; explicit text styles bypass ListTile disabled tints.
      tile = Opacity(opacity: 0.52, child: tile);
      tile = Tooltip(message: l10n.transactionIgnoredBadge, child: tile);
    }
    return tile;
  }

  /// Account, card, category, tag labels from embedded FK names (aligned with datasource order).
  static List<String> _relationNames(TransactionEntity t) => [
        if (t.accountName?.isNotEmpty == true) t.accountName!,
        if (t.cardName?.isNotEmpty == true) t.cardName!,
        if (t.categoryName?.isNotEmpty == true) t.categoryName!,
        if (t.tagName?.isNotEmpty == true) t.tagName!,
      ];

}

/// Picks an id from a searchable list. Returns `null` if dismissed, `''` if [allowNone] and user cleared.
Future<String?> _showSearchableIdPickerSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required String title,
  required String searchHint,
  required String noResultsMessage,
  required String emptyMessage,
  required bool allowNone,
  required List<({String id, String name})> initialItems,
  Future<void> Function(BuildContext sheetContext)? onAddPressed,
  String? addTooltip,
  Future<List<({String id, String name})>> Function()? reloadItems,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.55;
      var items = List<({String id, String name})>.from(initialItems);
      var showSearchField = false;
      var searchFilter = '';

      List<({String id, String name})> visible() {
        final q = searchFilter.trim().toLowerCase();
        if (q.isEmpty) return items;
        return items.where((e) => e.name.toLowerCase().contains(q)).toList();
      }

      return StatefulBuilder(
        builder: (context, setPickerState) {
          final list = visible();

          Future<void> refreshItems() async {
            final r = reloadItems;
            if (r == null) return;
            items = await r();
            setPickerState(() {});
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.transferAccountSearch,
                        icon: Icon(showSearchField ? Icons.search_off_outlined : Icons.search),
                        onPressed: () {
                          setPickerState(() {
                            showSearchField = !showSearchField;
                            if (!showSearchField) searchFilter = '';
                          });
                        },
                      ),
                      if (onAddPressed != null)
                        IconButton(
                          tooltip: addTooltip ?? '',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () async {
                            await onAddPressed(sheetContext);
                            await refreshItems();
                          },
                        ),
                    ],
                  ),
                ),
                if (allowNone)
                  ListTile(
                    title: Text(l10n.none),
                    leading: const Icon(Icons.clear),
                    onTap: () => Navigator.of(sheetContext).pop(''),
                  ),
                if (showSearchField)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: searchHint,
                        prefixIcon: const Icon(Icons.search, size: 22),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setPickerState(() => searchFilter = v),
                    ),
                  ),
                SizedBox(
                  height: maxH,
                  child: items.isEmpty
                      ? Center(child: Text(emptyMessage))
                      : list.isEmpty
                          ? Center(child: Text(noResultsMessage))
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final e = list[index];
                                return ListTile(
                                  title: Text(e.name),
                                  onTap: () => Navigator.of(sheetContext).pop(e.id),
                                );
                              },
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

/// Returns `a:id` or `c:id`. [onListsUpdated] should update parent state (e.g. [setState]).
Future<String?> showPaymentMethodPickerSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required String sheetTitle,
  required List<AccountEntity> accounts,
  required List<CardEntity> cards,
  required void Function(List<AccountEntity> accounts, List<CardEntity> cards) onListsUpdated,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.55;
      var pickerAccounts = List<AccountEntity>.from(accounts);
      var pickerCards = List<CardEntity>.from(cards);
      var showSearchField = false;
      var searchFilter = '';

      return StatefulBuilder(
        builder: (context, setPickerState) {
          Future<void> refreshPicker() async {
            final freshAccounts = await getIt<GetAccountsUsecase>()();
            final freshCards = await getIt<GetCardsUsecase>()();
            pickerAccounts = freshAccounts;
            pickerCards = freshCards;
            setPickerState(() {});
            onListsUpdated(freshAccounts, freshCards);
          }

          List<AccountEntity> visibleAccounts() {
            final q = searchFilter.trim().toLowerCase();
            if (q.isEmpty) return pickerAccounts;
            return pickerAccounts.where((a) => a.name.toLowerCase().contains(q)).toList();
          }

          List<CardEntity> visibleCards() {
            final q = searchFilter.trim().toLowerCase();
            if (q.isEmpty) return pickerCards;
            return pickerCards.where((c) => c.name.toLowerCase().contains(q)).toList();
          }

          final vAccounts = visibleAccounts();
          final vCards = visibleCards();
          final hasAny = pickerAccounts.isNotEmpty || pickerCards.isNotEmpty;
          final filteredEmpty = vAccounts.isEmpty && vCards.isEmpty;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          sheetTitle,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.transferAccountSearch,
                        icon: Icon(showSearchField ? Icons.search_off_outlined : Icons.search),
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
                          final choice = await showModalBottomSheet<_PaymentMethodCreateChoice>(
                            context: sheetContext,
                            showDragHandle: true,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                                    child: Text(
                                      l10n.paymentMethodAddChoiceTitle,
                                      style: Theme.of(ctx).textTheme.titleMedium,
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.account_balance_wallet_outlined),
                                    title: Text(l10n.newAccount),
                                    onTap: () => Navigator.pop(ctx, _PaymentMethodCreateChoice.account),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.credit_card_outlined),
                                    title: Text(l10n.newCard),
                                    onTap: () => Navigator.pop(ctx, _PaymentMethodCreateChoice.card),
                                  ),
                                  SizedBox(height: MediaQuery.paddingOf(ctx).bottom),
                                ],
                              ),
                            ),
                          );
                          if (!sheetContext.mounted) return;
                          switch (choice) {
                            case _PaymentMethodCreateChoice.account:
                              await showAccountEditorBottomSheet(sheetContext, l10n);
                            case _PaymentMethodCreateChoice.card:
                              await showCardEditorBottomSheet(sheetContext, l10n);
                            case null:
                              return;
                          }
                          await refreshPicker();
                        },
                      ),
                    ],
                  ),
                ),
                if (showSearchField)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: l10n.transferAccountSearchHint,
                        prefixIcon: const Icon(Icons.search, size: 22),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setPickerState(() => searchFilter = v),
                    ),
                  ),
                SizedBox(
                  height: maxH,
                  child: !hasAny
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '${l10n.noAccounts}\n${l10n.noCards}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : filteredEmpty
                          ? Center(child: Text(l10n.transactionPaymentMethodSearchNoResults))
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                if (vCards.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                    child: Text(
                                      l10n.cards,
                                      style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                            color: Theme.of(sheetContext).colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                  ...vCards.map(
                                    (c) => ListTile(
                                      leading: const Icon(Icons.credit_card_outlined),
                                      title: Text(c.name),
                                      onTap: () => Navigator.of(sheetContext).pop(
                                        '$_paymentMethodPickCardPrefix${c.id}',
                                      ),
                                    ),
                                  ),
                                ],
                                if (vAccounts.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                    child: Text(
                                      l10n.accounts,
                                      style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                            color: Theme.of(sheetContext).colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                  ...vAccounts.map(
                                    (a) => ListTile(
                                      leading: const Icon(Icons.account_balance_wallet_outlined),
                                      title: Text(a.name),
                                      onTap: () => Navigator.of(sheetContext).pop(
                                        '$_paymentMethodPickAccountPrefix${a.id}',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
    _dateDisplayController = TextEditingController();
    _timeDisplayController = TextEditingController();
    _paymentMethodDisplayController = TextEditingController();
    _categoryDisplayController = TextEditingController();
    _tagDisplayController = TextEditingController();
    _ignore = t?.ignore ?? false;
    _accountId = t?.accountId ?? widget.preferredAccountId;
    _cardId = t?.cardId ?? widget.preferredCardId;
    _categoryId = t?.categoryId ?? widget.preferredCategoryId;
    _tagId = t?.tagId ?? widget.preferredTagId;
    _loadLookups();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDateTimeDisplay();
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
          if (_accountId != null && !_accounts.any((a) => a.id == _accountId)) _accountId = null;
          if (_cardId != null && !_cards.any((c) => c.id == _cardId)) _cardId = null;
          if (_accountId != null && _cardId != null) _cardId = null;
          if (_categoryId != null && !_categories.any((c) => c.id == _categoryId)) _categoryId = null;
          if (_tagId != null && !_tags.any((t) => t.id == _tagId)) _tagId = null;
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

  @override
  void dispose() {
    _valueController.dispose();
    _percentageController.dispose();
    _descriptionController.dispose();
    _dateDisplayController.dispose();
    _timeDisplayController.dispose();
    _paymentMethodDisplayController.dispose();
    _categoryDisplayController.dispose();
    _tagDisplayController.dispose();
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
      _transactedAt = DateTime(d.year, d.month, d.day, _transactedAt.hour, _transactedAt.minute);
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
      accounts: _accounts,
      cards: _cards,
      onListsUpdated: (a, c) {
        if (!mounted) return;
        setState(() {
          _accounts = a;
          _cards = c;
          if (_accountId != null && !_accounts.any((x) => x.id == _accountId)) _accountId = null;
          if (_cardId != null && !_cards.any((x) => x.id == _cardId)) _cardId = null;
          if (_accountId != null && _cardId != null) _cardId = null;
          _syncRelationDisplays();
        });
      },
    );
    if (!mounted || raw == null || raw.isEmpty) return;
    setState(() {
      if (raw.startsWith(_paymentMethodPickAccountPrefix)) {
        _accountId = raw.substring(_paymentMethodPickAccountPrefix.length);
        _cardId = null;
      } else if (raw.startsWith(_paymentMethodPickCardPrefix)) {
        _cardId = raw.substring(_paymentMethodPickCardPrefix.length);
        _accountId = null;
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
      initialItems: _categories.map((c) => (id: c.id, name: c.name)).toList(),
      addTooltip: l10n.newCategory,
      onAddPressed: (sheetContext) => showCategoryEditorBottomSheet(sheetContext, l10n),
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
        return cats.map((c) => (id: c.id, name: c.name)).toList();
      },
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
      initialItems: _tags.map((t) => (id: t.id, name: t.name)).toList(),
      addTooltip: l10n.newTag,
      onAddPressed: (sheetContext) => showTagEditorBottomSheet(sheetContext, l10n),
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
        return tags.map((t) => (id: t.id, name: t.name)).toList();
      },
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
    if (value == null || value == 0 || pct == null || pct < 0 || pct > 100) return;
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
          transactionGroupId: widget.transaction!.transactionGroupId,
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: bottomInset + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEdit ? l10n.editTransaction : l10n.newTransaction,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
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
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
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
                  decoration: InputDecoration(labelText: l10n.accountDescription),
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valueController,
                        decoration: InputDecoration(labelText: l10n.transactionAmount),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        inputFormatters: _transactionAmountInputFormatters,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                          final amt = _parseTransactionAmountInput(v);
                          if (amt == null) return l10n.transactionAmountInvalidNumber;
                          if (amt == 0) return l10n.transactionAmountMustBeNonZero;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _loadingLookups
                          ? InputDecorator(
                              decoration: InputDecoration(labelText: l10n.transactionPaymentMethod),
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
                            )
                          : TextFormField(
                              key: _paymentMethodFieldKey,
                              readOnly: true,
                              enableInteractiveSelection: false,
                              showCursor: false,
                              controller: _paymentMethodDisplayController,
                              decoration: InputDecoration(
                                labelText: l10n.transactionPaymentMethod,
                                suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
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
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _loadingLookups
                          ? InputDecorator(
                              decoration: InputDecoration(labelText: l10n.transactionCategory),
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
                            )
                          : TextFormField(
                              key: _categoryFieldKey,
                              readOnly: true,
                              enableInteractiveSelection: false,
                              showCursor: false,
                              controller: _categoryDisplayController,
                              decoration: InputDecoration(
                                labelText: l10n.transactionCategory,
                                suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
                              ),
                              validator: (_) {
                                if (_categoryId == null) return l10n.fieldRequired;
                                return null;
                              },
                              onTap: _pickCategory,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _loadingLookups
                          ? InputDecorator(
                              decoration: InputDecoration(labelText: l10n.transactionTag),
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
                            )
                          : TextFormField(
                              key: _tagFieldKey,
                              readOnly: true,
                              enableInteractiveSelection: false,
                              showCursor: false,
                              controller: _tagDisplayController,
                              decoration: InputDecoration(
                                labelText: l10n.transactionTag,
                                suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
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
                        controller: _percentageController,
                        decoration: InputDecoration(labelText: l10n.transactionPercentage),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                          final p = double.tryParse(v.trim());
                          if (p == null) return l10n.fieldRequired;
                          if (p < 0 || p > 100) return l10n.transactionPercentageInvalidRange;
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
                            value: _ignore,
                            onChanged: (v) => setState(() => _ignore = v),
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
