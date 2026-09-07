import 'package:equatable/equatable.dart';

import '../../../../core/remote_load_failure.dart';
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
  final bool servedFromOfflineCache;
  const AccountsLoaded(this.accounts, {this.servedFromOfflineCache = false});
  @override
  List<Object?> get props => [accounts, servedFromOfflineCache];
}

class AccountsError extends AccountsState {
  final RemoteLoadFailure failure;
  const AccountsError({this.failure = RemoteLoadFailure.requestFailed});
  @override
  List<Object?> get props => [failure];
}

// Emitted when a CRUD action fails; retains the current list so the UI stays rendered.
class AccountsActionError extends AccountsState {
  final List<AccountEntity> accounts;
  final String? message;
  final bool servedFromOfflineCache;
  const AccountsActionError(
    this.accounts, {
    this.message,
    this.servedFromOfflineCache = false,
  });
  @override
  List<Object?> get props => [accounts, message, servedFromOfflineCache];
}
