import '../entities/card_entity.dart';

abstract class CardsRepository {
  Future<List<CardEntity>> getCards();
  Future<CardEntity> createCard({
    required String name,
    String? description,
    int cutDay = 24,
    int payDay = 24,
  });
  Future<CardEntity> updateCard({
    required String id,
    required String name,
    String? description,
    required int cutDay,
    required int payDay,
  });
  Future<void> deleteCard({required String id});
}
