import Foundation
import Supabase

/// Auth storage that lives in memory only, so the placeholder client of a demo
/// repository never reads or writes the Keychain.
final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: Data] = [:]

  func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
  func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
  func remove(key: String) throws { lock.withLock { values[key] = nil } }
}
