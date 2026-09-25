import 'package:flutter/services.dart';

/// Parses a transaction amount: optional leading −, digits, optional fractional part.
/// Returns null if empty, not parseable, or not finite. If the string has a comma but no dot, the first comma is treated as the decimal separator.
double? parseDecimalAmountInput(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains(',') && !s.contains('.')) {
    s = s.replaceFirst(',', '.');
  }
  final x = double.tryParse(s);
  if (x == null || !x.isFinite) return null;
  return x;
}

/// Allows optional leading minus, digits, and at most one `.` or `,` as decimal separator.
final class DecimalAmountInputFormatter extends TextInputFormatter {
  const DecimalAmountInputFormatter({this.allowNegative = true});

  final bool allowNegative;

  static String _filter(String input, {required bool allowNegative}) {
    if (input.isEmpty) return input;
    final buf = StringBuffer();
    var hasSep = false;
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (allowNegative && c == '-' && i == 0) {
        buf.write(c);
        continue;
      }
      final u = c.codeUnitAt(0);
      if (u >= 0x30 && u <= 0x39) {
        buf.write(c);
        continue;
      }
      if ((c == '.' || c == ',') && !hasSep) {
        buf.write(c);
        hasSep = true;
      }
    }
    return buf.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = _filter(newValue.text, allowNegative: allowNegative);
    if (filtered == newValue.text) return newValue;
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final mapped = _filter(
      newValue.text.substring(0, end),
      allowNegative: allowNegative,
    ).length;
    final off = mapped.clamp(0, filtered.length);
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: off),
    );
  }
}
