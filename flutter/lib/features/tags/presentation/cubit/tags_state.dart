import 'package:equatable/equatable.dart';
import '../../domain/entities/tag_entity.dart';

sealed class TagsState extends Equatable {
  const TagsState();
}

class TagsInitial extends TagsState {
  const TagsInitial();
  @override
  List<Object?> get props => [];
}

class TagsLoading extends TagsState {
  const TagsLoading();
  @override
  List<Object?> get props => [];
}

class TagsLoaded extends TagsState {
  final List<TagEntity> tags;
  const TagsLoaded(this.tags);
  @override
  List<Object?> get props => [tags];
}

class TagsError extends TagsState {
  final String? message;
  const TagsError({this.message});
  @override
  List<Object?> get props => [message];
}

class TagsActionError extends TagsState {
  final List<TagEntity> tags;
  final String? message;
  const TagsActionError(this.tags, {this.message});
  @override
  List<Object?> get props => [tags, message];
}
