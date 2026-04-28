import '../entities/card_entity.dart';

abstract class CardsRepository {
  Future<List<CardEntity>> getCards();
  Future<CardEntity> createCard({required String name, String? description});
  Future<CardEntity> updateCard({required String id, required String name, String? description});
  Future<void> deleteCard({required String id});
}
