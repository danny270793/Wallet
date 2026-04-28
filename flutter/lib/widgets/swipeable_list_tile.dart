import 'package:flutter/material.dart';

/// Row actions via horizontal swipe only (no tap on the row).
///
/// LTR: swipe **right → left** (finger moves left) = [onEdit] (row stays).
/// Swipe **left → right** = [confirmDelete]; if true, row dismisses and [onDeleted] runs.
class SwipeableListTile extends StatelessWidget {
  const SwipeableListTile({
    super.key,
    required this.itemKey,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.onEdit,
    required this.confirmDelete,
    required this.onDeleted,
  });

  final String itemKey;
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback onEdit;
  /// Return true to allow delete dismiss after user confirms in dialog.
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);

    final tile = ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
            return await confirmDelete();
          }
          return false;
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.startToEnd) {
            onDeleted();
          }
        },
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
              child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer, size: 28),
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
              child: Icon(Icons.edit_rounded, color: theme.colorScheme.onPrimaryContainer, size: 28),
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

/// Decorative leading circle with the first letter of [name].
CircleAvatar initialsAvatar(BuildContext context, String name, {double radius = 20}) {
  final theme = Theme.of(context);
  final trimmed = name.trim();
  final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  return CircleAvatar(
    radius: radius,
    backgroundColor: theme.colorScheme.primaryContainer,
    foregroundColor: theme.colorScheme.onPrimaryContainer,
    child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
