/// Splits [total] into [parts] equal-ish amounts; remainder goes to the last part (2 dp).
List<double> splitEqualAmountParts(double total, int parts) {
  if (parts <= 0) {
    throw ArgumentError.value(parts, 'parts', 'must be positive');
  }
  if (parts == 1) {
    return [double.parse(total.toStringAsFixed(2))];
  }
  final step = double.parse((total / parts).toStringAsFixed(2));
  final out = List<double>.filled(parts, step);
  var sum = step * (parts - 1);
  out[parts - 1] = double.parse((total - sum).toStringAsFixed(2));
  return out;
}
