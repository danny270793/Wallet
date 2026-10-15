import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/wallet_credit_entity.dart';

abstract class WalletCreditsRepository {
  Future<WalletCreditEntity> createCredit({
    required DateTime transactedAt,
    required int graceMonths,
    required int termMonths,
    String? description,
  });

  Future<OfflineServedBundle<WalletCreditEntity?>> getCredit(String id);

  Future<WalletCreditEntity> updateCreditGracing({
    required String id,
    required int graceMonths,
    required int termMonths,
    DateTime? transactedAt,
  });
}
