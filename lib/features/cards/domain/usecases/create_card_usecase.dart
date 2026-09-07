import '../entities/card_entity.dart';
import '../repositories/cards_repository.dart';

class CreateCardUsecase {
  final CardsRepository _repository;
  const CreateCardUsecase(this._repository);

  Future<CardEntity> call({
    required String name,
    String? description,
    int cutDay = 24,
    int payDay = 24,
  }) => _repository.createCard(
    name: name,
    description: description,
    cutDay: cutDay,
    payDay: payDay,
  );
}
