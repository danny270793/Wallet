import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';
import '../core/di/injection.dart';
import '../features/categories/domain/entities/category_entity.dart';
import '../features/categories/presentation/cubit/categories_cubit.dart';
import '../features/categories/presentation/cubit/categories_state.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';

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
          body: Stack(
            children: [
              _body(context, state, l10n),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: () => _showCategoryDialog(context, l10n),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CategoriesState state, AppLocalizations l10n) {
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
        itemBuilder: (context, index) => _CategoryTile(category: categories[index]),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, AppLocalizations l10n, [CategoryEntity? category]) {
    showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(
        cubit: context.read<CategoriesCubit>(),
        l10n: l10n,
        category: category,
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
      showDialog<void>(
        context: context,
        builder: (_) => _CategoryDialog(cubit: cubit, l10n: l10n, category: category),
      );
    }

    return SwipeableListTile(
      itemKey: category.id,
      leading: initialsAvatar(context, category.name),
      title: Text(category.name),
      subtitle: category.description != null
          ? Text(category.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
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
                child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return ok ?? false;
      },
      onDeleted: () => cubit.delete(id: category.id),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoriesCubit cubit;
  final AppLocalizations l10n;
  final CategoryEntity? category;

  const _CategoryDialog({required this.cubit, required this.l10n, this.category});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descriptionController = TextEditingController(text: widget.category?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    try {
      if (widget.category == null) {
        await widget.cubit.create(name: name, description: description);
      } else {
        await widget.cubit.update(id: widget.category!.id, name: name, description: description);
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final isEdit = widget.category != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.editCategory : l10n.newCategory),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.accountName),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.accountDescription),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
