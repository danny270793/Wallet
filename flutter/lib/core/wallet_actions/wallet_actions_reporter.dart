import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wallet_actions_datasource.dart';

/// Records errors and custom events to `wallet_actions` (best-effort; never throws to callers).
class WalletActionsReporter {
  WalletActionsReporter({
    required WalletActionsDatasource datasource,
    SupabaseClient? supabase,
  })  : _datasource = datasource,
        _supabase = supabase ?? Supabase.instance.client;

  final WalletActionsDatasource _datasource;
  final SupabaseClient _supabase;

  static const _maxStackLength = 24000;
  static const _maxMessageLength = 8000;

  String? _cachedVersion;
  Future<String>? _versionFuture;

  Future<String> _appVersion() {
    if (_cachedVersion != null) return Future.value(_cachedVersion);
    _versionFuture ??= PackageInfo.fromPlatform().then((info) {
      final v = '${info.version}+${info.buildNumber}';
      _cachedVersion = v;
      return v;
    }).catchError((_) {
      _cachedVersion = 'unknown';
      return _cachedVersion!;
    });
    return _versionFuture!;
  }

  String _osLabel() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  String? _currentUserId() => _supabase.auth.currentUser?.id;

  String _trim(String? s, int max) {
    if (s == null) return '';
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…(truncated)';
  }

  Future<void> _safeInsert({
    required String type,
    String? customTitle,
    Map<String, dynamic>? customPayload,
    String? errorMessage,
    String? errorStack,
  }) async {
    try {
      final version = await _appVersion();
      await _datasource.insert(
        type: type,
        customTitle: customTitle,
        customPayload: customPayload,
        errorMessage: errorMessage != null && errorMessage.isNotEmpty ? errorMessage : null,
        errorStack: errorStack != null && errorStack.isNotEmpty ? errorStack : null,
        appVersion: version,
        userId: _currentUserId(),
        os: _osLabel(),
      );
    } catch (_) {
      // Avoid recursion into logging failures.
    }
  }

  /// Use in `catch` blocks: [error] and [stackTrace] from the catch clause.
  void recordCaught(Object error, StackTrace? stackTrace) {
    unawaited(_safeInsert(
      type: 'error',
      errorMessage: _trim(error.toString(), _maxMessageLength),
      errorStack: _trim(stackTrace?.toString(), _maxStackLength),
    ));
  }

  /// Like [recordCaught] but prefixes a log/context line (e.g. from [AppLogger.error]).
  void recordCaughtWithContext(String context, Object error, StackTrace? stackTrace) {
    final msg = context.isEmpty
        ? error.toString()
        : '${_trim(context, 2000)}: $error';
    unawaited(_safeInsert(
      type: 'error',
      errorMessage: _trim(msg, _maxMessageLength),
      errorStack: _trim(stackTrace?.toString(), _maxStackLength),
    ));
  }

  /// [message] plus optional [stackTrace] when no exception object exists.
  void recordErrorMessage(String message, [StackTrace? stackTrace]) {
    unawaited(_safeInsert(
      type: 'error',
      errorMessage: _trim(message, _maxMessageLength),
      errorStack: _trim(stackTrace?.toString(), _maxStackLength),
    ));
  }

  /// Flutter framework error (e.g. build/layout); call from [FlutterError.onError].
  void recordFlutterError(FlutterErrorDetails details) {
    unawaited(_safeInsert(
      type: 'error',
      errorMessage: _trim(details.exceptionAsString(), _maxMessageLength),
      errorStack: _trim(details.stack?.toString(), _maxStackLength),
    ));
  }

  /// Async / isolate uncaught error; use from [PlatformDispatcher.onError].
  void recordUncaught(Object error, StackTrace stack) {
    recordCaught(error, stack);
  }

  /// Custom analytic or diagnostic event (not necessarily an exception).
  void recordCustom({required String title, Map<String, dynamic>? payload}) {
    unawaited(_safeInsert(
      type: 'custom',
      customTitle: _trim(title, 512),
      customPayload: payload,
    ));
  }
}
