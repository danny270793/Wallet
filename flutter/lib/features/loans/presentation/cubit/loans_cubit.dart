import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote_load_failure.dart';
import '../../../../core/sort_by_name.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/usecases/create_loan_usecase.dart';
import '../../domain/usecases/delete_loan_usecase.dart';
import '../../domain/usecases/get_loans_usecase.dart';
import '../../domain/usecases/update_loan_usecase.dart';
import 'loans_state.dart';

class LoansCubit extends Cubit<LoansState> {
  final GetLoansUsecase _getLoans;
  final CreateLoanUsecase _createLoan;
  final UpdateLoanUsecase _updateLoan;
  final DeleteLoanUsecase _deleteLoan;

  LoansCubit({
    required GetLoansUsecase getLoans,
    required CreateLoanUsecase createLoan,
    required UpdateLoanUsecase updateLoan,
    required DeleteLoanUsecase deleteLoan,
  }) : _getLoans = getLoans,
       _createLoan = createLoan,
       _updateLoan = updateLoan,
       _deleteLoan = deleteLoan,
       super(const LoansInitial());

  bool _preserveOfflineCacheFlag() => switch (state) {
    LoansLoaded(:final servedFromOfflineCache) => servedFromOfflineCache,
    LoansActionError(:final servedFromOfflineCache) => servedFromOfflineCache,
    _ => false,
  };

  static List<LoanEntity> _sorted(List<LoanEntity> loans) =>
      sortedByName(loans, (l) => l.name);

  Future<void> load({bool showLoading = true}) async {
    AppLogger.debug('loading loans');
    if (showLoading) emit(const LoansLoading());
    try {
      final bundle = await _getLoans();
      final loans = _sorted(bundle.value);
      AppLogger.info('loans loaded: ${loans.length}');
      emit(
        LoansLoaded(
          loans,
          servedFromOfflineCache: bundle.servedFromOfflineCache,
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to load loans', e, s);
      emit(LoansError(failure: classifyRemoteLoadError(e)));
    }
  }

  Future<void> create({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) async {
    final current = _currentLoans();
    AppLogger.debug('creating loan: $name');
    try {
      final loan = await _createLoan(
        accountId: accountId,
        name: name,
        value: value,
        nominalInterestRate: nominalInterestRate,
        termMonths: termMonths,
        paymentDay: paymentDay,
        firstPaymentDate: firstPaymentDate,
      );
      AppLogger.info('loan created: ${loan.id}');
      emit(
        LoansLoaded(
          _sorted([...current, loan]),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to create loan', e, s);
      emit(
        LoansActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    }
  }

  Future<void> update({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) async {
    final current = _currentLoans();
    AppLogger.debug('updating loan: $id');
    try {
      final loan = await _updateLoan(
        id: id,
        accountId: accountId,
        name: name,
        value: value,
        nominalInterestRate: nominalInterestRate,
        termMonths: termMonths,
        paymentDay: paymentDay,
        firstPaymentDate: firstPaymentDate,
      );
      AppLogger.info('loan updated: $id');
      emit(
        LoansLoaded(
          _sorted(current.map((l) => l.id == id ? loan : l).toList()),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    } catch (e, s) {
      AppLogger.error('failed to update loan', e, s);
      emit(
        LoansActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
    }
  }

  Future<bool> delete({required String id}) async {
    final current = _currentLoans();
    AppLogger.debug('deleting loan: $id');
    try {
      await _deleteLoan(id: id);
      AppLogger.info('loan deleted: $id');
      emit(
        LoansLoaded(
          current.where((l) => l.id != id).toList(),
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete loan', e, s);
      emit(
        LoansActionError(
          current,
          servedFromOfflineCache: _preserveOfflineCacheFlag(),
        ),
      );
      return false;
    }
  }

  List<LoanEntity> _currentLoans() => switch (state) {
    LoansLoaded(:final loans) => loans,
    LoansActionError(:final loans) => loans,
    _ => [],
  };
}
