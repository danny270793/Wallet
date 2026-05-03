import 'package:flutter/material.dart';

/// Shared [IconData] for consistent toolbars across the app.
abstract final class AppIcons {
  AppIcons._();

  /// Refine which data is shown (chart slices, dashboard view options, etc.).
  static const IconData filter = Icons.filter_list_rounded;
}
