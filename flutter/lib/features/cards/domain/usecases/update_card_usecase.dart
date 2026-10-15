import '../entities/card_entity.dart';
import '../repositories/cards_repository.dart';
import '../entities/card_type.dart';

class UpdateCardUsecase {
  final CardsRepository _repository;
  const UpdateCardUsecase(this._repository);

  Future<CardEntity> call({
    required String id,
    required String name,
    required CardType type,
    double? nominalInterestRate,
    required int cutDay,
    required int payDay,
  }) => _repository.updateCard(
    id: id,
    name: name,
    type: type,
    nominalInterestRate: nominalInterestRate,
    cutDay: cutDay,
    payDay: payDay,
  );
}
