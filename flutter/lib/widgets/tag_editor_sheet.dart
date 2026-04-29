import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import 'bottom_sheet_pinned_title.dart';
import '../features/tags/domain/entities/tag_entity.dart';
import '../features/tags/presentation/cubit/tags_cubit.dart';

/// Same tag create/edit form as the Tags screen.
Future<void> showTagEditorBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  TagEntity? tag,
  TagsCubit? cubit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) {
      final child = TagEditorSheet(l10n: l10n, tag: tag);
      return cubit != null
          ? BlocProvider.value(value: cubit, child: child)
          : BlocProvider(create: (_) => getIt<TagsCubit>(), child: child);
    },
  );
}

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({super.key, required this.l10n, this.tag});

  final AppLocalizations l10n;
  final TagEntity? tag;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.tag?.description ?? '',
    );
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
    final cubit = context.read<TagsCubit>();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    try {
      if (widget.tag == null) {
        await cubit.create(name: name, description: description);
      } else {
        await cubit.update(
          id: widget.tag!.id,
          name: name,
          description: description,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
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
    );
  }

  Widget _submitPrimaryButton(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final label = widget.tag == null ? l10n.accountSubmitCreate : l10n.save;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _loading ? null : _submit,
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
    final title = widget.tag == null ? l10n.newTag : l10n.editTag;

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
