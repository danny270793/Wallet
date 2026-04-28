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
  const AccountsLoaded(this.accounts);
  @override
  List<Object?> get props => [accounts];
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
  final String? message;
  const AccountsActionError(this.accounts, {this.message});
  @override
  List<Object?> get props => [accounts, message];
}
