import 'dart:async';
import 'dart:io';

/// Thrown when [deviceReportsOnline] is false and there is no cache to serve.
class NoDeviceConnectivityException implements Exception {
  const NoDeviceConnectivityException();
}

/// Distinguishes offline / transport failures from other remote errors for UX copy.
enum RemoteLoadFailure {
  networkUnavailable,
  requestFailed,
}

/// Classifies [error] from HTTP / Supabase / [SocketException] chains (no [BuildContext]).
RemoteLoadFailure classifyRemoteLoadError(Object error) {
  if (error is NoDeviceConnectivityException) {
    return RemoteLoadFailure.networkUnavailable;
  }
  if (error is SocketException) {
    return RemoteLoadFailure.networkUnavailable;
  }
  if (error is TimeoutException) {
    return RemoteLoadFailure.networkUnavailable;
  }
  final str = error.toString();
  const hints = <String>[
    'SocketException',
    'Failed host lookup',
    'Network is unreachable',
    'Connection refused',
    'Connection reset',
    'timed out',
    'TimeoutException',
    'HandshakeException',
    'Connection closed',
  ];
  for (final h in hints) {
    if (str.contains(h)) {
      return RemoteLoadFailure.networkUnavailable;
    }
  }
  return RemoteLoadFailure.requestFailed;
}
