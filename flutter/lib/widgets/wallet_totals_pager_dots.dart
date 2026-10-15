import 'package:flutter/material.dart';

/// Minimum horizontal swipe speed (pixels per second on [DragEndDetails]) to move a
/// bottom totals bar to the next / previous page.
const double kWalletTotalsSwipeMinVelocityPxPerSec = 280;

/// Page-indicator dots for the bottom totals bars. Renders nothing when [count] is
/// below 2; [selectedIndex] is clamped to `[0, count)`.
class WalletTotalsPagerDots extends StatelessWidget {
  const WalletTotalsPagerDots({
    super.key,
    required this.count,
    required this.selectedIndex,
  });

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final safeIndex = selectedIndex.clamp(0, count - 1);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
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
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
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
