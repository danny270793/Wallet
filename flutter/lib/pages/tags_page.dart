import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/tags/domain/entities/tag_entity.dart';
import '../features/tags/presentation/cubit/tags_cubit.dart';
import '../features/tags/presentation/cubit/tags_state.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';
import '../widgets/tag_editor_sheet.dart';

void _showTagBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  TagEntity? tag,
}) {
  showTagEditorBottomSheet(
    context,
    l10n,
    tag: tag,
    cubit: context.read<TagsCubit>(),
  );
}

class TagsPage extends StatelessWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TagsCubit>()..load(),
      child: const _TagsView(),
    );
  }
}

class _TagsView extends StatelessWidget {
  const _TagsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<TagsCubit, TagsState>(
      listener: (context, state) {
        if (state is TagsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        return ShellScaffold(
          title: l10n.tags,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showTagBottomSheet(context, l10n),
            child: const Icon(Icons.add),
          ),
          body: _body(context, state, l10n),
        );
      },
    );
  }

  Widget _body(BuildContext context, TagsState state, AppLocalizations l10n) {
    Future<void> refresh() => context.read<TagsCubit>().load();

    if (state is TagsLoading || state is TagsInitial) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    if (state is TagsError) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.unexpectedError),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tags = switch (state) {
      TagsLoaded(:final tags) => tags,
      TagsActionError(:final tags) => tags,
      _ => <TagEntity>[],
    };

    if (tags.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(child: Text(l10n.noTags)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: tags.length,
        itemBuilder: (context, index) => _TagTile(tag: tags[index]),
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  final TagEntity tag;
  const _TagTile({required this.tag});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<TagsCubit>();

    void openEdit() {
      _showTagBottomSheet(context, l10n, tag: tag);
    }

    void openTransactions() {
      context.push(
        Uri(
          path: '/transactions',
          queryParameters: {'tagId': tag.id, 'tagName': tag.name},
        ).toString(),
      );
    }

    return SwipeableListTile(
      itemKey: tag.id,
      title: Text(tag.name),
      subtitle: tag.description != null
          ? Text(tag.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      onTap: openTransactions,
      onEdit: openEdit,
      confirmDelete: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteTag),
            content: Text(l10n.confirmDeleteTag(tag.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDelete: () => cubit.delete(id: tag.id),
    );
  }
}
