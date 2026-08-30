import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import 'bottom_sheet_pinned_title.dart';

/// Same sheet on monthly and yearly dashboards: include ignored rows, weighted vs raw values,
/// show/hide credit-linked installments.
///
/// [onApply] is called after Save; the sheet is popped first (caller handles [setState]).
Future<void> showDashboardViewOptionsBottomSheet({
  required BuildContext context,
  required AppLocalizations l10n,
  required bool includeIgnored,
  required bool useWeightedAmounts,
  required bool showCredits,
  required void Function(
    bool includeIgnored,
    bool useWeightedAmounts,
    bool showCredits,
  ) onApply,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (sheetContext) {
      final draft = [includeIgnored, useWeightedAmounts, showCredits];

      return SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            final bottomPad = MediaQuery.paddingOf(ctx).bottom;
            return BottomSheetPinnedTitleScrollView(
              title: l10n.monthlyDashboardOptionsSheetTitle,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomPad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.dashboardIncludeIgnoredInTotals),
                    value: draft[0],
                    onChanged: (v) => setModal(() => draft[0] = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.dashboardUseWeightedAmounts),
                    value: draft[1],
                    onChanged: (v) => setModal(() => draft[1] = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.dashboardShowCredits),
                    value: draft[2],
                    onChanged: (v) => setModal(() => draft[2] = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onApply(draft[0], draft[1], draft[2]);
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
