import 'package:equatable/equatable.dart';

import '../../../../core/remote_load_failure.dart';
import '../../domain/entities/recurring_movement_entity.dart';

sealed class RecurringMovementsState extends Equatable {
  const RecurringMovementsState();
}

class RecurringMovementsInitial extends RecurringMovementsState {
  const RecurringMovementsInitial();
  @override
  List<Object?> get props => [];
}

class RecurringMovementsLoading extends RecurringMovementsState {
  const RecurringMovementsLoading();
  @override
  List<Object?> get props => [];
}

class RecurringMovementsLoaded extends RecurringMovementsState {
  final List<RecurringMovementEntity> movements;
  final bool servedFromOfflineCache;
  const RecurringMovementsLoaded(
    this.movements, {
    this.servedFromOfflineCache = false,
  });
  @override
  List<Object?> get props => [movements, servedFromOfflineCache];
}

class RecurringMovementsError extends RecurringMovementsState {
  final RemoteLoadFailure failure;
  const RecurringMovementsError({
    this.failure = RemoteLoadFailure.requestFailed,
  });
  @override
  List<Object?> get props => [failure];
}

class RecurringMovementsActionError extends RecurringMovementsState {
  final List<RecurringMovementEntity> movements;
  final String? message;
  final bool servedFromOfflineCache;
  const RecurringMovementsActionError(
    this.movements, {
    this.message,
    this.servedFromOfflineCache = false,
  });
  @override
  List<Object?> get props => [movements, message, servedFromOfflineCache];
}
