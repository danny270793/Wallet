import '../../../../core/offline/offline_fetch.dart';
import '../../../../core/offline/offline_served_bundle.dart';
import '../../../../core/offline/wallet_offline_cache.dart';
import '../../../../core/offline/wallet_offline_user_context.dart';
import '../../domain/entities/loan_capital_payment_entity.dart';
import '../../domain/repositories/loan_capital_payments_repository.dart';
import '../datasources/loan_capital_payments_remote_datasource.dart';

class LoanCapitalPaymentsRepositoryImpl
    implements LoanCapitalPaymentsRepository {
  final LoanCapitalPaymentsRemoteDatasource _datasource;
  final WalletOfflineCache _offlineCache;
  final WalletOfflineUserContext _offlineSession;

  const LoanCapitalPaymentsRepositoryImpl(
    this._datasource,
    this._offlineCache,
    this._offlineSession,
  );

  @override
  Future<OfflineServedBundle<List<LoanCapitalPaymentEntity>>>
  getCapitalPayments() => fetchListWithOfflineCache(
    session: _offlineSession,
    cache: _offlineCache,
    cacheKey: WalletOfflineCacheKeys.loanCapitalPayments,
    remote: _datasource.getCapitalPayments,
    fromJson: LoanCapitalPaymentEntity.fromJson,
    toJson: (e) => e.toJson(),
  );

  @override
  Future<LoanCapitalPaymentEntity> createCapitalPayment({
    required String loanId,
    required double value,
    required DateTime paidAt,
  }) => _datasource.createCapitalPayment(
    loanId: loanId,
    value: value,
    paidAt: paidAt,
  );

  @override
  Future<void> deleteCapitalPayment({required String id}) =>
      _datasource.deleteCapitalPayment(id: id);
}
