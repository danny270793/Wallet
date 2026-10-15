/// Optional leading "(n/m) " label for deferred credit installment rows.
final RegExp leadingCreditInstallmentDescriptionPrefix = RegExp(
  r'^\(\d+/\d+\)\s*',
);

/// Removes a leading "(n/m) " prefix saved on [description] (for edit UX).
String stripLeadingCreditInstallmentDescription(String? description) {
  final s = description ?? '';
  return s.replaceFirst(leadingCreditInstallmentDescriptionPrefix, '');
}

/// Stored [description] per row: "(current/total)" then optional user note.
String? creditGroupPrefixedDescription({
  required int oneBasedCurrent,
  required int total,
  String? userNote,
}) {
  if (total < 1 || oneBasedCurrent < 1) {
    throw ArgumentError(
      'creditGroupPrefixedDescription: need total>=1 and current>=1',
    );
  }
  final prefix = '($oneBasedCurrent/$total)';
  final trimmed = userNote?.trim() ?? '';
  if (trimmed.isEmpty) {
    return prefix;
  }
  return '$prefix $trimmed';
}
