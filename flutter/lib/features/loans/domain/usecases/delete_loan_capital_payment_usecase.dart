import '../repositories/loan_capital_payments_repository.dart';

class DeleteLoanCapitalPaymentUsecase {
  final LoanCapitalPaymentsRepository _repository;
  const DeleteLoanCapitalPaymentUsecase(this._repository);

  Future<void> call({required String id}) =>
      _repository.deleteCapitalPayment(id: id);
}
