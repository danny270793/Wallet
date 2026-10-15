import 'package:flutter/material.dart';

/// Lets the user pick a day of month (1–30); null when cancelled.
Future<int?> showDayOfMonthPicker(
  BuildContext context, {
  required String title,
  int? selected,
}) => showDialog<int>(
  context: context,
  builder: (_) => _DayOfMonthPickerDialog(title: title, selected: selected),
);

/// Grid of days 1–30; pops with the tapped day.
class _DayOfMonthPickerDialog extends StatelessWidget {
  const _DayOfMonthPickerDialog({required this.title, this.selected});

  final String title;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: SizedBox(
        width: 7 * 44,
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var day = 1; day <= 30; day++)
              day == selected
                  ? IconButton.filled(
                      onPressed: () => Navigator.of(context).pop(day),
                      icon: Text('$day'),
                    )
                  : IconButton(
                      onPressed: () => Navigator.of(context).pop(day),
                      icon: Text(
                        '$day',
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
