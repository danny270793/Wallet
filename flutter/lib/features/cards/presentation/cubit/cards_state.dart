import 'package:equatable/equatable.dart';
import '../../domain/entities/card_entity.dart';

sealed class CardsState extends Equatable {
  const CardsState();
}

class CardsInitial extends CardsState {
  const CardsInitial();
  @override
  List<Object?> get props => [];
}

class CardsLoading extends CardsState {
  const CardsLoading();
  @override
  List<Object?> get props => [];
}

class CardsLoaded extends CardsState {
  final List<CardEntity> cards;
  const CardsLoaded(this.cards);
  @override
  List<Object?> get props => [cards];
}

class CardsError extends CardsState {
  final String? message;
  const CardsError({this.message});
  @override
  List<Object?> get props => [message];
}

class CardsActionError extends CardsState {
  final List<CardEntity> cards;
  final String? message;
  const CardsActionError(this.cards, {this.message});
  @override
  List<Object?> get props => [cards, message];
}
