import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/sort_by_name.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/usecases/get_tags_usecase.dart';
import '../../domain/usecases/create_tag_usecase.dart';
import '../../domain/usecases/update_tag_usecase.dart';
import '../../domain/usecases/delete_tag_usecase.dart';
import 'tags_state.dart';

class TagsCubit extends Cubit<TagsState> {
  final GetTagsUsecase _getTags;
  final CreateTagUsecase _createTag;
  final UpdateTagUsecase _updateTag;
  final DeleteTagUsecase _deleteTag;

  TagsCubit({
    required GetTagsUsecase getTags,
    required CreateTagUsecase createTag,
    required UpdateTagUsecase updateTag,
    required DeleteTagUsecase deleteTag,
  })  : _getTags = getTags,
        _createTag = createTag,
        _updateTag = updateTag,
        _deleteTag = deleteTag,
        super(const TagsInitial());

  Future<void> load() async {
    AppLogger.debug('loading tags');
    emit(const TagsLoading());
    try {
      final tags = sortedByName(await _getTags(), (t) => t.name);
      AppLogger.info('tags loaded: ${tags.length}');
      emit(TagsLoaded(tags));
    } catch (e, s) {
      AppLogger.error('failed to load tags', e, s);
      emit(const TagsError());
    }
  }

  Future<void> create({required String name, String? description}) async {
    final current = _currentTags();
    AppLogger.debug('creating tag: $name');
    try {
      final tag = await _createTag(name: name, description: description);
      AppLogger.info('tag created: ${tag.id}');
      emit(TagsLoaded(sortedByName([...current, tag], (t) => t.name)));
    } catch (e, s) {
      AppLogger.error('failed to create tag', e, s);
      emit(TagsActionError(current));
    }
  }

  Future<void> update({required String id, required String name, String? description}) async {
    final current = _currentTags();
    AppLogger.debug('updating tag: $id');
    try {
      final updated = await _updateTag(id: id, name: name, description: description);
      AppLogger.info('tag updated: ${updated.id}');
      emit(TagsLoaded(
        sortedByName(
          current.map((a) => a.id == id ? updated : a).toList(),
          (t) => t.name,
        ),
      ));
    } catch (e, s) {
      AppLogger.error('failed to update tag', e, s);
      emit(TagsActionError(current));
    }
  }

  Future<bool> delete({required String id}) async {
    final current = _currentTags();
    AppLogger.debug('deleting tag: $id');
    try {
      await _deleteTag(id: id);
      AppLogger.info('tag deleted: $id');
      emit(TagsLoaded(
        sortedByName(current.where((a) => a.id != id).toList(), (t) => t.name),
      ));
      return true;
    } catch (e, s) {
      AppLogger.error('failed to delete tag', e, s);
      emit(TagsActionError(current));
      return false;
    }
  }

  List<TagEntity> _currentTags() => switch (state) {
    TagsLoaded(:final tags) => tags,
    TagsActionError(:final tags) => tags,
    _ => [],
  };
}
