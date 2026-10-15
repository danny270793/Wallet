import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/logger/app_logger.dart';

/// Logs [error] (printed to the terminal in debug builds) and shows the generic
/// error snack bar with a "See more" action that opens [showErrorDetailsDialog].
void showErrorSnackBar(
  BuildContext context,
  AppLocalizations l10n, {
  required String logMessage,
  required Object error,
  StackTrace? stackTrace,
}) {
  AppLogger.error(logMessage, error, stackTrace);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.unexpectedError),
      action: SnackBarAction(
        label: l10n.errorSeeMore,
        onPressed: () => showErrorDetailsDialog(
          context,
          l10n,
          action: logMessage,
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    ),
  );
}

/// Message, type, server details (for Supabase errors) and stack trace, with copy.
Future<void> showErrorDetailsDialog(
  BuildContext context,
  AppLocalizations l10n, {
  required String action,
  required Object error,
  StackTrace? stackTrace,
}) {
  final details = errorDetailsText(
    action: action,
    error: error,
    stackTrace: stackTrace,
  );
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.errorDetailsTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              details,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: details)),
            child: Text(l10n.errorCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).closeButtonLabel,
            ),
          ),
        ],
      );
    },
  );
}

String errorDetailsText({
  required String action,
  required Object error,
  StackTrace? stackTrace,
}) {
  final b = StringBuffer()
    ..writeln('When: ${DateTime.now().toIso8601String()}')
    ..writeln('Action: $action')
    ..writeln('Type: ${error.runtimeType}');
  if (error is PostgrestException) {
    b
      ..writeln('Message: ${error.message}')
      ..writeln('Code: ${error.code}')
      ..writeln('Details: ${error.details}')
      ..writeln('Hint: ${error.hint}');
  } else if (error is AuthException) {
    b
      ..writeln('Message: ${error.message}')
      ..writeln('Status: ${error.statusCode}');
  } else {
    b.writeln('Message: $error');
  }
  if (stackTrace != null) {
    b
      ..writeln()
      ..writeln('Stack trace:')
      ..write(stackTrace);
  }
  return b.toString().trimRight();
}
