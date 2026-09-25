import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/decimal_amount_input.dart';
import '../core/di/injection.dart';
import 'bottom_sheet_pinned_title.dart';
import 'category_editor_sheet.dart';
import 'searchable_id_picker_sheet.dart';
import 'tag_editor_sheet.dart';
import '../features/categories/domain/entities/category_entity.dart';
import '../features/categories/domain/usecases/delete_category_usecase.dart';
import '../features/categories/domain/usecases/get_categories_usecase.dart';
import '../features/categories/presentation/cubit/categories_cubit.dart';
import '../features/recurring_movements/domain/entities/recurring_movement_entity.dart';
import '../features/recurring_movements/presentation/cubit/recurring_movements_cubit.dart';
import '../features/tags/domain/entities/tag_entity.dart';
import '../features/tags/domain/usecases/delete_tag_usecase.dart';
import '../features/tags/domain/usecases/get_tags_usecase.dart';
import '../features/tags/presentation/cubit/tags_cubit.dart';

/// Create/edit form for a recurring movement on the Recurring movements screen.
Future<void> showRecurringMovementEditorBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  RecurringMovementEntity? movement,
  required RecurringMovementsCubit cubit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: RecurringMovementEditorSheet(l10n: l10n, movement: movement),
    ),
  );
}

class RecurringMovementEditorSheet extends StatefulWidget {
  const RecurringMovementEditorSheet({
    super.key,
    required this.l10n,
    this.movement,
  });

  final AppLocalizations l10n;
  final RecurringMovementEntity? movement;

  @override
  State<RecurringMovementEditorSheet> createState() =>
      _RecurringMovementEditorSheetState();
}

