import '../entities/card_entity.dart';
import '../repositories/cards_repository.dart';
import '../entities/card_type.dart';

class CreateCardUsecase {
  final CardsRepository _repository;
  const CreateCardUsecase(this._repository);

  Future<CardEntity> call({
    required String name,
    required CardType type,
    double? nominalInterestRate,
    int cutDay = 24,
    int payDay = 24,
  }) => _repository.createCard(
    name: name,
    type: type,
    nominalInterestRate: nominalInterestRate,
    cutDay: cutDay,
    payDay: payDay,
  );
}
