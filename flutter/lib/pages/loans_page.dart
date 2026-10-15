import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../features/accounts/domain/usecases/get_accounts_usecase.dart';
import '../features/loans/domain/entities/loan_capital_payment_entity.dart';
import '../features/loans/domain/entities/loan_entity.dart';
import '../features/loans/domain/entities/loan_schedule.dart';
import '../features/loans/domain/usecases/get_loan_capital_payments_usecase.dart';
import '../features/loans/presentation/cubit/loans_cubit.dart';
import '../features/loans/presentation/cubit/loans_state.dart';
import '../widgets/loan_editor_sheet.dart';
import '../widgets/offline_cached_data_banner.dart';
import '../widgets/remote_load_failure_panel.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/wallet_dual_balance_trailing.dart';

/// `name (xx.xx %)` when the loan has a rate, like the cards list.
String loanTitle(LoanEntity loan) => loan.nominalInterestRate == null
    ? loan.name
    : '${loan.name} (${loan.nominalInterestRate!.toStringAsFixed(2)} %)';

/// Amounts on the right of a loan row, like the credits list: the current
/// installment, what is still pending, and the whole debt (every installment
/// plus payments to capital). All positive; rows show them as outflows.
({double monthly, double pending, double total}) loanListAmounts(
  LoanEntity loan, {
  required List<LoanCapitalPaymentEntity> capitalPayments,
}) {
  final schedule = loanSchedule(loan, capitalPayments: capitalPayments);
  final total = schedule.fold<double>(0, (s, e) => s + e.payment);
  final paid = schedule
      .where(loanEntryIsPaid)
      .fold<double>(0, (s, e) => s + e.payment);
  return (
    monthly: loanCurrentPayment(loan, capitalPayments: capitalPayments),
    pending: total - paid,
    total: total,
  );
}