class _RecurringMovementEditorSheetState
    extends State<RecurringMovementEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _categoryFieldKey = GlobalKey<FormFieldState<String>>();
  final _tagFieldKey = GlobalKey<FormFieldState<String>>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _valueController;
  final _categoryDisplayController = TextEditingController();
  final _tagDisplayController = TextEditingController();
  List<CategoryEntity> _categories = [];
  List<TagEntity> _tags = [];
  String? _categoryId;
  String? _tagId;
  bool _loadingLookups = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final m = widget.movement;
    _nameController = TextEditingController(text: m?.name ?? '');
    _descriptionController = TextEditingController(text: m?.description ?? '');
    _valueController = TextEditingController(
      text: m == null ? '' : m.value.toStringAsFixed(2),
    );
    _categoryId = m?.categoryId;
    _tagId = m?.tagId;
    _categoryDisplayController.text = m?.categoryName ?? '';
    _tagDisplayController.text = m?.tagName ?? '';
    _loadLookups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _categoryDisplayController.dispose();
    _tagDisplayController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final categories = (await getIt<GetCategoriesUsecase>()()).value;
      final tags = (await getIt<GetTagsUsecase>()()).value;
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _tags = tags;
        if (_categoryId != null &&
            !_categories.any((c) => c.id == _categoryId)) {
          _categoryId = null;
        }
        if (_tagId != null && !_tags.any((t) => t.id == _tagId)) {
          _tagId = null;
        }
        _loadingLookups = false;
        _syncRelationDisplays();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLookups = false);
    }
  }

  void _syncRelationDisplays() {
    String nameOf<T>(
      List<T> items,
      String? id,
      String Function(T) idOf,
      String Function(T) nameOf,
    ) {
      if (id == null) return '';
      for (final e in items) {
        if (idOf(e) == id) return nameOf(e);
      }
      return '';
    }

    _categoryDisplayController.text = nameOf(
      _categories,
      _categoryId,
      (c) => c.id,
      (c) => c.name,
    );
    _tagDisplayController.text = nameOf(
      _tags,
      _tagId,
      (t) => t.id,
      (t) => t.name,
    );
  }

  Future<void> _pickCategory() async {
    if (_loadingLookups) return;
    final l10n = widget.l10n;
    final selectedId = await showSearchableIdPickerSheet(
      context,
      l10n: l10n,
      title: l10n.transactionCategory,
      searchHint: l10n.transferAccountSearchHint,
      noResultsMessage: l10n.transferAccountSearchNoResults,
      emptyMessage: l10n.noCategories,
      allowNone: false,
      getItems: () => _categories.map((c) => (id: c.id, name: c.name)).toList(),
      addTooltip: l10n.newCategory,
      onAddPressed: (sheetContext) =>
          showCategoryEditorBottomSheet(sheetContext, l10n),
      reloadItems: () async {
        final cats = (await getIt<GetCategoriesUsecase>()()).value;
        if (mounted) {
          setState(() {
            _categories = cats;
            if (_categoryId != null && !cats.any((c) => c.id == _categoryId)) {
              _categoryId = null;
            }
            _syncRelationDisplays();
          });
        }
      },
      swipe: SearchablePickerSwipeActions(
        onEditItem: (sheetCtx, item) async {
          final cat = _categories.firstWhere((c) => c.id == item.id);
          await showCategoryEditorBottomSheet(
            sheetCtx,
            l10n,
            category: cat,
            cubit: getIt<CategoriesCubit>(),
          );
        },
        confirmDeleteItem: (sheetCtx, item) => confirmDeletePickerTitle(
          sheetCtx,
          l10n,
          title: l10n.deleteCategory,
          message: l10n.confirmDeleteCategory(item.name),
        ),
        deleteItem: (item) async {
          try {
            await getIt<DeleteCategoryUsecase>()(id: item.id);
            return true;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
            }
            return false;
          }
        },
      ),
    );
    if (!mounted || selectedId == null || selectedId.isEmpty) return;
    setState(() {
      _categoryId = selectedId;
      _syncRelationDisplays();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _categoryFieldKey.currentState?.validate();
    });
  }

  Future<void> _pickTag() async {
    if (_loadingLookups) return;
    final l10n = widget.l10n;
    final selectedId = await showSearchableIdPickerSheet(
      context,
      l10n: l10n,
      title: l10n.transactionTag,
      searchHint: l10n.transferAccountSearchHint,
      noResultsMessage: l10n.transferAccountSearchNoResults,
      emptyMessage: l10n.noTags,
      allowNone: false,
      getItems: () => _tags
          .where((t) => !t.hidden)
          .map((t) => (id: t.id, name: t.name))
          .toList(),
      addTooltip: l10n.newTag,
      onAddPressed: (sheetContext) =>
          showTagEditorBottomSheet(sheetContext, l10n),
      reloadItems: () async {
        final tags = (await getIt<GetTagsUsecase>()()).value;
        if (mounted) {
          setState(() {
            _tags = tags;
            if (_tagId != null && !tags.any((t) => t.id == _tagId)) {
              _tagId = null;
            }
            _syncRelationDisplays();
          });
        }
      },
      swipe: SearchablePickerSwipeActions(
        onEditItem: (sheetCtx, item) async {
          final tag = _tags.firstWhere((t) => t.id == item.id);
          await showTagEditorBottomSheet(
            sheetCtx,
            l10n,
            tag: tag,
            cubit: getIt<TagsCubit>(),
          );
        },
        confirmDeleteItem: (sheetCtx, item) => confirmDeletePickerTitle(
          sheetCtx,
          l10n,
          title: l10n.deleteTag,
          message: l10n.confirmDeleteTag(item.name),
        ),
        deleteItem: (item) async {
          try {
            await getIt<DeleteTagUsecase>()(id: item.id);
            return true;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.unexpectedError)));
            }
            return false;
          }
        },
      ),
    );
    if (!mounted || selectedId == null || selectedId.isEmpty) return;
    setState(() {
      _tagId = selectedId;
      _syncRelationDisplays();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tagFieldKey.currentState?.validate();
    });
  }

  Future<void> _submit() async {
    if (_loadingLookups) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final cubit = context.read<RecurringMovementsCubit>();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final value = parseDecimalAmountInput(_valueController.text)!;
    try {
      if (widget.movement == null) {
        await cubit.create(
          name: name,
          description: description,
          value: value,
          categoryId: _categoryId!,
          tagId: _tagId!,
        );
      } else {
        await cubit.update(
          id: widget.movement!.id,
          name: name,
          description: description,
          value: value,
          categoryId: _categoryId!,
          tagId: _tagId!,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _lookupField({
    required GlobalKey<FormFieldState<String>> fieldKey,
    required String label,
    required TextEditingController controller,
    required String? selectedId,
    required VoidCallback onTap,
  }) {
    if (_loadingLookups) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return TextFormField(
      key: fieldKey,
      readOnly: true,
      enableInteractiveSelection: false,
      showCursor: false,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
      ),
      validator: (_) => selectedId == null ? widget.l10n.fieldRequired : null,
      onTap: onTap,
    );
  }

  Widget _formFields(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.accountName),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
            autofocus: widget.movement == null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: l10n.transactionAmount,
              helperText: l10n.recurringMovementValueHint,
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: const [
              DecimalAmountInputFormatter(allowNegative: true),
            ],
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
              final amt = parseDecimalAmountInput(v);
              if (amt == null) return l10n.transactionAmountInvalidNumber;
              if (amt == 0) return l10n.transactionAmountMustBeNonZero;
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _lookupField(
                  fieldKey: _categoryFieldKey,
                  label: l10n.transactionCategory,
                  controller: _categoryDisplayController,
                  selectedId: _categoryId,
                  onTap: _pickCategory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _lookupField(
                  fieldKey: _tagFieldKey,
                  label: l10n.transactionTag,
                  controller: _tagDisplayController,
                  selectedId: _tagId,
                  onTap: _pickTag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: l10n.accountDescription),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _submitPrimaryButton(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final label = widget.movement == null
        ? l10n.accountSubmitCreate
        : l10n.save;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: (_loading || _loadingLookups) ? null : _submit,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final title = widget.movement == null
        ? l10n.newRecurringMovement
        : l10n.editRecurringMovement;

    return BottomSheetPinnedTitleScrollView(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _formFields(l10n),
          const SizedBox(height: 24),
          _submitPrimaryButton(l10n),
        ],
      ),
    );
  }
}
