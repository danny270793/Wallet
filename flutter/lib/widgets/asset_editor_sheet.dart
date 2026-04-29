import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../features/assets/domain/entities/asset_entity.dart';
import '../features/assets/presentation/cubit/assets_cubit.dart';
import 'bottom_sheet_pinned_title.dart';

Future<void> showAssetEditorBottomSheet(
  BuildContext context,
  AppLocalizations l10n, {
  AssetsCubit? cubit,
  AssetEntity? asset,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) {
      final child = AssetEditorSheet(l10n: l10n, asset: asset);
      return cubit != null
          ? BlocProvider.value(value: cubit, child: child)
          : BlocProvider(create: (_) => getIt<AssetsCubit>(), child: child);
    },
  );
}

class AssetEditorSheet extends StatefulWidget {
  const AssetEditorSheet({super.key, required this.l10n, this.asset});

  final AppLocalizations l10n;
  final AssetEntity? asset;

  @override
  State<AssetEditorSheet> createState() => _AssetEditorSheetState();
}

class _AssetEditorSheetState extends State<AssetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _providerController;
  late final TextEditingController _valueController;
  late final TextEditingController _soldController;
  late DateTime _boughtAt;
  DateTime? _endedAt;
  bool _loading = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    if (a != null) {
      _nameController = TextEditingController(text: a.name);
      _providerController = TextEditingController(text: a.provider);
      _valueController = TextEditingController(text: a.value.toStringAsFixed(2));
      _soldController = TextEditingController(
        text: a.soldValue != null ? a.soldValue!.toStringAsFixed(2) : '',
      );
      _boughtAt = _dateOnly(a.boughtAt);
      _endedAt = a.endedAt == null ? null : _dateOnly(a.endedAt!);
    } else {
      _nameController = TextEditingController();
      _providerController = TextEditingController();
      _valueController = TextEditingController(text: '0');
      _soldController = TextEditingController();
      _boughtAt = _dateOnly(DateTime.now());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _valueController.dispose();
    _soldController.dispose();
    super.dispose();
  }

  Future<void> _pickBought() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _boughtAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _boughtAt = _dateOnly(d);
      if (_endedAt != null && _endedAt!.isBefore(_boughtAt)) {
        _endedAt = null;
      }
    });
  }

  Future<void> _pickEnded() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endedAt ?? _boughtAt,
      firstDate: _boughtAt,
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => _endedAt = _dateOnly(d));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ended = _endedAt;
    if (ended != null && ended.isBefore(_boughtAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.assetEndBeforePurchase)),
      );
      return;
    }

    final v = double.tryParse(_valueController.text.trim().replaceAll(',', '.'));
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.assetInvalidNumber)),
      );
      return;
    }

    double? sold;
    final soldText = _soldController.text.trim();
    if (soldText.isNotEmpty) {
      sold = double.tryParse(soldText.replaceAll(',', '.'));
      if (sold == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.assetInvalidNumber)),
        );
        return;
      }
    }

    setState(() => _loading = true);
    final cubit = context.read<AssetsCubit>();
    final name = _nameController.text.trim();
    final provider = _providerController.text.trim();
    final bought = DateTime(_boughtAt.year, _boughtAt.month, _boughtAt.day, 12);
    final end = ended == null
        ? null
        : DateTime(ended.year, ended.month, ended.day, 12);
    try {
      final existing = widget.asset;
      if (existing == null) {
        await cubit.create(
          name: name,
          provider: provider,
          value: v,
          boughtAt: bought,
          endedAt: end,
          soldValue: sold,
        );
      } else {
        await cubit.update(
          id: existing.id,
          name: name,
          provider: provider,
          value: v,
          boughtAt: bought,
          endedAt: end,
          soldValue: sold,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          suffixIcon: onClear != null
              ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
              : null,
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }

  Widget _formFields(AppLocalizations l10n) {
    final dateFmt = DateFormat.yMMMd();
    final isCreate = widget.asset == null;
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
            autofocus: isCreate,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _providerController,
            decoration: InputDecoration(labelText: l10n.assetProvider),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _valueController,
            decoration: InputDecoration(labelText: l10n.assetValue),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: (s) {
              if (s == null || s.trim().isEmpty) return l10n.fieldRequired;
              if (double.tryParse(s.trim().replaceAll(',', '.')) == null) {
                return l10n.assetInvalidNumber;
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          _buildField(
            icon: Icons.calendar_today_outlined,
            label: l10n.assetPurchaseDate,
            value: dateFmt.format(_boughtAt),
            onTap: _pickBought,
          ),
          const SizedBox(height: 8),
          _buildField(
            icon: Icons.event_outlined,
            label: l10n.assetEndDate,
            value: _endedAt == null ? '—' : dateFmt.format(_endedAt!),
            onTap: _pickEnded,
            onClear: _endedAt == null
                ? null
                : () => setState(() => _endedAt = null),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _soldController,
            decoration: InputDecoration(labelText: l10n.assetSoldAmountField),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final isCreate = widget.asset == null;
    final title = isCreate ? l10n.newAsset : l10n.editAsset;
    final submitLabel =
        isCreate ? l10n.accountSubmitCreate : l10n.save;

    return BottomSheetPinnedTitleScrollView(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _formFields(l10n),
          const SizedBox(height: 24),
          SizedBox(
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
                  : Text(submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
