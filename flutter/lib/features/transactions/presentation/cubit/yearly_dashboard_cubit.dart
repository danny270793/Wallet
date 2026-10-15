import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/automatic_recurring_movements.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote_load_failure.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../../recurring_movements/domain/usecases/get_recurring_movements_usecase.dart';
import '../../domain/usecases/get_transactions_for_year_usecase.dart';

sealed class YearlyDashboardState {
  const YearlyDashboardState();
}

final class YearlyDashboardInitial extends YearlyDashboardState {
  const YearlyDashboardInitial();
}

final class YearlyDashboardLoading extends YearlyDashboardState {
  const YearlyDashboardLoading();
}

final class YearlyDashboardLoaded extends YearlyDashboardState {
  const YearlyDashboardLoaded(
    this.transactions, {
    this.recurringMonthlyIncome = 0,
    this.recurringMonthlyOutcome = 0,
    this.automaticSource = const AutomaticMovementsSource(),
    this.servedFromOfflineCache = false,
  });
  final List<TransactionEntity> transactions;

  /// Sum of positive recurring movement values, used as the estimated income
  /// for months after the current one.
  final double recurringMonthlyIncome;

  /// Sum of absolute negative recurring movement values (estimated outcome of
  /// the user's own movements).
  final double recurringMonthlyOutcome;

  /// Loans and cards, for the estimates that change month to month.
  final AutomaticMovementsSource automaticSource;

  /// Loan installments and card interest due in [month] (positive). Card
  /// deferred installments are left out: they are already transactions dated
  /// in their months.
  double automaticOutcomeFor(DateTime month) => automaticSource
      .forMonth(month)
      .where((a) => a is! CardDeferredRecurringMovement)
      .fold(0, (s, a) => s - a.monthlyAmount);

  /// Estimated outcome of [month]: recurring movements plus loans and cards.
  double outcomeFor(DateTime month) =>
      recurringMonthlyOutcome + automaticOutcomeFor(month);

  /// Estimated net of [month].
  double netFor(DateTime month) => recurringMonthlyIncome - outcomeFor(month);

  /// Net of the user's own recurring movements only (see [netFor]).
  double get recurringMonthlyNet =>
      recurringMonthlyIncome - recurringMonthlyOutcome;
  final bool servedFromOfflineCache;
}

final class YearlyDashboardError extends YearlyDashboardState {
  const YearlyDashboardError(this.failure);
  final RemoteLoadFailure failure;
}

class YearlyDashboardCubit extends Cubit<YearlyDashboardState> {
  YearlyDashboardCubit(
    this._getYear,
    this._getRecurringMovements, {
    Future<AutomaticMovementsSource> Function()? loadAutomaticSource,
  }) : _loadAutomaticSource =
           loadAutomaticSource ?? loadAutomaticMovementsSource,
       super(const YearlyDashboardInitial());

  final Future<AutomaticMovementsSource> Function() _loadAutomaticSource;

  final GetTransactionsForYearUsecase _getYear;
  final GetRecurringMovementsUsecase _getRecurringMovements;
  int _generation = 0;

  Future<void> loadYear(DateTime yearStartLocal) async {
    final year = DateTime(yearStartLocal.year, 1, 1);
    final gen = ++_generation;
    emit(const YearlyDashboardLoading());
    try {
      final bundle = await _getYear(year);
      if (gen != _generation) return;
      if (isClosed) return;
      final list = bundle.value;
      final recurring = await _loadRecurringMonthlyTotals();
      if (gen != _generation) return;
      if (isClosed) return;
      AppLogger.info('yearly dashboard loaded ${year.year}: ${list.length}');
      emit(
        YearlyDashboardLoaded(
          list,
          recurringMonthlyIncome: recurring.income,
          recurringMonthlyOutcome: recurring.outcome,
          automaticSource: recurring.automatic,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      if (gen != _generation) return;
      if (isClosed) return;
      AppLogger.error('yearly dashboard load failed', e, s);
      emit(YearlyDashboardError(classifyRemoteLoadError(e)));
    }
  }

  /// Projection is optional: a failure here should not block the dashboard.
  Future<({double income, double outcome, AutomaticMovementsSource automatic})>
  _loadRecurringMonthlyTotals() async {
    var income = 0.0;
    var outcome = 0.0;
    try {
      final bundle = await _getRecurringMovements();
      for (final m in bundle.value) {
        final monthly = m.monthlyAmount;
        if (monthly > 0) {
          income += monthly;
        } else {
          outcome += -monthly;
        }
      }
    } catch (e, s) {
      AppLogger.error('yearly dashboard recurring movements load failed', e, s);
    }
    return (
      income: income,
      outcome: outcome,
      automatic: await _loadAutomaticSource(),
    );
  }
}
