import 'package:flutter/foundation.dart';

import 'demo_data_generator.dart';
import 'demo_store.dart';

/// "Try demo" session: the app runs on fake, in-memory data generated when the
/// demo starts. Nothing reaches Supabase or the offline cache, and nothing
/// survives [exit] or an app restart.
class DemoMode extends ChangeNotifier {
  DemoMode._();

  static final DemoMode instance = DemoMode._();

  static const email = 'demo@wallet.app';

  DemoStore? _store;

  bool get isActive => _store != null;

  DemoStore get store {
    final s = _store;
    if (s == null) throw StateError('demo mode is not active');
    return s;
  }

  /// Generates a fresh data set relative to today and switches the app to it.
  void enter() {
    final s = DemoStore();
    DemoDataGenerator(s).populate();
    _store = s;
    notifyListeners();
  }

  void exit() {
    if (_store == null) return;
    _store = null;
    notifyListeners();
  }
}
