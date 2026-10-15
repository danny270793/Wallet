import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/remote_load_failure.dart';

extension RemoteLoadFailureL10n on RemoteLoadFailure {
  String title(AppLocalizations l10n) => switch (this) {
    RemoteLoadFailure.networkUnavailable => l10n.loadFailedNoConnectionTitle,
    RemoteLoadFailure.requestFailed => l10n.loadFailedRequestFailedTitle,
  };

  String body(AppLocalizations l10n) => switch (this) {
    RemoteLoadFailure.networkUnavailable => l10n.loadFailedNoConnectionBody,
    RemoteLoadFailure.requestFailed => l10n.loadFailedRequestFailedBody,
  };

  IconData get icon => switch (this) {
    RemoteLoadFailure.networkUnavailable => Icons.wifi_off_rounded,
    RemoteLoadFailure.requestFailed => Icons.cloud_off_outlined,
  };
}

/// Pull-to-refresh + alert-style card for failed initial / reload remote fetches.
class RemoteLoadFailurePanel extends StatelessWidget {
  final EdgeInsetsGeometry listPadding;

  const RemoteLoadFailurePanel({
    super.key,
    required this.l10n,
    required this.failure,
    required this.onRetry,
    this.listPadding = const EdgeInsets.all(24),
  });

  final AppLocalizations l10n;
  final RemoteLoadFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: listPadding,
        children: [
          Card(
            elevation: 0,
            color: scheme.errorContainer.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(failure.icon, size: 28, color: scheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          failure.title(l10n),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    failure.body(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
