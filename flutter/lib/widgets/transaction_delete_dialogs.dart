import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

Future<bool> confirmDeleteTransactionDialog(
  BuildContext context,
  AppLocalizations l10n,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteTransaction),
      content: Text(l10n.confirmDeleteTransaction),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<bool> confirmDeleteTransferPairDialog(
  BuildContext context,
  AppLocalizations l10n,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteTransferPair),
      content: Text(l10n.confirmDeleteTransferPair),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
