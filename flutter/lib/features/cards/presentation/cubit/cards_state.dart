import 'package:equatable/equatable.dart';

import '../../../../core/remote_load_failure.dart';
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
  final RemoteLoadFailure failure;
  const CardsError({this.failure = RemoteLoadFailure.requestFailed});
  @override
  List<Object?> get props => [failure];
}

class CardsActionError extends CardsState {
  final List<CardEntity> cards;
  final String? message;
  const CardsActionError(this.cards, {this.message});
  @override
  List<Object?> get props => [cards, message];
}
