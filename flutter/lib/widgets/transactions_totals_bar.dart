import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import 'wallet_dual_balance_trailing.dart';

/// Swipe horizontally (with enough speed) on the totals bar to move to next ([forward] true)
/// or previous ([forward] false) mode.
typedef TransactionsTotalsModeSwipe = void Function(bool forward);

/// Minimum horizontal swipe speed (pixels per second on [DragEndDetails]) to cycle mode.
const double kTransactionsTotalsSwipeMinVelocityPxPerSec = 280;

/// Bottom summary: income (sum of positive amounts), outcome (sum of absolute negatives),
/// net balance. Transfer legs ([TransactionEntity.isAccountTransferLeg]) are not included upstream.
/// When [totalsDotsCount] is at least 2, shows page-indicator dots beneath the Income / Outcome / Balance row;
/// highlight follows [totalsDotsSelectedIndex] (typically the same index as totals mode).
class TransactionsTotalsBar extends StatelessWidget {
  const TransactionsTotalsBar({
    super.key,
    required this.l10n,
    required this.income,
    required this.outcome,
    required this.balance,
    this.primarySubtitle,
    this.secondaryIncome,
    this.secondaryOutcome,
    this.secondaryBalance,
    this.secondarySubtitle,
    this.onTotalsModeSwipe,
    this.totalsDotsCount = 0,
    this.totalsDotsSelectedIndex = 0,
  });

  final AppLocalizations l10n;
  final double income;
  final double outcome;
  final double balance;
  final String? primarySubtitle;
  final double? secondaryIncome;
  final double? secondaryOutcome;
  final double? secondaryBalance;
  final String? secondarySubtitle;
  final TransactionsTotalsModeSwipe? onTotalsModeSwipe;

  /// When ≥ 2, shows pager dots under Income / Outcome / Balance.
  /// Index [totalsDotsSelectedIndex] is clamped to `[0, totalsDotsCount)`.
  final int totalsDotsCount;
  final int totalsDotsSelectedIndex;

  bool get _hasSecondary =>
      secondaryIncome != null &&
      secondaryOutcome != null &&
      secondaryBalance != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget row(double inc, double out, double bal, {required bool compact}) {
      final amountStyle = compact
          ? theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            )
          : theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
      final labelStyle = theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      );

      Widget column(String amount, String label, Color amountColor) {
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                textAlign: TextAlign.center,
                style: amountStyle?.copyWith(color: amountColor),
              ),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: labelStyle),
            ],
          ),
        );
      }

      final incStr = l10n.transactionAmountValue(inc.toStringAsFixed(2));
      final outStr = l10n.transactionAmountValue(out.toStringAsFixed(2));
      final balStr = l10n.transactionAmountValue(bal.toStringAsFixed(2));

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column(incStr, l10n.transactionsTotalIncome, const Color(0xFF1B8736)),
          column(
            outStr,
            l10n.transactionsTotalOutcome,
            theme.colorScheme.error,
          ),
          column(
            balStr,
            l10n.transactionsTotalBalance,
            walletListBalanceColor(theme, bal),
          ),
        ],
      );
    }

    final dotsRow = _totalsDotsRow(theme);

    return GestureDetector(
      onHorizontalDragEnd: onTotalsModeSwipe == null
          ? null
          : (details) {
              final vx = details.velocity.pixelsPerSecond.dx;
              if (vx.abs() < kTransactionsTotalsSwipeMinVelocityPxPerSec) {
                return;
              }
              // Leftward drag (negative vx) moves to next option (LTR pattern).
              onTotalsModeSwipe!(vx < 0);
            },
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (primarySubtitle != null) ...[
                    Text(
                      primarySubtitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  row(income, outcome, balance, compact: false),
                  if (dotsRow != null) ...[
                    const SizedBox(height: 10),
                    dotsRow,
                  ],
                  if (_hasSecondary) ...[
                    Divider(
                      height: 20,
                      thickness: 1,
                      color: theme.dividerColor,
                    ),
                    if (secondarySubtitle != null) ...[
                      Text(
                        secondarySubtitle!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    row(
                      secondaryIncome!,
                      secondaryOutcome!,
                      secondaryBalance!,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _totalsDotsRow(ThemeData theme) {
    if (totalsDotsCount < 2) return null;
    final scheme = theme.colorScheme;
    final safeIndex = totalsDotsSelectedIndex.clamp(
      0,
      totalsDotsCount > 1 ? totalsDotsCount - 1 : 0,
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalsDotsCount, (i) {
          final isOn = i == safeIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: isOn ? 9 : 7,
              height: isOn ? 9 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? scheme.primary : Colors.transparent,
                border: isOn
                    ? null
                    : Border.all(
                        color:
                            scheme.onSurfaceVariant.withValues(alpha: 0.42),
                        width: 1.25,
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
