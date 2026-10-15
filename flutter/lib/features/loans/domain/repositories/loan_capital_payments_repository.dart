import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/loan_capital_payment_entity.dart';

abstract class LoanCapitalPaymentsRepository {
  /// Every capital payment of the user, across all loans.
  Future<OfflineServedBundle<List<LoanCapitalPaymentEntity>>>
  getCapitalPayments();
  Future<LoanCapitalPaymentEntity> createCapitalPayment({
    required String loanId,
    required double value,
    required DateTime paidAt,
  });
  Future<void> deleteCapitalPayment({required String id});
}
