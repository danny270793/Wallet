/// Sorts a **copy** of [items] by [nameOf] using case-insensitive comparison.
List<T> sortedByName<T>(List<T> items, String Function(T) nameOf) {
  final out = List<T>.of(items);
  out.sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
  return out;
}
