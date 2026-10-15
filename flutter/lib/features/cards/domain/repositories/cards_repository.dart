import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/card_entity.dart';
import '../entities/card_type.dart';

abstract class CardsRepository {
  Future<OfflineServedBundle<List<CardEntity>>> getCards();
  Future<CardEntity> createCard({
    required String name,
    required CardType type,
    double? nominalInterestRate,
    int cutDay = 24,
    int payDay = 24,
  });
  Future<CardEntity> updateCard({
    required String id,
    required String name,
    required CardType type,
    double? nominalInterestRate,
    required int cutDay,
    required int payDay,
  });
  Future<void> deleteCard({required String id});
}
