import Foundation
import Security

/// An access token handed over by the paired iPhone, kept in the watch's
/// keychain so the app opens signed in while the token is still valid.
final class BorrowedToken: @unchecked Sendable {
  private let lock = NSLock()
  private var token: String?
  private static let service = "io.github.danny270793.wallet.watch.token"

  init() { token = Self.load() }

  var accessToken: String? { lock.withLock { isValidLocked ? token : nil } }
  var expiry: Date? { lock.withLock { token.flatMap { Self.claims($0)?.expiry } } }
  var userId: String? { lock.withLock { token.flatMap { Self.claims($0)?.subject } } }
  var isValid: Bool { lock.withLock { isValidLocked } }

  private var isValidLocked: Bool {
    guard let token, let exp = Self.claims(token)?.expiry else { return false }
    return exp > .now
  }

  func set(_ jwt: String) throws {
    guard let exp = Self.claims(jwt)?.expiry, exp > .now else {
      throw WalletError.invalidArgument("access token expired")
    }
    lock.withLock { token = jwt }
    Self.save(jwt)
  }

  func clear() {
    lock.withLock { token = nil }
    Self.save(nil)
  }

  /// `exp` and `sub` claims of a JWT (the user id is the subject).
  static func claims(_ jwt: String) -> (expiry: Date, subject: String?)? {
    let parts = jwt.split(separator: ".")
    guard parts.count == 3 else { return nil }
    var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    b64 += String(repeating: "=", count: (4 - b64.count % 4) % 4)
    guard let data = Data(base64Encoded: b64),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let exp = obj["exp"] as? Double
    else { return nil }
    return (Date(timeIntervalSince1970: exp), (obj["sub"] as? String)?.lowercased())
  }

  private static var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
  }

  private static func load() -> String? {
    var q = query
    q[kSecReturnData as String] = true
    var out: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func save(_ token: String?) {
    SecItemDelete(query as CFDictionary)
    guard let token else { return }
    var q = query
    q[kSecValueData as String] = Data(token.utf8)
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(q as CFDictionary, nil)
  }
}
