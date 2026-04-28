import 'package:equatable/equatable.dart';
import '../../domain/entities/account_entity.dart';

sealed class AccountsState extends Equatable {
  const AccountsState();
}

class AccountsInitial extends AccountsState {
  const AccountsInitial();
  @override
  List<Object?> get props => [];
}

class AccountsLoading extends AccountsState {
  const AccountsLoading();
  @override
  List<Object?> get props => [];
}

class AccountsLoaded extends AccountsState {
  final List<AccountEntity> accounts;
  final Map<String, double> balancesByAccountId;
  const AccountsLoaded(this.accounts, {this.balancesByAccountId = const {}});
  @override
  List<Object?> get props => [accounts, balancesByAccountId];
}

class AccountsError extends AccountsState {
  final String? message;
  const AccountsError({this.message});
  @override
  List<Object?> get props => [message];
}

// Emitted when a CRUD action fails; retains the current list so the UI stays rendered.
class AccountsActionError extends AccountsState {
  final List<AccountEntity> accounts;
  final Map<String, double> balancesByAccountId;
  final String? message;
  const AccountsActionError(this.accounts, {this.balancesByAccountId = const {}, this.message});
  @override
  List<Object?> get props => [accounts, balancesByAccountId, message];
}
