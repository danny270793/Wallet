import '../../domain/entities/card_entity.dart';
import '../../domain/repositories/cards_repository.dart';
import '../datasources/cards_remote_datasource.dart';

class CardsRepositoryImpl implements CardsRepository {
  final CardsRemoteDatasource _datasource;
  const CardsRepositoryImpl(this._datasource);

  @override
  Future<List<CardEntity>> getCards() => _datasource.getCards();

  @override
  Future<CardEntity> createCard({required String name, String? description}) =>
      _datasource.createCard(name: name, description: description);

  @override
  Future<CardEntity> updateCard({required String id, required String name, String? description}) =>
      _datasource.updateCard(id: id, name: name, description: description);

  @override
  Future<void> deleteCard({required String id}) => _datasource.deleteCard(id: id);
}
