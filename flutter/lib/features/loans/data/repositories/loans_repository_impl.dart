import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/offline_served_bundle.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/repositories/loans_repository.dart';
import '../datasources/loans_remote_datasource.dart';

class LoansRepositoryImpl implements LoansRepository {
  final LoansRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const LoansRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<OfflineServedBundle<List<LoanEntity>>> getLoans() =>
      fetchListWithOfflineCache(
        session: _offlineSession,
        cache: _offlineCache,
        cacheKey: WalletOfflineCacheKeys.loans,
        remote: _datasource.getLoans,
        fromJson: LoanEntity.fromJson,
        toJson: (e) => e.toJson(),
      );

  @override
  Future<LoanEntity> createLoan({
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) => _datasource.createLoan(
    accountId: accountId,
    name: name,
    value: value,
    nominalInterestRate: nominalInterestRate,
    termMonths: termMonths,
    paymentDay: paymentDay,
    firstPaymentDate: firstPaymentDate,
  );

  @override
  Future<LoanEntity> updateLoan({
    required String id,
    required String accountId,
    required String name,
    required double value,
    double? nominalInterestRate,
    required int termMonths,
    required int paymentDay,
    required DateTime firstPaymentDate,
  }) => _datasource.updateLoan(
    id: id,
    accountId: accountId,
    name: name,
    value: value,
    nominalInterestRate: nominalInterestRate,
    termMonths: termMonths,
    paymentDay: paymentDay,
    firstPaymentDate: firstPaymentDate,
  );

  @override
  Future<void> deleteLoan({required String id}) =>
      _datasource.deleteLoan(id: id);
}
