import 'package:equatable/equatable.dart';

import '../../../../core/credit_ledger_grouping.dart';
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

  /// Deferred installment sums keyed by card id; missing ids have no installments.
  final Map<String, CardCreditTotals> creditTotals;
  final bool servedFromOfflineCache;
  const CardsLoaded(
    this.cards, {
    this.creditTotals = const {},
    this.servedFromOfflineCache = false,
  });
  @override
  List<Object?> get props => [cards, creditTotals, servedFromOfflineCache];
}

class CardsError extends CardsState {
  final RemoteLoadFailure failure;
  const CardsError({this.failure = RemoteLoadFailure.requestFailed});
  @override
  List<Object?> get props => [failure];
}

class CardsActionError extends CardsState {
  final List<CardEntity> cards;
  final Map<String, CardCreditTotals> creditTotals;
  final String? message;
  final bool servedFromOfflineCache;
  const CardsActionError(
    this.cards, {
    this.creditTotals = const {},
    this.message,
    this.servedFromOfflineCache = false,
  });
  @override
  List<Object?> get props => [
    cards,
    creditTotals,
    message,
    servedFromOfflineCache,
  ];
}
