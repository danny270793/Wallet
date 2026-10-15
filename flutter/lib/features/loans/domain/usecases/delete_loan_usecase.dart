import '../repositories/loans_repository.dart';

class DeleteLoanUsecase {
  final LoansRepository _repository;
  const DeleteLoanUsecase(this._repository);

  Future<void> call({required String id}) => _repository.deleteLoan(id: id);
}
