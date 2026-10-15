import '../entities/loan_entity.dart';
import '../repositories/loans_repository.dart';

class UpdateLoanUsecase {
  final LoansRepository _repository;
  const UpdateLoanUsecase(this._repository);

  Future<LoanEntity> call({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) => _repository.updateLoan(
    id: id,
    accountId: accountId,
    name: name,
    value: value,
    nominalInterestRate: nominalInterestRate,
    termMonths: termMonths,
    paymentDay: paymentDay,
    firstPaymentDate: firstPaymentDate,
  );
}
