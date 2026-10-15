import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/credit_ledger_grouping.dart';
import '../core/decimal_amount_input.dart';
import '../core/di/injection.dart';
import 'bottom_sheet_pinned_title.dart';
import 'card_type_icon.dart';
import 'day_of_month_picker_dialog.dart';
import '../features/cards/domain/entities/card_entity.dart';
import '../features/cards/domain/entities/card_type.dart';
import '../features/cards/presentation/cubit/cards_cubit.dart';
import '../features/transactions/domain/usecases/list_transactions_having_credit_group_usecase.dart';

/// Same card create/edit form as the Cards screen FAB / row edit.
Future<void> showCardEditorBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  CardEntity? card,
  double? postedBalance,
  double? deferredBalance,
  CardsCubit? cubit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) {
      final child = CardEditorSheet(
        l10n: l10n,
        card: card,
        postedBalance: postedBalance,
        deferredBalance: deferredBalance,
      );
      return cubit != null
          ? BlocProvider.value(value: cubit, child: child)
          : BlocProvider(create: (_) => getIt<CardsCubit>(), child: child);
    },
  );
}

class CardEditorSheet extends StatefulWidget {
  const CardEditorSheet({
    super.key,
    required this.l10n,
    this.card,
    this.postedBalance,
    this.deferredBalance,
  });

  final AppLocalizations l10n;
  final CardEntity? card;

  /// Regular purchases plus installments already posted (first amount on /cards).
  /// Used as the Balance field and as the baseline for an Adjustment movement.
  final double? postedBalance;

  /// Installments still to come (second amount on /cards). Shown read-only.
  final double? deferredBalance;

  @override
  State<CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<CardEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cutDayController;
  late final TextEditingController _payDayController;
  late final TextEditingController _interestRateController;
  TextEditingController? _balanceController;
  TextEditingController? _deferredBalanceController;
  TextEditingController? _totalBalanceController;
  CardType? _type;
  double? _postedBalance;
  double _deferredBalance = 0;
  bool _loading = false;

