import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/loan_entity.dart';

abstract class LoansRepository {
  Future<OfflineServedBundle<List<LoanEntity>>> getLoans();
  Future<LoanEntity> createLoan({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  });
  Future<LoanEntity> updateLoan({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  });
  Future<void> deleteLoan({required String id});
}
