import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

/// Holds the visible calendar year for the yearly dashboard (normalized to Jan 1).
class YearlyDashboardHost extends StatefulWidget {
  const YearlyDashboardHost({super.key, required this.child});

  final Widget child;

  @override
  State<YearlyDashboardHost> createState() => _YearlyDashboardHostState();
}

class _YearlyDashboardHostState extends State<YearlyDashboardHost> {
  late final ValueNotifier<DateTime> _visibleYear;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _visibleYear = ValueNotifier<DateTime>(DateTime(n.year, 1, 1));
  }

  @override
  void dispose() {
    _visibleYear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YearlyDashboardScope(
      notifier: _visibleYear,
      child: widget.child,
    );
  }
}

class YearlyDashboardScope extends InheritedNotifier<ValueNotifier<DateTime>> {
  const YearlyDashboardScope({
    super.key,
    required ValueNotifier<DateTime> super.notifier,
    required super.child,
  });

  static ValueNotifier<DateTime> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<YearlyDashboardScope>();
    assert(scope != null, 'YearlyDashboardScope not found');
    return scope!.notifier!;
  }
}

Future<void> _pickYearFromDialog(
  BuildContext context,
  ValueNotifier<DateTime> notifier,
  Locale locale,
) async {
  final displayed = notifier.value.year;
  final now = DateTime.now();
  final minYear = now.year - 150;
  final maxYear = now.year + 150;
  final picked = await showDialog<int>(
    context: context,
    builder: (context) => _YearListPickerDialog(
      initialYear: displayed,
      locale: locale,
      l10n: AppLocalizations.of(context)!,
      minYear: minYear,
      maxYear: maxYear,
    ),
  );
  if (picked != null && context.mounted) {
    notifier.value = DateTime(picked, 1, 1);
  }
}

class _YearListPickerDialog extends StatefulWidget {
  const _YearListPickerDialog({
    required this.initialYear,
    required this.locale,
    required this.l10n,
    required this.minYear,
    required this.maxYear,
  });

  final int initialYear;
  final Locale locale;
  final AppLocalizations l10n;
  final int minYear;
  final int maxYear;

  @override
  State<_YearListPickerDialog> createState() => _YearListPickerDialogState();
}

class _YearListPickerDialogState extends State<_YearListPickerDialog> {
  static const double _itemHeight = 48;
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitial());
  }

  void _scrollToInitial() {
    if (!mounted || !_controller.hasClients) return;
    final y = widget.initialYear.clamp(widget.minYear, widget.maxYear);
    final indexFromTop = widget.maxYear - y;
    final offset = (indexFromTop * _itemHeight).clamp(0.0, _controller.position.maxScrollExtent);
    _controller.jumpTo(offset);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = widget.locale.toString();
    final count = widget.maxYear - widget.minYear + 1;
    return AlertDialog(
      title: Text(widget.l10n.yearlyPickYear),
      content: SizedBox(
        width: 280,
        height: 360,
        child: ListView.builder(
          controller: _controller,
          itemExtent: _itemHeight,
          itemCount: count,
          itemBuilder: (context, index) {
            final year = widget.maxYear - index;
            final selectedHere = year == widget.initialYear;
            final primary = theme.colorScheme.primary;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop<int>(context, year),
                child: Center(
                  child: Text(
                    DateFormat.y(loc).format(DateTime(year)),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: selectedHere ? FontWeight.w700 : FontWeight.w500,
                      color: selectedHere ? primary : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Year switcher below the app bar title (same layout as [TransactionsMonthAppBarBottom], year only).
class YearlyDashboardAppBarBottom extends StatelessWidget implements PreferredSizeWidget {
  const YearlyDashboardAppBarBottom({super.key, required this.notifier});

  final ValueNotifier<DateTime> notifier;

  static int _minYear() => DateTime.now().year - 150;

  static int _maxYear() => DateTime.now().year + 150;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final minY = _minYear();
    final maxY = _maxYear();

    return ValueListenableBuilder<DateTime>(
      valueListenable: notifier,
      builder: (context, visibleYear, _) {
        final y = visibleYear.year;
        final label = DateFormat.y(locale.toString()).format(DateTime(y));
        return SizedBox(
          height: preferredSize.height,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.transactionsPickPreviousYear,
                visualDensity: VisualDensity.compact,
                onPressed: y > minY
                    ? () {
                        notifier.value = DateTime(y - 1, 1, 1);
                      }
                    : null,
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _pickYearFromDialog(context, notifier, locale),
                    customBorder: const StadiumBorder(),
                    child: Tooltip(
                      message: l10n.yearlyPickYear,
                      excludeFromSemantics: true,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.25,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.transactionsPickNextYear,
                visualDensity: VisualDensity.compact,
                onPressed: y < maxY
                    ? () {
                        notifier.value = DateTime(y + 1, 1, 1);
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
