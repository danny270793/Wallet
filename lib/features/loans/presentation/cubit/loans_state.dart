import 'package:equatable/equatable.dart';

import '../../../../core/remote_load_failure.dart';
import '../../domain/entities/loan_entity.dart';

sealed class LoansState extends Equatable {
  const LoansState();
}

class LoansInitial extends LoansState {
  const LoansInitial();
  @override
  List<Object?> get props => [];
}

class LoansLoading extends LoansState {
  const LoansLoading();
  @override
  List<Object?> get props => [];
}

class LoansLoaded extends LoansState {
  final List<LoanEntity> loans;
  final bool servedFromOfflineCache;
  const LoansLoaded(this.loans, {this.servedFromOfflineCache = false});
  @override
  List<Object?> get props => [loans, servedFromOfflineCache];
}

class LoansError extends LoansState {
  final RemoteLoadFailure failure;
  const LoansError({this.failure = RemoteLoadFailure.requestFailed});
  @override
  List<Object?> get props => [failure];
}

/// Create/update/delete failed; list is unchanged so the UI can keep showing prior data.
class LoansActionError extends LoansState {
  final List<LoanEntity> loans;
  final bool servedFromOfflineCache;
  const LoansActionError(this.loans, {this.servedFromOfflineCache = false});
  @override
  List<Object?> get props => [loans, servedFromOfflineCache];
}
