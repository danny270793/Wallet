import '../entities/card_entity.dart';
import '../repositories/cards_repository.dart';

class UpdateCardUsecase {
  final CardsRepository _repository;
  const UpdateCardUsecase(this._repository);

  Future<CardEntity> call({
    required String id,
    required String name,
    String? description,
    required int cutDay,
    required int payDay,
  }) => _repository.updateCard(
    id: id,
    name: name,
    description: description,
    cutDay: cutDay,
    payDay: payDay,
  );
}
