import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the OS reports any active data path (Wi‑Fi, cellular, ethernet, etc.).
/// When this is false, both Wi‑Fi and mobile data are typically off.
///
/// An empty result is treated as unknown so we still attempt the remote call.
Future<bool> deviceReportsOnline() async {
  final results = await Connectivity().checkConnectivity();
  if (results.isEmpty) return true;
  return results.any((r) => r != ConnectivityResult.none);
}
