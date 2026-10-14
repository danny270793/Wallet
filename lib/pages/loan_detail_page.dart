import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/decimal_amount_input.dart';
import '../core/di/injection.dart';
import '../features/accounts/domain/usecases/get_accounts_usecase.dart';
import '../features/loans/domain/entities/loan_capital_payment_entity.dart';
import '../features/loans/domain/entities/loan_entity.dart';
import '../features/loans/domain/entities/loan_schedule.dart';
import '../features/loans/domain/usecases/create_loan_capital_payment_usecase.dart';
import '../features/loans/domain/usecases/delete_loan_capital_payment_usecase.dart';
import '../features/loans/domain/usecases/get_loan_capital_payments_usecase.dart';
import '../features/loans/presentation/cubit/loans_cubit.dart';
import '../features/loans/presentation/cubit/loans_state.dart';
import '../core/logger/app_logger.dart';
import '../widgets/bottom_sheet_pinned_title.dart';
import '../widgets/error_details.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_bottom_bar_insets.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

/// One loan: its creation values and the monthly payment plan derived from them,
/// recomputed after each payment to capital. Loans are not linked to
/// transactions yet, so installments are computed, not recorded.
class LoanDetailPage extends StatelessWidget {
  const LoanDetailPage({super.key, required this.loanId, this.initialLoan});

  final String loanId;

  /// Passed from the list so the page renders before the reload finishes.
  final LoanEntity? initialLoan;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoansCubit>()..load(showLoading: false),
      child: _LoanDetailView(loanId: loanId, initialLoan: initialLoan),
    );
  }
}

class _LoanDetailView extends StatefulWidget {
  const _LoanDetailView({required this.loanId, this.initialLoan});

  final String loanId;
  final LoanEntity? initialLoan;

  @override
  State<_LoanDetailView> createState() => _LoanDetailViewState();
}

class _LoanDetailViewState extends State<_LoanDetailView> {
  String? _accountName;
  List<LoanCapitalPaymentEntity> _capitalPayments = const [];

  @override
  void initState() {
    super.initState();
    _loadAccountName(widget.initialLoan?.accountId);
    _loadCapitalPayments();
  }

  Future<void> _loadAccountName(String? accountId) async {
    if (accountId == null) return;
    try {
      final accounts = (await getIt<GetAccountsUsecase>()()).value;
      if (!mounted) return;
      final match = accounts.where((a) => a.id == accountId);
      setState(() => _accountName = match.isEmpty ? null : match.first.name);
    } catch (e, s) {
      AppLogger.error('failed to load loan account name', e, s);
    }
  }

  Future<void> _loadCapitalPayments() async {
    try {
      final all = (await getIt<GetLoanCapitalPaymentsUsecase>()()).value;
      if (!mounted) return;
      setState(() {
        _capitalPayments = all.where((p) => p.loanId == widget.loanId).toList();
      });
    } catch (e, s) {
      AppLogger.error('failed to load loan capital payments', e, s);
    }
  }

  /// Pull to refresh: the loan itself, its account name and capital payments.
  Future<void> _refresh(LoanEntity loan) => Future.wait([
    context.read<LoansCubit>().load(showLoading: false),
    _loadAccountName(loan.accountId),
    _loadCapitalPayments(),
  ]);

  Future<void> _addCapitalPayment(
    AppLocalizations l10n,
    LoanEntity loan,
  ) async {
    final result =
        await showModalBottomSheet<({double value, DateTime paidAt})>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: false,
          builder: (_) => _CapitalPaymentSheet(
            l10n: l10n,
            maxValueOn: (date) =>
                loanBalanceOn(loan, date, capitalPayments: _capitalPayments),
          ),
        );
    if (result == null || !mounted) return;
    try {
      await getIt<CreateLoanCapitalPaymentUsecase>()(
        loanId: loan.id,
        value: result.value,
        paidAt: result.paidAt,
      );
      await _loadCapitalPayments();
    } catch (e, s) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        l10n,
        logMessage: 'failed to create loan capital payment',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<bool> _deleteCapitalPayment(
    AppLocalizations l10n,
    LoanCapitalPaymentEntity payment,
  ) async {
    try {
      await getIt<DeleteLoanCapitalPaymentUsecase>()(id: payment.id);
      await _loadCapitalPayments();
      return true;
    } catch (e, s) {
      if (mounted) {
        showErrorSnackBar(
          context,
          l10n,
          logMessage: 'failed to delete loan capital payment',
          error: e,
          stackTrace: s,
        );
      }
      return false;
    }
  }

