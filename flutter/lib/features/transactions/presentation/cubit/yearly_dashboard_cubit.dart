import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote_load_failure.dart';
import '../../domain/entities/transaction_entity.dart';
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
  const YearlyDashboardLoaded(this.transactions, {this.servedFromOfflineCache = false});
  final List<TransactionEntity> transactions;
  final bool servedFromOfflineCache;
}

final class YearlyDashboardError extends YearlyDashboardState {
  const YearlyDashboardError(this.failure);
  final RemoteLoadFailure failure;
}

class YearlyDashboardCubit extends Cubit<YearlyDashboardState> {
  YearlyDashboardCubit(this._getYear) : super(const YearlyDashboardInitial());

  final GetTransactionsForYearUsecase _getYear;
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
      AppLogger.info('yearly dashboard loaded ${year.year}: ${list.length}');
      emit(YearlyDashboardLoaded(
        list,
        servedFromOfflineCache: bundle.servedFromOfflineCache,
      ));
    } catch (e, s) {
      if (gen != _generation) return;
      if (isClosed) return;
      AppLogger.error('yearly dashboard load failed', e, s);
      emit(YearlyDashboardError(classifyRemoteLoadError(e)));
    }
  }
}
