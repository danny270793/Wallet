import '../../../../core/offline/offline_served_bundle.dart';
import '../entities/card_entity.dart';
import '../repositories/cards_repository.dart';

class GetCardsUsecase {
  final CardsRepository _repository;
  const GetCardsUsecase(this._repository);

  Future<OfflineServedBundle<List<CardEntity>>> call() => _repository.getCards();
}
