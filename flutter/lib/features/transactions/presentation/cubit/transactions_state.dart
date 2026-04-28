import 'package:equatable/equatable.dart';
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
  const TransactionsLoaded(this.transactions);
  @override
  List<Object?> get props => [transactions];
}

class TransactionsError extends TransactionsState {
  final String? message;
  const TransactionsError({this.message});
  @override
  List<Object?> get props => [message];
}

class TransactionsActionError extends TransactionsState {
  final List<TransactionEntity> transactions;
  final String? message;
  const TransactionsActionError(this.transactions, {this.message});
  @override
  List<Object?> get props => [transactions, message];
}
