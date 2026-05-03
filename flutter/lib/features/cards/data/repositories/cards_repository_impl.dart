import '../../domain/entities/card_entity.dart';
import '../../domain/repositories/cards_repository.dart';
import '../datasources/cards_remote_datasource.dart';

class CardsRepositoryImpl implements CardsRepository {
  final CardsRemoteDatasource _datasource;
  const CardsRepositoryImpl(this._datasource);

  @override
  Future<List<CardEntity>> getCards() => _datasource.getCards();

  @override
  Future<CardEntity> createCard({
    required String name,
    String? description,
    int cutDay = 24,
    int payDay = 24,
  }) =>
      _datasource.createCard(
        name: name,
        description: description,
        cutDay: cutDay,
        payDay: payDay,
      );

  @override
  Future<CardEntity> updateCard({
    required String id,
    required String name,
    String? description,
    required int cutDay,
    required int payDay,
  }) =>
      _datasource.updateCard(
        id: id,
        name: name,
        description: description,
        cutDay: cutDay,
        payDay: payDay,
      );

  @override
  Future<void> deleteCard({required String id}) => _datasource.deleteCard(id: id);
}
