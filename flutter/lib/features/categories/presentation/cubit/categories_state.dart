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
  const CategoriesLoaded(this.categories);
  @override
  List<Object?> get props => [categories];
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
  const CategoriesActionError(this.categories, {this.message});
  @override
  List<Object?> get props => [categories, message];
}
