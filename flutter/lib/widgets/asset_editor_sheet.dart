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

  late final TextEditingController _boughtDateDisplayController;
  late final TextEditingController _boughtTimeDisplayController;
  late final TextEditingController _endedDateDisplayController;
  late final TextEditingController _endedTimeDisplayController;

  /// Local wall time (matches transaction picker behavior).
  late DateTime _boughtAt;
  DateTime? _endedAt;
  bool _loading = false;

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
      _boughtAt = a.boughtAt.toLocal();
      _endedAt = a.endedAt?.toLocal();
    } else {
      _nameController = TextEditingController();
      _providerController = TextEditingController();
      _valueController = TextEditingController(text: '0');
      _soldController = TextEditingController();
      _boughtAt = DateTime.now();
    }
    _boughtDateDisplayController = TextEditingController();
    _boughtTimeDisplayController = TextEditingController();
    _endedDateDisplayController = TextEditingController();
    _endedTimeDisplayController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncBoughtDateTimeDisplay();
      _syncEndedDateTimeDisplay();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _valueController.dispose();
    _soldController.dispose();
    _boughtDateDisplayController.dispose();
    _boughtTimeDisplayController.dispose();
    _endedDateDisplayController.dispose();
    _endedTimeDisplayController.dispose();
    super.dispose();
  }

  void _syncBoughtDateTimeDisplay() {
    final locale = Localizations.localeOf(context).toString();
    _boughtDateDisplayController.text = DateFormat.yMd(locale).format(_boughtAt);
    _boughtTimeDisplayController.text = DateFormat.Hm(locale).format(_boughtAt);
  }

  void _syncEndedDateTimeDisplay() {
    final e = _endedAt;
    final locale = Localizations.localeOf(context).toString();
    if (e == null) {
      _endedDateDisplayController.text = '';
      _endedTimeDisplayController.text = '';
    } else {
      _endedDateDisplayController.text = DateFormat.yMd(locale).format(e);
      _endedTimeDisplayController.text = DateFormat.Hm(locale).format(e);
    }
  }

  Future<void> _pickBoughtDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _boughtAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _boughtAt = DateTime(
        d.year,
        d.month,
        d.day,
        _boughtAt.hour,
        _boughtAt.minute,
      );
      if (_endedAt != null && _endedAt!.isBefore(_boughtAt)) {
        _endedAt = null;
      }
    });
    _syncBoughtDateTimeDisplay();
    _syncEndedDateTimeDisplay();
  }

  Future<void> _pickBoughtTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_boughtAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _boughtAt = DateTime(
        _boughtAt.year,
        _boughtAt.month,
        _boughtAt.day,
        time.hour,
        time.minute,
      );
      if (_endedAt != null && _endedAt!.isBefore(_boughtAt)) {
        _endedAt = null;
      }
    });
    _syncBoughtDateTimeDisplay();
    _syncEndedDateTimeDisplay();
  }

  Future<void> _pickEndedDate() async {
    final initial = _endedAt ?? _boughtAt;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_boughtAt.year, _boughtAt.month, _boughtAt.day),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;

    final hour = (_endedAt ?? _boughtAt).hour;
    final minute = (_endedAt ?? _boughtAt).minute;
    setState(() {
      _endedAt = DateTime(d.year, d.month, d.day, hour, minute);
      if (_endedAt!.isBefore(_boughtAt)) {
        _endedAt = _boughtAt;
      }
    });
    _syncEndedDateTimeDisplay();
  }

  Future<void> _pickEndedTime() async {
    if (_endedAt == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.assetPickEndDateFirst)),
      );
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endedAt!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _endedAt = DateTime(
        _endedAt!.year,
        _endedAt!.month,
        _endedAt!.day,
        time.hour,
        time.minute,
      );
      if (_endedAt!.isBefore(_boughtAt)) {
        _endedAt = _boughtAt;
      }
    });
    _syncEndedDateTimeDisplay();
  }

  void _clearEnded() {
    setState(() => _endedAt = null);
    _syncEndedDateTimeDisplay();
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
    try {
      final existing = widget.asset;
      if (existing == null) {
        await cubit.create(
          name: name,
          provider: provider,
          value: v,
          boughtAt: _boughtAt,
          endedAt: ended,
          soldValue: sold,
        );
      } else {
        await cubit.update(
          id: existing.id,
          name: name,
          provider: provider,
          value: v,
          boughtAt: _boughtAt,
          endedAt: ended,
          soldValue: sold,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _formFields(AppLocalizations l10n) {
    final isCreate = widget.asset == null;

    Widget dateTimeRow({
      required TextEditingController dateController,
      required TextEditingController timeController,
      required VoidCallback onDate,
      required VoidCallback onTime,
      List<Widget>? trailing,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              readOnly: true,
              enableInteractiveSelection: false,
              showCursor: false,
              controller: dateController,
              decoration: InputDecoration(
                labelText: l10n.transferDateLabel,
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              ),
              onTap: onDate,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              readOnly: true,
              enableInteractiveSelection: false,
              showCursor: false,
              controller: timeController,
              decoration: InputDecoration(
                labelText: l10n.transferTimeLabel,
                suffixIcon: const Icon(Icons.schedule, size: 20),
              ),
              onTap: onTime,
            ),
          ),
          ...?trailing,
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.accountName),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
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
          const SizedBox(height: 16),
          Text(
            l10n.assetPurchaseDate,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          dateTimeRow(
            dateController: _boughtDateDisplayController,
            timeController: _boughtTimeDisplayController,
            onDate: _pickBoughtDate,
            onTime: _pickBoughtTime,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.assetEndDate,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          dateTimeRow(
            dateController: _endedDateDisplayController,
            timeController: _endedTimeDisplayController,
            onDate: _pickEndedDate,
            onTime: _pickEndedTime,
            trailing: [
              if (_endedAt != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                  onPressed: _clearEnded,
                ),
            ],
          ),
          const SizedBox(height: 12),
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
    final submitLabel = isCreate ? l10n.accountSubmitCreate : l10n.save;

    return BottomSheetPinnedTitleScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
