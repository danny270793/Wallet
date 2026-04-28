import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

/// Holds the visible month for the transactions route; ancestor of both [AppShell] and body so the app bar can read it.
class TransactionsMonthHost extends StatefulWidget {
  const TransactionsMonthHost({super.key, required this.child});

  final Widget child;

  @override
  State<TransactionsMonthHost> createState() => _TransactionsMonthHostState();
}

class _TransactionsMonthHostState extends State<TransactionsMonthHost> {
  late final ValueNotifier<DateTime> _visibleMonth;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _visibleMonth = ValueNotifier<DateTime>(DateTime(n.year, n.month, 1));
  }

  @override
  void dispose() {
    _visibleMonth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TransactionsMonthScope(
      notifier: _visibleMonth,
      child: widget.child,
    );
  }
}

/// Rebuild subtree when [ValueNotifier<DateTime>] (visible month) changes.
class TransactionsMonthScope extends InheritedNotifier<ValueNotifier<DateTime>> {
  const TransactionsMonthScope({
    super.key,
    required ValueNotifier<DateTime> super.notifier,
    required super.child,
  });

  static ValueNotifier<DateTime> of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TransactionsMonthScope>();
    assert(scope != null, 'TransactionsMonthScope not found');
    return scope!.notifier!;
  }

  static ValueNotifier<DateTime>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TransactionsMonthScope>()
        ?.notifier;
  }
}

Future<void> _pickMonthYear(
  BuildContext context,
  ValueNotifier<DateTime> notifier,
  Locale locale,
) async {
  final displayed = notifier.value;
  final now = DateTime.now();
  final minYear = now.year - 150;
  final maxYear = now.year + 150;
  final picked = await showDialog<DateTime>(
    context: context,
    builder: (context) => _MonthYearPickerDialog(
      initial: displayed,
      locale: locale,
      l10n: AppLocalizations.of(context)!,
      minYear: minYear,
      maxYear: maxYear,
    ),
  );
  if (picked != null && context.mounted) {
    notifier.value = picked;
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({
    required this.initial,
    required this.locale,
    required this.l10n,
    required this.minYear,
    required this.maxYear,
  });

  final DateTime initial;
  final Locale locale;
  final AppLocalizations l10n;
  final int minYear;
  final int maxYear;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _year = i.year.clamp(widget.minYear, widget.maxYear);
  }

  String _monthAbbrev(int monthIndex1Based) {
    final loc = widget.locale.toString();
    return DateFormat.MMM(loc).format(DateTime(2000, monthIndex1Based));
  }

  bool _isInitiallySelectedMonth(int month) {
    final i = widget.initial;
    return i.year == _year && i.month == month;
  }

  void _previousYear() {
    if (_year > widget.minYear) setState(() => _year--);
  }

  void _nextYear() {
    if (_year < widget.maxYear) setState(() => _year++);
  }

  void _selectMonth(int month) {
    Navigator.pop<DateTime>(
      context,
      DateTime(_year, month, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: null,
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: widget.l10n.transactionsPickPreviousYear,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _year > widget.minYear ? _previousYear : null,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Opacity(
                              opacity: _year > widget.minYear ? 1 : 0.35,
                              child: Icon(
                                Icons.keyboard_double_arrow_left,
                                color: theme.colorScheme.onSurface,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: widget.l10n.transactionsPickNextYear,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _year < widget.maxYear ? _nextYear : null,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Opacity(
                              opacity: _year < widget.maxYear ? 1 : 0.35,
                              child: Icon(
                                Icons.keyboard_double_arrow_right,
                                color: theme.colorScheme.onSurface,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final m = index + 1;
                final selectedHere = _isInitiallySelectedMonth(m);
                final primary = theme.colorScheme.primary;
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: selectedHere
                        ? BorderSide(color: primary, width: 2)
                        : BorderSide.none,
                  ),
                  onPressed: () => _selectMonth(m),
                  child: Text(
                    _monthAbbrev(m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight:
                          selectedHere ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Month switcher in [AppBar.bottom] (below the route title, still part of the app bar).
class TransactionsMonthAppBarBottom extends StatelessWidget implements PreferredSizeWidget {
  const TransactionsMonthAppBarBottom({super.key, required this.notifier});

  final ValueNotifier<DateTime> notifier;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final locales = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    return ValueListenableBuilder<DateTime>(
      valueListenable: notifier,
      builder: (context, visibleMonth, _) {
        final label = DateFormat.yMMMM(locale.toString()).format(visibleMonth);
        return SizedBox(
          height: preferredSize.height,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: locales.previousMonthTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final v = notifier.value;
                  notifier.value = DateTime(v.year, v.month - 1, 1);
                },
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _pickMonthYear(context, notifier, locale),
                    customBorder: const StadiumBorder(),
                    child: Tooltip(
                      message: AppLocalizations.of(context)!.transactionsPickMonth,
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
                tooltip: locales.nextMonthTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final v = notifier.value;
                  notifier.value = DateTime(v.year, v.month + 1, 1);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