Widget _amountText(
  AppLocalizations l10n,
  ThemeData theme,
  double amount, {
  bool emphasized = false,
}) {
  final base = emphasized
      ? theme.textTheme.titleSmall
      : theme.textTheme.bodySmall;
  return Text(
    l10n.transactionAmountValue(amount.toStringAsFixed(2)),
    textAlign: TextAlign.end,
    style: base?.copyWith(
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
      color: emphasized ? theme.colorScheme.error : theme.colorScheme.onSurface,
      height: 1.15,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class LoansPage extends StatelessWidget {
  const LoansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoansCubit>()..load(),
      child: const _LoansView(),
    );
  }
}

class _LoansView extends StatefulWidget {
  const _LoansView();

  @override
  State<_LoansView> createState() => _LoansViewState();
}

class _LoansViewState extends State<_LoansView> {
  /// Ids picked in multi-select mode (entered by long-pressing a row).
  final Set<String> _selectedIds = {};

  /// Account names by id, for the row subtitles; empty until loaded.
  Map<String, String> _accountNames = const {};

  /// Capital payments by loan id, so rows show the recomputed monthly amount.
  Map<String, List<LoanCapitalPaymentEntity>> _capitalPayments = const {};

  @override
  void initState() {
    super.initState();
    _loadAccountNames();
    _loadCapitalPayments();
  }

  Future<void> _loadCapitalPayments() async {
    try {
      final all = (await getIt<GetLoanCapitalPaymentsUsecase>()()).value;
      if (!mounted) return;
      final byLoan = <String, List<LoanCapitalPaymentEntity>>{};
      for (final p in all) {
        byLoan.putIfAbsent(p.loanId, () => []).add(p);
      }
      setState(() => _capitalPayments = byLoan);
    } catch (_) {}
  }

  Future<void> _loadAccountNames() async {
    try {
      final bundle = await getIt<GetAccountsUsecase>()();
      if (!mounted) return;
      setState(() {
        _accountNames = {for (final a in bundle.value) a.id: a.name};
      });
    } catch (_) {}
  }

  /// Selected rows that still exist; select mode is on while this is non-empty.
  List<LoanEntity> _selectedAmong(List<LoanEntity> items) =>
      items.where((e) => _selectedIds.contains(e.id)).toList();

  void _toggleSelected(String id, List<LoanEntity> items) {
    setState(() {
      // Drop ids of rows that no longer exist before toggling.
      _selectedIds.retainAll(items.map((e) => e.id));
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<LoansCubit, LoansState>(
      listener: (context, state) {
        if (state is LoansActionError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
        }
      },
      builder: (context, state) {
        final loans = switch (state) {
          LoansLoaded(:final loans) => loans,
          LoansActionError(:final loans) => loans,
          _ => <LoanEntity>[],
        };
        final selected = _selectedAmong(loans);
        final selecting = selected.isNotEmpty;
        final showTotalBar = loans.isNotEmpty;
        final total = (selecting ? selected : loans).fold<double>(
          0,
          (s, l) =>
              s -
              loanListAmounts(
                l,
                capitalPayments: _capitalPayments[l.id] ?? const [],
              ).pending,
        );

        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _clearSelection();
          },
          child: ShellScaffold(
            title: selecting
                ? l10n.listSelectedCount(selected.length)
                : l10n.loans,
            appBarActionsBeforeSettings: selecting
                ? [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      onPressed: _clearSelection,
                    ),
                  ]
                : null,
            floatingActionButton: FloatingActionButton(
              onPressed: () => showLoanEditorBottomSheet(
                context,
                l10n,
                cubit: context.read<LoansCubit>(),
              ),
              child: const Icon(Icons.add),
            ),
            bottomNavigationBar: showTotalBar
                ? WalletListBalanceTotalBar(l10n: l10n, total: total)
                : null,
            body: _body(context, state, l10n),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, LoansState state, AppLocalizations l10n) {
    Future<void> pullRefresh() async {
      await Future.wait([
        context.read<LoansCubit>().load(showLoading: false),
        _loadAccountNames(),
        _loadCapitalPayments(),
      ]);
    }

    Future<void> reloadWithOverlay() =>
        context.read<LoansCubit>().load(showLoading: true);

    if (state is LoansLoading || state is LoansInitial) {
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

    if (state is LoansError) {
      return RemoteLoadFailurePanel(
        l10n: l10n,
        failure: state.failure,
        onRetry: reloadWithOverlay,
      );
    }

    final offlineCached = switch (state) {
      LoansLoaded(:final servedFromOfflineCache) => servedFromOfflineCache,
      LoansActionError(:final servedFromOfflineCache) => servedFromOfflineCache,
      _ => false,
    };

    final loans = switch (state) {
      LoansLoaded(:final loans) => loans,
      LoansActionError(:final loans) => loans,
      _ => <LoanEntity>[],
    };

    if (loans.isEmpty) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            OfflineCachedDataBanner(visible: offlineCached),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.3,
              child: Center(child: Text(l10n.noLoans)),
            ),
          ],
        ),
      );
    }

    final selecting = _selectedAmong(loans).isNotEmpty;
    return RefreshIndicator(
      onRefresh: pullRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: loans.length + (offlineCached ? 1 : 0),
        itemBuilder: (context, index) {
          if (offlineCached && index == 0) {
            return const OfflineCachedDataBanner(visible: true);
          }
          final loan = loans[index - (offlineCached ? 1 : 0)];
          return _LoanTile(
            loan: loan,
            accountName: _accountNames[loan.accountId],
            capitalPayments: _capitalPayments[loan.id] ?? const [],
            onReturned: _loadCapitalPayments,
            selecting: selecting,
            selected: _selectedIds.contains(loan.id),
            onToggleSelected: () => _toggleSelected(loan.id, loans),
          );
        },
      ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  final LoanEntity loan;
  final String? accountName;
  final List<LoanCapitalPaymentEntity> capitalPayments;

  /// Called after coming back from the detail page (capital payments may have changed).
  final Future<void> Function() onReturned;

  /// In select mode a tap toggles selection and swipe actions are disabled.
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelected;

  const _LoanTile({
    required this.loan,
    required this.accountName,
    required this.capitalPayments,
    required this.onReturned,
    required this.selecting,
    required this.selected,
    required this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<LoansCubit>();
    final theme = Theme.of(context);
    final amounts = loanListAmounts(loan, capitalPayments: capitalPayments);
    final summary = l10n.loanTermMonths(loan.termMonths);

    Future<void> openDetail() async {
      await context.push('/loans/${loan.id}', extra: loan);
      if (!context.mounted) return;
      await Future.wait([cubit.load(showLoading: false), onReturned()]);
    }

    return SwipeableListTile(
      itemKey: loan.id,
      title: Text(loanTitle(loan)),
      subtitle: Text(
        accountName == null ? summary : '$accountName · $summary',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _amountText(l10n, theme, -amounts.monthly, emphasized: true),
          const SizedBox(height: 2),
          _amountText(l10n, theme, -amounts.pending),
          const SizedBox(height: 2),
          _amountText(l10n, theme, -amounts.total),
        ],
      ),
      selected: selected,
      swipeEnabled: !selecting,
      onTap: selecting ? onToggleSelected : openDetail,
      onLongPress: onToggleSelected,
      onEdit: () =>
          showLoanEditorBottomSheet(context, l10n, loan: loan, cubit: cubit),
      confirmDelete: () => confirmDeleteLoan(context, l10n, loan),
      onDelete: () => cubit.delete(id: loan.id),
    );
  }
}

Future<bool> confirmDeleteLoan(
  BuildContext context,
  AppLocalizations l10n,
  LoanEntity loan,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteLoan),
      content: Text(l10n.confirmDeleteLoan(loan.name)),
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
}
