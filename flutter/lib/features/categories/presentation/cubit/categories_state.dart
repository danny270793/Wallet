import 'package:equatable/equatable.dart';

import '../../../../core/remote_load_failure.dart';
import '../../domain/entities/category_entity.dart';

sealed class CategoriesState extends Equatable {
  const CategoriesState();
}

class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
  @override
  List<Object?> get props => [];
}

class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
  @override
  List<Object?> get props => [];
}

class CategoriesLoaded extends CategoriesState {
  final List<CategoryEntity> categories;
  final bool servedFromOfflineCache;
  const CategoriesLoaded(this.categories, {this.servedFromOfflineCache = false});
  @override
  List<Object?> get props => [categories, servedFromOfflineCache];
}

class CategoriesError extends CategoriesState {
  final RemoteLoadFailure failure;
  const CategoriesError({this.failure = RemoteLoadFailure.requestFailed});
  @override
  List<Object?> get props => [failure];
}

class CategoriesActionError extends CategoriesState {
  final List<CategoryEntity> categories;
  final String? message;
  final bool servedFromOfflineCache;
  const CategoriesActionError(this.categories, {this.message, this.servedFromOfflineCache = false});
  @override
  List<Object?> get props => [categories, message, servedFromOfflineCache];
}
