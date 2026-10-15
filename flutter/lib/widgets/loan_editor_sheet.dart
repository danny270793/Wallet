import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/decimal_amount_input.dart';
import '../core/di/injection.dart';
import '../core/sort_by_name.dart';
import '../features/accounts/domain/entities/account_entity.dart';
import '../features/accounts/domain/usecases/get_accounts_usecase.dart';
import '../features/loans/domain/entities/loan_entity.dart';
import '../features/loans/presentation/cubit/loans_cubit.dart';
import 'account_editor_sheet.dart';
import 'bottom_sheet_pinned_title.dart';
import 'day_of_month_picker_dialog.dart';
import 'searchable_id_picker_sheet.dart';

Future<void> showLoanEditorBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  LoanEntity? loan,
  LoansCubit? cubit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) {
      final child = LoanEditorSheet(l10n: l10n, loan: loan);
      return cubit != null
          ? BlocProvider.value(value: cubit, child: child)
          : BlocProvider(create: (_) => getIt<LoansCubit>(), child: child);
    },
  );
}

class LoanEditorSheet extends StatefulWidget {
  const LoanEditorSheet({super.key, required this.l10n, this.loan});

  final AppLocalizations l10n;
  final LoanEntity? loan;

  @override
  State<LoanEditorSheet> createState() => _LoanEditorSheetState();
}