  Future<bool> _confirmDeleteCapitalPayment(AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.loanDeleteCapitalPayment),
        content: Text(l10n.loanConfirmDeleteCapitalPayment),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);

    return BlocConsumer<LoansCubit, LoansState>(
      listenWhen: (prev, next) {
        final before = _find(prev)?.accountId;
        final after = _find(next)?.accountId;
        return after != null && after != before;
      },
      listener: (context, state) => _loadAccountName(_find(state)?.accountId),
      builder: (context, state) {
        final loan = _find(state) ?? widget.initialLoan;
        if (loan == null) {
          return ShellScaffold(
            title: l10n.loans,
            useDrawer: false,
            body: state is LoansLoaded || state is LoansActionError
                ? Center(child: Text(l10n.loanNotFound))
                : const Center(child: CircularProgressIndicator()),
          );
        }

        final schedule = loanSchedule(loan, capitalPayments: _capitalPayments);
        final totalPayment = schedule.fold<double>(0, (s, e) => s + e.payment);
        final paidInstallments = schedule
            .whereType<LoanInstallmentEntry>()
            .where(loanEntryIsPaid)
            .fold<double>(0, (s, e) => s + e.payment);
        final paidToCapital = schedule
            .whereType<LoanCapitalPaymentEntry>()
            .fold<double>(0, (s, e) => s + e.payment);
        final installmentCount = schedule
            .whereType<LoanInstallmentEntry>()
            .length;

        Widget detail(String label, String value) => ListTile(
          dense: true,
          title: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Text(value, style: theme.textTheme.bodyLarge),
        );

        String amount(double v) =>
            l10n.transactionAmountValue(v.toStringAsFixed(2));

        return ShellScaffold(
          title: loan.name,
          useDrawer: false,
          floatingActionButton: FloatingActionButton(
            tooltip: l10n.loanCapitalPayment,
            onPressed: () => _addCapitalPayment(l10n, loan),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: _LoanTotalsBar(
            l10n: l10n,
            paidInstallments: paidInstallments,
            paidToCapital: paidToCapital,
            pending: totalPayment - paidInstallments - paidToCapital,
          ),
          body: RefreshIndicator(
            onRefresh: () => _refresh(loan),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                detail(l10n.loanAccount, _accountName ?? ''),
                detail(l10n.loanValue, amount(loan.value)),
                detail(l10n.loanTotalToPay, amount(totalPayment)),
                detail(
                  l10n.loanInterestToPay,
                  amount(totalPayment - loan.value),
                ),
                detail(
                  l10n.cardNominalInterestRate,
                  loan.nominalInterestRate == null
                      ? '—'
                      : '${loan.nominalInterestRate!.toStringAsFixed(2)} %',
                ),
                detail(l10n.transactionMesesPlazo, '${loan.termMonths}'),
                detail(
                  l10n.loanFirstPaymentDate,
                  dateFormat.format(loan.firstPaymentDate),
                ),
                detail(l10n.loanPaymentDay, '${loan.paymentDay}'),
                detail(
                  l10n.loanMonthlyPayment,
                  amount(
                    loanCurrentPayment(loan, capitalPayments: _capitalPayments),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    l10n.loanSchedule,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final e in schedule)
                  switch (e) {
                    LoanInstallmentEntry() => _ScheduleRow(
                      l10n: l10n,
                      paid: loanEntryIsPaid(e),
                      title:
                          '${e.number}/$installmentCount · '
                          '${dateFormat.format(e.date)}',
                      subtitle: l10n.loanInstallmentBreakdown(
                        e.principal.toStringAsFixed(2),
                        e.interest.toStringAsFixed(2),
                        e.remaining.toStringAsFixed(2),
                      ),
                      payment: e.payment,
                    ),
                    LoanCapitalPaymentEntry() => SwipeableListTile(
                      itemKey: e.capitalPayment.id,
                      leading: Icon(
                        Icons.savings_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        '${l10n.loanCapitalPayment} · '
                        '${dateFormat.format(e.date)}',
                      ),
                      subtitle: Text(
                        l10n.loanCapitalPaymentLeft(
                          e.remaining.toStringAsFixed(2),
                        ),
                      ),
                      trailing: WalletListBalanceAmount(
                        l10n: l10n,
                        balance: -e.payment,
                      ),
                      // Only delete applies: a capital payment has nothing to edit
                      // that deleting and re-adding would not cover.
                      onEdit: () {},
                      confirmDelete: () => _confirmDeleteCapitalPayment(l10n),
                      onDelete: () =>
                          _deleteCapitalPayment(l10n, e.capitalPayment),
                    ),
                  },
              ],
            ),
          ),
        );
      },
    );
  }

  LoanEntity? _find(LoansState state) {
    final loans = switch (state) {
      LoansLoaded(:final loans) => loans,
      LoansActionError(:final loans) => loans,
      _ => const <LoanEntity>[],
    };
    for (final l in loans) {
      if (l.id == widget.loanId) return l;
    }
    return null;
  }
}

