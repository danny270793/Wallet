import '../../domain/entities/wallet_credit_entity.dart';
import '../../domain/repositories/wallet_credits_repository.dart';
import '../datasources/wallet_credits_remote_datasource.dart';

class WalletCreditsRepositoryImpl implements WalletCreditsRepository {
  final WalletCreditsRemoteDatasource _datasource;
  const WalletCreditsRepositoryImpl(this._datasource);

  @override
  Future<WalletCreditEntity> createCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  }) =>
      _datasource.insertCredit(
        transactedAt: transactedAt,
        graceMonths: graceMonths,
        termMonths: termMonths,
        description: description,
      );

  @override
  Future<WalletCreditEntity?> getCredit(String id) => _datasource.fetchCredit(id);

  @override
  Future<WalletCreditEntity> updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
    DateTime? transactedAt,
  }) =>
      _datasource.updateCreditGracing(
        id: id,
        graceMonths: graceMonths,
        termMonths: termMonths,
        transactedAt: transactedAt,
      );
}
