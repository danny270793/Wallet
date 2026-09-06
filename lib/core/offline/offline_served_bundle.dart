/// Value returned from a read-through offline cache: live data plus whether it was read from disk.
class OfflineServedBundle<T> {
  final T value;
  final bool servedFromOfflineCache;

  const OfflineServedBundle({
    required this.value,
    required this.servedFromOfflineCache,
  });
}
