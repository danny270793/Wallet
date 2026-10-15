import '../entities/loan_entity.dart';
import '../repositories/loans_repository.dart';

class CreateLoanUsecase {
  final LoansRepository _repository;
  const CreateLoanUsecase(this._repository);

  Future<LoanEntity> call({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) => _repository.createLoan(
    accountId: accountId,
    name: name,
    value: value,
    nominalInterestRate: nominalInterestRate,
    termMonths: termMonths,
    paymentDay: paymentDay,
    firstPaymentDate: firstPaymentDate,
  );
}
