import '../repositories/cards_repository.dart';

class DeleteCardUsecase {
  final CardsRepository _repository;
  const DeleteCardUsecase(this._repository);

  Future<void> call({required String id}) => _repository.deleteCard(id: id);
}
