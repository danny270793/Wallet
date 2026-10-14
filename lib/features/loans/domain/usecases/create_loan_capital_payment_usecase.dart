import '../entities/loan_capital_payment_entity.dart';
import '../repositories/loan_capital_payments_repository.dart';

class CreateLoanCapitalPaymentUsecase {
  final LoanCapitalPaymentsRepository _repository;
  const CreateLoanCapitalPaymentUsecase(this._repository);

  Future<LoanCapitalPaymentEntity> call({
    required String loanId,
    required double value,
    required DateTime paidAt,
  }) => _repository.createCapitalPayment(
    loanId: loanId,
    value: value,
    paidAt: paidAt,
  );
}
