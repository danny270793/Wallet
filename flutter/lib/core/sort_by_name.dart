/// Sorts a **copy** of [items] by [nameOf] using case-insensitive comparison.
List<T> sortedByName<T>(List<T> items, String Function(T) nameOf) {
  final out = List<T>.of(items);
  out.sort(
    (a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()),
  );
  return out;
}

/// Visible items first (A–Z), then hidden items (A–Z).
List<T> sortedVisibleThenByName<T>(
  List<T> items, {
  required String Function(T) nameOf,
  required bool Function(T) isHidden,
}) {
  final out = List<T>.of(items);
  out.sort((a, b) {
    final hiddenCmp = (isHidden(a) ? 1 : 0).compareTo(isHidden(b) ? 1 : 0);
    if (hiddenCmp != 0) return hiddenCmp;
    return nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());
  });
  return out;
}
