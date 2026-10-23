import Foundation
import OSLog
import Supabase

/// Console logging plus best-effort error reporting to `wallet_actions`,
/// like the Flutter `AppLogger`/`WalletActionsReporter` pair.
public enum AppLog {
  private static let logger = Logger(subsystem: "io.github.danny270793.wallet", category: "app")

  /// Set once the Supabase client exists, so errors can be reported.
  nonisolated(unsafe) static var reporter: ActionsReporter?

  /// True while demo mode is on: errors are only logged to the console, never
  /// sent to `wallet_actions`.
  nonisolated(unsafe) public static var isDemo = false

  public static func debug(_ message: String) {
    #if DEBUG
      logger.debug("\(message, privacy: .public)")
    #endif
  }

  public static func info(_ message: String) {
    #if DEBUG
      logger.info("\(message, privacy: .public)")
    #endif
  }

  public static func error(_ message: String, _ error: Error? = nil) {
    logger.error("\(message, privacy: .public) \(error.map { String(describing: $0) } ?? "", privacy: .public)")
    if !isDemo { reporter?.record(message: error.map { "\(message): \($0)" } ?? message, stack: Thread.callStackSymbols) }
  }
}

/// Inserts rows into `wallet_actions`. Never throws to callers.
final class ActionsReporter: Sendable {
  private let client: SupabaseClient
  private static let maxStack = 24_000
  private static let maxMessage = 8_000

  private let borrowedUserId: @Sendable () -> String?

  init(client: SupabaseClient, userId: @escaping @Sendable () -> String? = { nil }) {
    self.client = client
    borrowedUserId = userId
  }

  private struct Row: Encodable {
    var type: String
    var customTitle: String?
    var errorMessage: String?
    var errorStack: String?
    var appVersion: String
    var userId: String?
    var os: String
  }

  private static var appVersion: String {
    let info = Bundle.main.infoDictionary
    let v = info?["CFBundleShortVersionString"] as? String ?? "unknown"
    let b = info?["CFBundleVersion"] as? String ?? "0"
    return "\(v)+\(b)"
  }

  private static func trim(_ s: String, _ max: Int) -> String {
    s.count <= max ? s : String(s.prefix(max)) + "…(truncated)"
  }

  private var osLabel: String {
    #if os(watchOS)
      "watchos"
    #else
      "ios"
    #endif
  }

  /// The watch has no Supabase Auth session; reading `auth` there is not allowed.
  private func currentAuthUser() -> String? {
    #if os(watchOS)
      nil
    #else
      client.auth.currentUser?.id.uuidString.lowercased()
    #endif
  }

  func record(message: String, stack: [String]) {
    let row = Row(
      type: "error", errorMessage: Self.trim(message, Self.maxMessage),
      errorStack: Self.trim(stack.joined(separator: "\n"), Self.maxStack), appVersion: Self.appVersion,
      userId: borrowedUserId() ?? currentAuthUser(), os: osLabel)
    let client = client
    Task.detached {
      _ = try? await client.from("wallet_actions").insert(row).execute()
    }
  }
}
