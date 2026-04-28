import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/card_entity.dart';
import '../../domain/usecases/get_cards_usecase.dart';
import '../../domain/usecases/create_card_usecase.dart';
import '../../domain/usecases/update_card_usecase.dart';
import '../../domain/usecases/delete_card_usecase.dart';
import 'cards_state.dart';

class CardsCubit extends Cubit<CardsState> {
  final GetCardsUsecase _getCards;
  final CreateCardUsecase _createCard;
  final UpdateCardUsecase _updateCard;
  final DeleteCardUsecase _deleteCard;

  CardsCubit({
    required GetCardsUsecase getCards,
    required CreateCardUsecase createCard,
    required UpdateCardUsecase updateCard,
    required DeleteCardUsecase deleteCard,
  })  : _getCards = getCards,
        _createCard = createCard,
        _updateCard = updateCard,
        _deleteCard = deleteCard,
        super(const CardsInitial());

  Future<void> load() async {
    AppLogger.debug('loading cards');
    emit(const CardsLoading());
    try {
      final cards = await _getCards();
      AppLogger.info('cards loaded: ${cards.length}');
      emit(CardsLoaded(cards));
    } catch (e, s) {
      AppLogger.error('failed to load cards', e, s);
      emit(const CardsError());
    }
  }

  Future<void> create({required String name, String? description}) async {
    final current = _currentCards();
    AppLogger.debug('creating card: $name');
    try {
      await _createCard(name: name, description: description);
      AppLogger.info('card created');
      final cards = await _getCards();
      emit(CardsLoaded(cards));
    } catch (e, s) {
      AppLogger.error('failed to create card', e, s);
      emit(CardsActionError(current));
    }
  }

  Future<void> update({required String id, required String name, String? description}) async {
    final current = _currentCards();
    AppLogger.debug('updating card: $id');
    try {
      await _updateCard(id: id, name: name, description: description);
      AppLogger.info('card updated: $id');
      final cards = await _getCards();
      emit(CardsLoaded(cards));
    } catch (e, s) {
      AppLogger.error('failed to update card', e, s);
      try {
        final reloaded = await _getCards();
        emit(CardsActionError(reloaded));
      } catch (_) {
        emit(CardsActionError(current));
      }
    }
  }

  Future<void> delete({required String id}) async {
    final current = _currentCards();
    AppLogger.debug('deleting card: $id');
    try {
      await _deleteCard(id: id);
      AppLogger.info('card deleted: $id');
      emit(CardsLoaded(current.where((a) => a.id != id).toList()));
    } catch (e, s) {
      AppLogger.error('failed to delete card', e, s);
      emit(CardsActionError(current));
    }
  }

  List<CardEntity> _currentCards() => switch (state) {
    CardsLoaded(:final cards) => cards,
    CardsActionError(:final cards) => cards,
    _ => [],
  };
}
