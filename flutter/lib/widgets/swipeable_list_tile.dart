import 'package:flutter/material.dart';

/// Row actions via horizontal swipe only (no tap on the row).
///
/// LTR: swipe **right → left** (finger moves left) = [onEdit] (row stays).
/// Swipe **left → right** = [confirmDelete] then [onDelete]; row dismisses only if both succeed.
class SwipeableListTile extends StatelessWidget {
  const SwipeableListTile({
    super.key,
    required this.itemKey,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.tileIsThreeLine = false,
    this.dense = false,
    this.minLeadingWidth,
    this.horizontalTitleGap,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    required this.onEdit,
    required this.confirmDelete,
    required this.onDelete,
  });

  final String itemKey;
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// When false, tile uses disabled colors (e.g. ignored transactions).
  final bool enabled;

  /// Passed to inner [ListTile.isThreeLine].
  final bool tileIsThreeLine;

  /// Passed to inner [ListTile.dense].
  final bool dense;

  /// Passed to inner [ListTile.minLeadingWidth] when non-null.
  final double? minLeadingWidth;

  /// Passed to inner [ListTile.horizontalTitleGap] when non-null.
  final double? horizontalTitleGap;

  /// Passed to inner [ListTile.contentPadding].
  final EdgeInsetsGeometry contentPadding;

  final VoidCallback onEdit;

  /// Return true to allow delete dismiss after user confirms in dialog.
  final Future<bool> Function() confirmDelete;

  /// Runs after [confirmDelete] returns true. Return false to keep the row (e.g. server delete failed).
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);

    final tile = ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      enabled: enabled,
      isThreeLine: tileIsThreeLine,
      dense: dense,
      minLeadingWidth: minLeadingWidth,
      horizontalTitleGap: horizontalTitleGap,
      contentPadding: contentPadding,
      shape: RoundedRectangleBorder(borderRadius: radius),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Dismissible(
        key: ValueKey('swipe_$itemKey'),
        direction: DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.startToEnd: _kDismissThreshold,
          DismissDirection.endToStart: _kDismissThreshold,
        },
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            onEdit();
            return false;
          }
          if (direction == DismissDirection.startToEnd) {
            if (!await confirmDelete()) return false;
            return await onDelete();
          }
          return false;
        },
        onDismissed: (_) {},
        movementDuration: const Duration(milliseconds: 260),
        background: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: radius,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.onErrorContainer,
                size: 28,
              ),
            ),
          ),
        ),
        secondaryBackground: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: radius,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Icon(
                Icons.edit_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
          ),
        ),
        child: tile,
      ),
    );
  }
}

/// Slightly lower than default so short swipes still register.
const double _kDismissThreshold = 0.28;