/// Installment row; already-paid ones are faded and marked with a check.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.l10n,
    required this.paid,
    required this.title,
    required this.subtitle,
    required this.payment,
  });

  final AppLocalizations l10n;
  final bool paid;
  final String title;
  final String subtitle;
  final double payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = ListTile(
      leading: Icon(
        paid ? Icons.check_circle : Icons.radio_button_unchecked,
        color: paid
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: WalletListBalanceAmount(l10n: l10n, balance: -payment),
    );
    return paid ? Opacity(opacity: 0.55, child: tile) : tile;
  }
}

/// Asks for the amount and day of a payment to capital, at most what is owed
/// on that day.
class _CapitalPaymentSheet extends StatefulWidget {
  const _CapitalPaymentSheet({required this.l10n, required this.maxValueOn});

  final AppLocalizations l10n;

  /// Principal still owed at the end of the given day.
  final double Function(DateTime date) maxValueOn;

  @override
  State<_CapitalPaymentSheet> createState() => _CapitalPaymentSheetState();
}

class _CapitalPaymentSheetState extends State<_CapitalPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _dateController = TextEditingController();
  late DateTime _paidAt;

  double get _maxValue => widget.maxValueOn(_paidAt);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _paidAt = DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDateText();
  }

  void _syncDateText() {
    final locale = Localizations.localeOf(context).toString();
    _dateController.text = DateFormat.yMd(locale).format(_paidAt);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _paidAt = DateTime(d.year, d.month, d.day);
      _syncDateText();
    });
    if (_valueController.text.trim().isNotEmpty) {
      _formKey.currentState?.validate();
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      value: parseDecimalAmountInput(_valueController.text)!,
      paidAt: _paidAt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final max = _maxValue.toStringAsFixed(2);
    return BottomSheetPinnedTitleScrollView(
      title: l10n.loanCapitalPayment,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _dateController,
              readOnly: true,
              enableInteractiveSelection: false,
              showCursor: false,
              decoration: InputDecoration(
                labelText: l10n.loanCapitalPaymentDate,
                suffixIcon: const Icon(Icons.event_outlined),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _valueController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.loanValue,
                helperText: l10n.loanCapitalPaymentMax(max),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [
                DecimalAmountInputFormatter(allowNegative: false),
              ],
              validator: (v) {
                final n = parseDecimalAmountInput(v);
                if (n == null || n <= 0) return l10n.loanValueInvalid;
                if (n > _maxValue + 1e-6) {
                  return l10n.loanCapitalPaymentMax(max);
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: theme.textTheme.labelLarge,
              ),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned footer: installments already due, payments to capital, and what is
/// still pending.
class _LoanTotalsBar extends StatelessWidget {
  const _LoanTotalsBar({
    required this.l10n,
    required this.paidInstallments,
    required this.paidToCapital,
    required this.pending,
  });

  final AppLocalizations l10n;
  final double paidInstallments;
  final double paidToCapital;
  final double pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    Widget column(double value, String label, Color color) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.transactionAmountValue(value.toStringAsFixed(2)),
            textAlign: TextAlign.center,
            style: amountStyle?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: labelStyle),
        ],
      ),
    );

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: walletBottomBarExtraBottomInset(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(
                paidInstallments,
                l10n.loanPaidInstallments,
                walletListBalanceColor(theme, paidInstallments),
              ),
              column(
                paidToCapital,
                l10n.loanPaidToCapital,
                walletListBalanceColor(theme, paidToCapital),
              ),
              column(
                pending,
                l10n.loanPending,
                walletListBalanceColor(theme, -pending),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