  static String _dayText(int day) => day.toString();

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _nameController = TextEditingController(text: card?.name ?? '');
    _type = card?.type;
    _cutDayController = TextEditingController(
      text: _dayText(card?.cutDay ?? 24),
    );
    _payDayController = TextEditingController(
      text: _dayText(card?.payDay ?? 24),
    );
    _interestRateController = TextEditingController(
      text: card?.nominalInterestRate?.toString() ?? '',
    );
    if (card != null) {
      _postedBalance = widget.postedBalance ?? card.balance;
      _deferredBalance = widget.deferredBalance ?? 0;
      _balanceController = TextEditingController(
        text: _postedBalance!.toStringAsFixed(2),
      )..addListener(_updateTotalBalance);
      _deferredBalanceController = TextEditingController(
        text: _deferredBalance.toStringAsFixed(2),
      );
      _totalBalanceController = TextEditingController();
      _updateTotalBalance();
      if (widget.postedBalance == null || widget.deferredBalance == null) {
        _resolvePostedBalance(card);
      }
    }
  }

  Future<void> _resolvePostedBalance(CardEntity card) async {
    try {
      final bundle = await getIt<ListTransactionsHavingCreditGroupUsecase>()();
      final credits = creditTotalsByCard(bundle.value)[card.id];
      final posted = cardPostedBalance(card.balance, credits);
      if (!mounted || _balanceController == null) return;
      final typed = _balanceController!.text.trim();
      final stillInitial =
          typed == card.balance.toStringAsFixed(2) ||
          typed == (_postedBalance?.toStringAsFixed(2) ?? '');
      setState(() {
        _postedBalance = posted;
        _deferredBalance = credits?.pending ?? 0;
        _deferredBalanceController!.text = _deferredBalance.toStringAsFixed(2);
        if (stillInitial) {
          _balanceController!.text = posted.toStringAsFixed(2);
        }
        _updateTotalBalance();
      });
    } catch (_) {}
  }

  /// Total = revolving (as typed) + deferred; falls back to the stored revolving
  /// balance while the field does not parse.
  void _updateTotalBalance() {
    final total = _totalBalanceController;
    if (total == null) return;
    final revolving =
        parseDecimalAmountInput(_balanceController?.text) ??
        _postedBalance ??
        0;
    total.text = (revolving + _deferredBalance).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cutDayController.dispose();
    _payDayController.dispose();
    _interestRateController.dispose();
    _balanceController?.dispose();
    _deferredBalanceController?.dispose();
    _totalBalanceController?.dispose();
    super.dispose();
  }

  Future<void> _pickDay(TextEditingController controller, String title) async {
    final day = await showDayOfMonthPicker(
      context,
      title: title,
      selected: int.tryParse(controller.text.trim()),
    );
    if (day == null || !mounted) return;
    setState(() => controller.text = '$day');
  }

  String? _validateBillingDay(String? v, AppLocalizations l10n) {
    if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
    final n = int.tryParse(v.trim());
    if (n == null || n < 1 || n > 30) return l10n.cardDayInvalidRange;
    return null;
  }

  String? _validateInterestRate(String? v, AppLocalizations l10n) {
    if (v == null || v.trim().isEmpty) return null;
    final n = parseDecimalAmountInput(v);
    if (n == null || n < 0) return l10n.cardNominalInterestRateInvalid;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final cubit = context.read<CardsCubit>();
    final name = _nameController.text.trim();
    final type = _type!;
    final cutDay = int.parse(_cutDayController.text.trim());
    final payDay = int.parse(_payDayController.text.trim());
    final nominalInterestRate = parseDecimalAmountInput(
      _interestRateController.text,
    );
    try {
      if (widget.card == null) {
        await cubit.create(
          name: name,
          type: type,
          nominalInterestRate: nominalInterestRate,
          cutDay: cutDay,
          payDay: payDay,
        );
      } else {
        final targetBalance = double.tryParse(_balanceController!.text.trim());
        if (targetBalance == null) return;
        await cubit.update(
          id: widget.card!.id,
          name: name,
          type: type,
          nominalInterestRate: nominalInterestRate,
          cutDay: cutDay,
          payDay: payDay,
          previousBalance: _postedBalance ?? widget.card!.balance,
          targetBalance: targetBalance,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _formFields(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.accountName),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CardType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: l10n.cardType),
            items: [
              for (final t in CardType.values)
                DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      CardTypeIcon(type: t),
                      const SizedBox(width: 12),
                      Text(cardTypeLabel(t, l10n)),
                    ],
                  ),
                ),
            ],
            onChanged: (t) => setState(() => _type = t),
            validator: (t) => t == null ? l10n.fieldRequired : null,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cutDayController,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  decoration: InputDecoration(
                    labelText: l10n.cardCutDay,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (v) => _validateBillingDay(v, l10n),
                  onTap: () => _pickDay(_cutDayController, l10n.cardCutDay),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _payDayController,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  decoration: InputDecoration(
                    labelText: l10n.cardPayDay,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (v) => _validateBillingDay(v, l10n),
                  onTap: () => _pickDay(_payDayController, l10n.cardPayDay),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_balanceController != null) ...[
            TextFormField(
              controller: _balanceController,
              decoration: InputDecoration(labelText: l10n.cardRevolvingBalance),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                if (double.tryParse(v.trim()) == null) {
                  return l10n.fieldRequired;
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _deferredBalanceController,
              decoration: InputDecoration(labelText: l10n.cardDeferredBalance),
              enabled: false,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _totalBalanceController,
              decoration: InputDecoration(labelText: l10n.cardTotalBalance),
              enabled: false,
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: _interestRateController,
            decoration: InputDecoration(
              labelText: l10n.cardNominalInterestRate,
              suffixText: '%',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [
              DecimalAmountInputFormatter(allowNegative: false),
            ],
            validator: (v) => _validateInterestRate(v, l10n),
          ),
        ],
      ),
    );
  }

  Widget _submitPrimaryButton(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final label = widget.card == null ? l10n.accountSubmitCreate : l10n.save;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _loading ? null : _submit,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final title = widget.card == null ? l10n.newCard : l10n.editCard;

    return BottomSheetPinnedTitleScrollView(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _formFields(l10n),
          const SizedBox(height: 24),
          _submitPrimaryButton(l10n),
        ],
      ),
    );
  }
}
