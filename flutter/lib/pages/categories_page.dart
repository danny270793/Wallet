import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/categories/domain/entities/category_entity.dart';
import '../features/categories/presentation/cubit/categories_cubit.dart';
import '../features/categories/presentation/cubit/categories_state.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';

void _showCategoryBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  CategoryEntity? category,
}) {
  showCategoryEditorBottomSheet(
    context,
    l10n,
    category: category,
    cubit: context.read<CategoriesCubit>(),
  );
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CategoriesCubit>()..load(),
      child: const _CategoriesView(),
    );
  }
}

class _CategoriesView extends StatelessWidget {
  const _CategoriesView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<CategoriesCubit, CategoriesState>(
      listener: (context, state) {
        if (state is CategoriesActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        return ShellScaffold(
          title: l10n.categories,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCategoryBottomSheet(context, l10n),
            child: const Icon(Icons.add),
          ),
          body: _body(context, state, l10n),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    CategoriesState state,
    AppLocalizations l10n,
  ) {
    Future<void> refresh() => context.read<CategoriesCubit>().load();

    if (state is CategoriesLoading || state is CategoriesInitial) {
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

    if (state is CategoriesError) {
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

    final categories = switch (state) {
      CategoriesLoaded(:final categories) => categories,
      CategoriesActionError(:final categories) => categories,
      _ => <CategoryEntity>[],
    };

    if (categories.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(child: Text(l10n.noCategories)),
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
        itemCount: categories.length,
        itemBuilder: (context, index) =>
            _CategoryTile(category: categories[index]),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryEntity category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<CategoriesCubit>();

    void openEdit() {
      _showCategoryBottomSheet(context, l10n, category: category);
    }

    void openTransactions() {
      context.push(
        Uri(
          path: '/transactions',
          queryParameters: {
            'categoryId': category.id,
            'categoryName': category.name,
          },
        ).toString(),
      );
    }

    return SwipeableListTile(
      itemKey: category.id,
      title: Text(category.name),
      subtitle: category.description != null
          ? Text(
              category.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: openTransactions,
      onEdit: openEdit,
      confirmDelete: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteCategory),
            content: Text(l10n.confirmDeleteCategory(category.name)),
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
      onDelete: () => cubit.delete(id: category.id),
    );
  }
}