class _LoanEditorSheetState extends State<LoanEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final TextEditingController _interestRateController;
  late final TextEditingController _termController;
  late final TextEditingController _paymentDayDisplayController;
  final _paymentDayFieldKey = GlobalKey<FormFieldState<String>>();
  late final TextEditingController _accountDisplayController;
  final _accountFieldKey = GlobalKey<FormFieldState<String>>();
  List<AccountEntity> _accounts = const [];
  bool _loadingAccounts = true;
  String? _accountId;
  int? _paymentDay;
  DateTime? _firstPaymentDate;
  late final TextEditingController _firstPaymentDisplayController;
  final _firstPaymentFieldKey = GlobalKey<FormFieldState<String>>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    _nameController = TextEditingController(text: loan?.name ?? '');
    _valueController = TextEditingController(
      text: loan?.value.toStringAsFixed(2) ?? '',
    );
    _interestRateController = TextEditingController(
      text: loan?.nominalInterestRate?.toString() ?? '',
    );
    _termController = TextEditingController(
      text: loan?.termMonths.toString() ?? '',
    );
    _accountDisplayController = TextEditingController();
    _accountId = loan?.accountId;
    _paymentDay = loan?.paymentDay;
    _firstPaymentDate = loan?.firstPaymentDate;
    _firstPaymentDisplayController = TextEditingController();
    _paymentDayDisplayController = TextEditingController(
      text: _paymentDay?.toString() ?? '',
    );
    _loadAccounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFirstPaymentText();
  }

  void _syncFirstPaymentText() {
    final d = _firstPaymentDate;
    final locale = Localizations.localeOf(context).toString();
    _firstPaymentDisplayController.text = d == null
        ? ''
        : DateFormat.yMd(locale).format(d);
  }

  /// Also fills an empty payment day with the picked date's day (30 at most).
  Future<void> _pickFirstPaymentDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _firstPaymentDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _firstPaymentDate = DateTime(d.year, d.month, d.day);
      _syncFirstPaymentText();
      if (_paymentDay == null) {
        _paymentDay = d.day > 30 ? 30 : d.day;
        _paymentDayDisplayController.text = '$_paymentDay';
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstPaymentFieldKey.currentState?.validate();
      _paymentDayFieldKey.currentState?.validate();
    });
  }

  Future<void> _loadAccounts() async {
    try {
      final bundle = await getIt<GetAccountsUsecase>()();
      if (!mounted) return;
      setState(() {
        _accounts = sortedByName(bundle.value, (a) => a.name);
        if (_accountId != null && !_accounts.any((a) => a.id == _accountId)) {
          _accountId = null;
        }
        _loadingAccounts = false;
        _syncAccountText();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  void _syncAccountText() {
    final match = _accounts.where((a) => a.id == _accountId);
    _accountDisplayController.text = match.isEmpty ? '' : match.first.name;
  }

  Future<void> _pickAccount() async {
    if (_loadingAccounts) return;
    final l10n = widget.l10n;
    final selectedId = await showSearchableIdPickerSheet(
      context,
      l10n: l10n,
      title: l10n.loanAccount,
      searchHint: l10n.transferAccountSearchHint,
      noResultsMessage: l10n.transferAccountSearchNoResults,
      emptyMessage: l10n.noAccounts,
      allowNone: false,
      getItems: () => _accounts.map((a) => (id: a.id, name: a.name)).toList(),
      addTooltip: l10n.newAccount,
      onAddPressed: (sheetContext) =>
          showAccountEditorBottomSheet(sheetContext, l10n),
      reloadItems: _loadAccounts,
    );
    if (!mounted || selectedId == null || selectedId.isEmpty) return;
    setState(() {
      _accountId = selectedId;
      _syncAccountText();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accountFieldKey.currentState?.validate();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _interestRateController.dispose();
    _termController.dispose();
    _paymentDayDisplayController.dispose();
    _firstPaymentDisplayController.dispose();
    _accountDisplayController.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentDay() async {
    final day = await showDayOfMonthPicker(
      context,
      title: widget.l10n.loanPaymentDay,
      selected: _paymentDay,
    );
    if (day == null || !mounted) return;
    setState(() {
      _paymentDay = day;
      _paymentDayDisplayController.text = '$day';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paymentDayFieldKey.currentState?.validate();
    });
  }

  String? _validateValue(String? v, AppLocalizations l10n) {
    if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
    final n = parseDecimalAmountInput(v);
    if (n == null || n <= 0) return l10n.loanValueInvalid;
    return null;
  }

  String? _validateInterestRate(String? v, AppLocalizations l10n) {
    if (v == null || v.trim().isEmpty) return null;
    final n = parseDecimalAmountInput(v);
    if (n == null || n < 0) return l10n.cardNominalInterestRateInvalid;
    return null;
  }

  String? _validateTerm(String? v, AppLocalizations l10n) {
    if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
    final n = int.tryParse(v.trim());
    if (n == null || n < 1) return l10n.loanTermInvalid;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final cubit = context.read<LoansCubit>();
    final accountId = _accountId!;
    final name = _nameController.text.trim();
    final value = parseDecimalAmountInput(_valueController.text)!;
    final nominalInterestRate = parseDecimalAmountInput(
      _interestRateController.text,
    );
    final termMonths = int.parse(_termController.text.trim());
    try {
      if (widget.loan == null) {
        await cubit.create(
          accountId: accountId,
          name: name,
          value: value,
          nominalInterestRate: nominalInterestRate,
          termMonths: termMonths,
          paymentDay: _paymentDay!,
          firstPaymentDate: _firstPaymentDate!,
        );
      } else {
        await cubit.update(
          id: widget.loan!.id,
          accountId: accountId,
          name: name,
          value: value,
          nominalInterestRate: nominalInterestRate,
          termMonths: termMonths,
          paymentDay: _paymentDay!,
          firstPaymentDate: _firstPaymentDate!,
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
            autofocus: widget.loan == null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: _accountFieldKey,
            readOnly: true,
            enableInteractiveSelection: false,
            showCursor: false,
            controller: _accountDisplayController,
            decoration: InputDecoration(
              labelText: l10n.loanAccount,
              suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
            ),
            validator: (_) => _accountId == null ? l10n.fieldRequired : null,
            onTap: _pickAccount,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _valueController,
            decoration: InputDecoration(labelText: l10n.loanValue),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [
              DecimalAmountInputFormatter(allowNegative: false),
            ],
            validator: (v) => _validateValue(v, l10n),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _interestRateController,
                  decoration: InputDecoration(
                    labelText: l10n.cardNominalInterestRate,
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [
                    DecimalAmountInputFormatter(allowNegative: false),
                  ],
                  validator: (v) => _validateInterestRate(v, l10n),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _termController,
                  decoration: InputDecoration(
                    labelText: l10n.transactionMesesPlazo,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateTerm(v, l10n),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: _firstPaymentFieldKey,
                  controller: _firstPaymentDisplayController,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  decoration: InputDecoration(
                    labelText: l10n.loanFirstPaymentDate,
                    suffixIcon: const Icon(Icons.event_outlined),
                  ),
                  validator: (_) =>
                      _firstPaymentDate == null ? l10n.fieldRequired : null,
                  onTap: _pickFirstPaymentDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: _paymentDayFieldKey,
                  controller: _paymentDayDisplayController,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  decoration: InputDecoration(
                    labelText: l10n.loanPaymentDay,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (_) =>
                      _paymentDay == null ? l10n.fieldRequired : null,
                  onTap: _pickPaymentDay,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _submitPrimaryButton(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final label = widget.loan == null ? l10n.accountSubmitCreate : l10n.save;
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
    final title = widget.loan == null ? l10n.newLoan : l10n.editLoan;

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
