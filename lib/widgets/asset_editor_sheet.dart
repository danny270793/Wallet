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

  late final TextEditingController _boughtDisplayController;
  late final TextEditingController _endedDisplayController;

  /// Calendar date only (midnight local).
  late DateTime _boughtAt;
  DateTime? _endedAt;
  bool _loading = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Noon local when persisting avoids timezone boundary issues vs DB timestamptz.
  static DateTime _noonLocalOn(DateTime dateOnly) =>
      DateTime(dateOnly.year, dateOnly.month, dateOnly.day, 12);

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    if (a != null) {
      _nameController = TextEditingController(text: a.name);
      _providerController = TextEditingController(text: a.provider);
      _valueController = TextEditingController(
        text: a.value.toStringAsFixed(2),
      );
      _soldController = TextEditingController(
        text: a.soldValue != null ? a.soldValue!.toStringAsFixed(2) : '',
      );
      final lb = a.boughtAt.toLocal();
      _boughtAt = _dateOnly(lb);
      _endedAt = a.endedAt == null ? null : _dateOnly(a.endedAt!.toLocal());
    } else {
      _nameController = TextEditingController();
      _providerController = TextEditingController();
      _valueController = TextEditingController(text: '0');
      _soldController = TextEditingController();
      _boughtAt = _dateOnly(DateTime.now());
    }
    _boughtDisplayController = TextEditingController();
    _endedDisplayController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncBoughtDisplay();
      _syncEndedDisplay();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _valueController.dispose();
    _soldController.dispose();
    _boughtDisplayController.dispose();
    _endedDisplayController.dispose();
    super.dispose();
  }

  void _syncBoughtDisplay() {
    final locale = Localizations.localeOf(context).toString();
    _boughtDisplayController.text = DateFormat.yMd(locale).format(_boughtAt);
  }

  void _syncEndedDisplay() {
    final e = _endedAt;
    final locale = Localizations.localeOf(context).toString();
    _endedDisplayController.text = e == null
        ? ''
        : DateFormat.yMd(locale).format(e);
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
      _boughtAt = DateTime(d.year, d.month, d.day);
      if (_endedAt != null && _endedAt!.isBefore(_boughtAt)) {
        _endedAt = null;
      }
    });
    _syncBoughtDisplay();
    _syncEndedDisplay();
  }

  Future<void> _pickEnded() async {
    final initial = _endedAt ?? _boughtAt;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _boughtAt,
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _endedAt = DateTime(d.year, d.month, d.day);
      if (_endedAt!.isBefore(_boughtAt)) {
        _endedAt = _boughtAt;
      }
    });
    _syncEndedDisplay();
  }

  void _clearEnded() {
    setState(() => _endedAt = null);
    _syncEndedDisplay();
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

    final v = double.tryParse(
      _valueController.text.trim().replaceAll(',', '.'),
    );
    if (v == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.l10n.assetInvalidNumber)));
      return;
    }

    double? sold;
    final soldText = _soldController.text.trim();
    if (soldText.isNotEmpty) {
      sold = double.tryParse(soldText.replaceAll(',', '.'));
      if (sold == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.l10n.assetInvalidNumber)));
        return;
      }
    }

    setState(() => _loading = true);
    final cubit = context.read<AssetsCubit>();
    final name = _nameController.text.trim();
    final provider = _providerController.text.trim();
    final bought = _noonLocalOn(_boughtAt);
    final end = ended == null ? null : _noonLocalOn(ended);

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

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final isCreate = widget.asset == null;
    final title = isCreate ? l10n.newAsset : l10n.editAsset;
    final submitLabel = isCreate ? l10n.accountSubmitCreate : l10n.save;

    return BottomSheetPinnedTitleScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.accountName),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.fieldRequired
                      : null,
                  autofocus: isCreate,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _providerController,
                  decoration: InputDecoration(labelText: l10n.assetProvider),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueController,
                  decoration: InputDecoration(labelText: l10n.assetValue),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (s) {
                    if (s == null || s.trim().isEmpty)
                      return l10n.fieldRequired;
                    if (double.tryParse(s.trim().replaceAll(',', '.')) ==
                        null) {
                      return l10n.assetInvalidNumber;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        enableInteractiveSelection: false,
                        showCursor: false,
                        controller: _boughtDisplayController,
                        decoration: InputDecoration(
                          labelText: l10n.assetPurchaseDate,
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                          ),
                        ),
                        onTap: _pickBought,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        enableInteractiveSelection: false,
                        showCursor: false,
                        controller: _endedDisplayController,
                        decoration: InputDecoration(
                          labelText: l10n.assetEndDate,
                          hintText: '—',
                          suffixIcon: Icon(
                            _endedAt != null
                                ? Icons.event
                                : Icons.event_outlined,
                            size: 20,
                          ),
                        ),
                        onTap: _pickEnded,
                      ),
                    ),
                    if (_endedAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).cancelButtonLabel,
                        onPressed: _clearEnded,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _soldController,
                  decoration: InputDecoration(
                    labelText: l10n.assetSoldAmountField,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
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
