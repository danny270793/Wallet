import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/loan_entity.dart';
import '../repositories/loans_repository.dart';

class GetLoansUsecase {
  final LoansRepository _repository;
  const GetLoansUsecase(this._repository);

  Future<OfflineServedBundle<List<LoanEntity>>> call() =>
      _repository.getLoans();
}
