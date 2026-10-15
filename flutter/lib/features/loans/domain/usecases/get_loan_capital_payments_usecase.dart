import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/loan_capital_payment_entity.dart';
import '../repositories/loan_capital_payments_repository.dart';

class GetLoanCapitalPaymentsUsecase {
  final LoanCapitalPaymentsRepository _repository;
  const GetLoanCapitalPaymentsUsecase(this._repository);

  Future<OfflineServedBundle<List<LoanCapitalPaymentEntity>>> call() =>
      _repository.getCapitalPayments();
}
