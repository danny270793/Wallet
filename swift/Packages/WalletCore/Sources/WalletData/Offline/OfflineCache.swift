import Foundation
import Network
import WalletCore

/// One on-disk JSON cache file.
public struct CacheEntry: Identifiable, Hashable, Sendable {
  public var key: String
  public var bytes: Int
  public var modifiedAt: Date
  public var id: String { key }
}

/// JSON file cache under Application Support, one folder per user id.
/// Same layout as the Flutter app: `wallet_offline_cache/<userId>/<key>.json`.
public actor OfflineCache {
  public static let shared = OfflineCache()

  private let root: URL

  public init(root: URL? = nil) {
    self.root =
      root
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("wallet_offline_cache", isDirectory: true)
  }

  private struct ListFile<T: Codable>: Codable { var items: [T] }
  private struct ItemFile<T: Codable>: Codable { var item: T }

  private func file(_ user: String, _ key: String) throws -> URL {
    let safe = key.replacingOccurrences(of: #"[^a-zA-Z0-9_\-\.]"#, with: "_", options: .regularExpression)
    let dir = root.appendingPathComponent(user, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("\(safe).json")
  }

  public func saveList<T: Codable & Sendable>(_ items: [T], user: String?, key: String) {
    guard let user, !user.isEmpty else { return }
    do {
      try WalletJSON.encoder.encode(ListFile(items: items)).write(to: file(user, key), options: .atomic)
    } catch {
      AppLog.error("offline cache list write failed", error)
    }
  }

  public func loadList<T: Codable & Sendable>(_ type: T.Type, user: String?, key: String) -> [T]? {
    guard let user, !user.isEmpty else { return nil }
    do {
      let url = try file(user, key)
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      return try WalletJSON.decoder.decode(ListFile<T>.self, from: Data(contentsOf: url)).items
    } catch {
      AppLog.error("offline cache list read failed", error)
      return nil
    }
  }

  public func saveItem<T: Codable & Sendable>(_ item: T, user: String?, key: String) {
    guard let user, !user.isEmpty else { return }
    do {
      try WalletJSON.encoder.encode(ItemFile(item: item)).write(to: file(user, key), options: .atomic)
    } catch {
      AppLog.error("offline cache item write failed", error)
    }
  }

  public func loadItem<T: Codable & Sendable>(_ type: T.Type, user: String?, key: String) -> T? {
    guard let user, !user.isEmpty else { return nil }
    do {
      let url = try file(user, key)
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      return try WalletJSON.decoder.decode(ItemFile<T>.self, from: Data(contentsOf: url)).item
    } catch {
      AppLog.error("offline cache item read failed", error)
      return nil
    }
  }

  public func clear(user: String) {
    guard !user.isEmpty else { return }
    try? FileManager.default.removeItem(at: root.appendingPathComponent(user, isDirectory: true))
  }

  /// Cache files of [user], newest first.
  public func entries(user: String) -> [CacheEntry] {
    let dir = root.appendingPathComponent(user, isDirectory: true)
    let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
    guard
      let urls = try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: keys)
    else { return [] }
    return urls.filter { $0.pathExtension == "json" }.compactMap { url in
      let v = try? url.resourceValues(forKeys: Set(keys))
      return CacheEntry(
        key: url.deletingPathExtension().lastPathComponent, bytes: v?.fileSize ?? 0,
        modifiedAt: v?.contentModificationDate ?? .distantPast)
    }.sorted { $0.modifiedAt > $1.modifiedAt }
  }
}

/// Stable cache keys, identical to the Flutter app's.
public enum CacheKey {
  public static let accounts = "accounts"
  public static let cards = "cards"
  public static let loans = "loans"
  public static let loanCapitalPayments = "loan_capital_payments"
  public static let categories = "categories"
  public static let tags = "tags"
  public static let assets = "assets"
  public static let recurringMovements = "recurring_movements"
  public static let creditGroups = "tx_credit_groups_flat"

  public static func month(_ m: Date) -> String {
    String(format: "tx_month_%d_%02d", WalletCalendar.year(m), WalletCalendar.month(m))
  }

  public static func year(_ y: Date) -> String { "tx_year_\(WalletCalendar.year(y))" }
  public static func yearOnly(_ y: Int) -> String { "tx_in_year_\(y)" }
  public static func credit(_ id: String) -> String { "tx_credit_\(id)" }
  public static func walletCredit(_ id: String) -> String { "wallet_credit_\(id)" }
}

/// Whether the OS reports any network path. Unknown counts as online.
public final class Connectivity: @unchecked Sendable {
  public static let shared = Connectivity()
  private let monitor = NWPathMonitor()
  private let lock = NSLock()
  private var status: NWPath.Status = .satisfied

  private init() {
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      lock.withLock { self.status = path.status }
    }
    monitor.start(queue: DispatchQueue(label: "wallet.connectivity"))
  }

  public var isOnline: Bool { lock.withLock { status != .unsatisfied } }
}

/// Value from a read-through cache, and whether it came from disk.
public struct Served<T: Sendable>: Sendable {
  public var value: T
  public var fromCache: Bool
  public init(_ value: T, fromCache: Bool) {
    self.value = value
    self.fromCache = fromCache
  }
}

/// Thrown when offline with nothing cached.
public struct NoConnectivityError: Error, LocalizedError {
  public var errorDescription: String? { "No internet connection" }
}

public enum LoadFailure: Sendable {
  case networkUnavailable, requestFailed

  public init(_ error: Error) {
    if error is NoConnectivityError || error is URLError {
      self = .networkUnavailable
      return
    }
    let s = String(describing: error)
    let hints = ["NSURLErrorDomain", "offline", "timed out", "network connection", "Could not connect", "-1009", "-1001"]
    self = hints.contains { s.localizedCaseInsensitiveContains($0) } ? .networkUnavailable : .requestFailed
  }
}

/// Remote first; serve the cache when offline or the request fails for network reasons.
func readThrough<T: Codable & Sendable>(
  user: String?, key: String, cache: OfflineCache, remote: () async throws -> [T]
) async throws -> Served<[T]> {
  if !Connectivity.shared.isOnline, let cached = await cache.loadList(T.self, user: user, key: key) {
    return Served(cached, fromCache: true)
  }
  do {
    let list = try await remote()
    await cache.saveList(list, user: user, key: key)
    return Served(list, fromCache: false)
  } catch {
    let cached = await cache.loadList(T.self, user: user, key: key)
    let offline = !Connectivity.shared.isOnline
    if let cached, offline || LoadFailure(error) == .networkUnavailable {
      return Served(cached, fromCache: true)
    }
    if offline { throw NoConnectivityError() }
    throw error
  }
}

func readThroughItem<T: Codable & Sendable>(
  user: String?, key: String, cache: OfflineCache, remote: () async throws -> T?
) async throws -> Served<T?> {
  if !Connectivity.shared.isOnline, let cached = await cache.loadItem(T.self, user: user, key: key) {
    return Served(cached, fromCache: true)
  }
  do {
    let value = try await remote()
    if let value { await cache.saveItem(value, user: user, key: key) }
    return Served(value, fromCache: false)
  } catch {
    let cached = await cache.loadItem(T.self, user: user, key: key)
    let offline = !Connectivity.shared.isOnline
    if let cached, offline || LoadFailure(error) == .networkUnavailable {
      return Served(cached, fromCache: true)
    }
    if offline { throw NoConnectivityError() }
    throw error
  }
}
