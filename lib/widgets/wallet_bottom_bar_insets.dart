import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Extra bottom inset for pinned [ShellScaffold] footer bars above the home
/// indicator / gesture area. Caps [MediaQuery.padding] so spacing stays tighter than
/// a full [SafeArea] bottom.
double walletBottomBarExtraBottomInset(BuildContext context) {
  final b = MediaQuery.paddingOf(context).bottom;
  if (b <= 0) return 0;
  return math.min(b, 10);
}
