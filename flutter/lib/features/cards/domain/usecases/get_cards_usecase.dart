import '../entities/card_entity.dart';
import '../repositories/cards_repository.dart';

class GetCardsUsecase {
  final CardsRepository _repository;
  const GetCardsUsecase(this._repository);

  Future<List<CardEntity>> call() => _repository.getCards();
}
