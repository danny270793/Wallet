import 'package:equatable/equatable.dart';

import '../../../../core/remote_load_failure.dart';
import '../../domain/entities/transaction_entity.dart';

sealed class TransactionsState extends Equatable {
  const TransactionsState();
}

class TransactionsInitial extends TransactionsState {
  const TransactionsInitial();
  @override
  List<Object?> get props => [];
}

class TransactionsLoading extends TransactionsState {
  const TransactionsLoading();
  @override
  List<Object?> get props => [];
}

class TransactionsLoaded extends TransactionsState {
  final List<TransactionEntity> transactions;
  final bool servedFromOfflineCache;
  const TransactionsLoaded(
    this.transactions, {
    this.servedFromOfflineCache = false,
  });
  @override
  List<Object?> get props => [transactions, servedFromOfflineCache];
}

class TransactionsError extends TransactionsState {
  final RemoteLoadFailure failure;
  const TransactionsError({this.failure = RemoteLoadFailure.requestFailed});
  @override
  List<Object?> get props => [failure];
}

class TransactionsActionError extends TransactionsState {
  final List<TransactionEntity> transactions;
  final String? message;
  final bool servedFromOfflineCache;
  const TransactionsActionError(
    this.transactions, {
    this.message,
    this.servedFromOfflineCache = false,
  });
  @override
  List<Object?> get props => [transactions, message, servedFromOfflineCache];
}
