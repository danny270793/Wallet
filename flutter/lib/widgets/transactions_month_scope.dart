import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
