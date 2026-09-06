import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import 'bottom_sheet_pinned_title.dart';
import '../features/cards/domain/entities/card_entity.dart';
import '../features/cards/presentation/cubit/cards_cubit.dart';

/// Same card create/edit form as the Cards screen FAB / row edit.
Future<void> showCardEditorBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  CardEntity? card,
  CardsCubit? cubit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) {
      final child = CardEditorSheet(l10n: l10n, card: card);
      return cubit != null
          ? BlocProvider.value(value: cubit, child: child)
          : BlocProvider(create: (_) => getIt<CardsCubit>(), child: child);
    },
  );
}

class CardEditorSheet extends StatefulWidget {
  const CardEditorSheet({super.key, required this.l10n, this.card});

  final AppLocalizations l10n;
  final CardEntity? card;

  @override
  State<CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<CardEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cutDayController;
  late final TextEditingController _payDayController;
  late final TextEditingController _descriptionController;
  TextEditingController? _balanceController;
  bool _loading = false;

  static String _dayText(int day) => day.toString();

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _nameController = TextEditingController(text: card?.name ?? '');
    _cutDayController = TextEditingController(
      text: _dayText(card?.cutDay ?? 24),
    );
    _payDayController = TextEditingController(
      text: _dayText(card?.payDay ?? 24),
    );
    _descriptionController = TextEditingController(
      text: card?.description ?? '',
    );
    if (card != null) {
      _balanceController = TextEditingController(
        text: card.balance.toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cutDayController.dispose();
    _payDayController.dispose();
    _descriptionController.dispose();
    _balanceController?.dispose();
    super.dispose();
  }

  String? _validateBillingDay(String? v, AppLocalizations l10n) {
    if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
    final n = int.tryParse(v.trim());
    if (n == null || n < 1 || n > 30) return l10n.cardDayInvalidRange;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final cubit = context.read<CardsCubit>();
    final name = _nameController.text.trim();
    final cutDay = int.parse(_cutDayController.text.trim());
    final payDay = int.parse(_payDayController.text.trim());
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    try {
      if (widget.card == null) {
        await cubit.create(
          name: name,
          description: description,
          cutDay: cutDay,
          payDay: payDay,
        );
      } else {
        final targetBalance = double.tryParse(_balanceController!.text.trim());
        if (targetBalance == null) return;
        await cubit.update(
          id: widget.card!.id,
          name: name,
          description: description,
          cutDay: cutDay,
          payDay: payDay,
          previousBalance: widget.card!.balance,
          targetBalance: targetBalance,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cutDayController,
                  decoration: InputDecoration(labelText: l10n.cardCutDay),
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateBillingDay(v, l10n),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _payDayController,
                  decoration: InputDecoration(labelText: l10n.cardPayDay),
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateBillingDay(v, l10n),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_balanceController != null) ...[
            TextFormField(
              controller: _balanceController,
              decoration: InputDecoration(labelText: l10n.accountBalance),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                if (double.tryParse(v.trim()) == null) {
                  return l10n.fieldRequired;
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
          ],
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
    final label = widget.card == null ? l10n.accountSubmitCreate : l10n.save;
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
    final title = widget.card == null ? l10n.newCard : l10n.editCard;

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
