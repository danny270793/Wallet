import '../entities/wallet_credit_entity.dart';

abstract class WalletCreditsRepository {
  Future<WalletCreditEntity> createCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  });

  Future<WalletCreditEntity?> getCredit(String id);

  Future<WalletCreditEntity> updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
  });
}
