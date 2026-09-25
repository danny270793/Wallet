import 'package:flutter_bloc/flutter_bloc.dart';

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
    this.servedFromOfflineCache = false,
  });
  final List<TransactionEntity> transactions;

  /// Sum of positive recurring movement values, used as the estimated income
  /// for months after the current one.
  final double recurringMonthlyIncome;

  /// Sum of absolute negative recurring movement values (estimated outcome).
  final double recurringMonthlyOutcome;

  /// Estimated monthly net used to project the cumulative balance.
  double get recurringMonthlyNet =>
      recurringMonthlyIncome - recurringMonthlyOutcome;
  final bool servedFromOfflineCache;
}

final class YearlyDashboardError extends YearlyDashboardState {
  const YearlyDashboardError(this.failure);
  final RemoteLoadFailure failure;
}

class YearlyDashboardCubit extends Cubit<YearlyDashboardState> {
  YearlyDashboardCubit(this._getYear, this._getRecurringMovements)
    : super(const YearlyDashboardInitial());

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
  Future<({double income, double outcome})>
  _loadRecurringMonthlyTotals() async {
    try {
      final bundle = await _getRecurringMovements();
      var income = 0.0;
      var outcome = 0.0;
      for (final m in bundle.value) {
        if (m.value > 0) {
          income += m.value;
        } else {
          outcome += -m.value;
        }
      }
      return (income: income, outcome: outcome);
    } catch (e, s) {
      AppLogger.error('yearly dashboard recurring movements load failed', e, s);
      return (income: 0.0, outcome: 0.0);
    }
  }
}
