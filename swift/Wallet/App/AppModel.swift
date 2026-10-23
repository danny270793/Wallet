import SwiftUI
import WalletCore
import WalletData

/// App-wide state: the repository, the session and a change counter.
///
/// Demo mode swaps [repo] for an in-memory repository full of fake data (see
/// `WalletRepository(demo:)`); the real repository and its Supabase client sit
/// untouched until the user signs out of the demo.
///
/// Every successful write bumps [dataVersion]; screens reload in
/// `.task(id: model.dataVersion)`, so lists, totals and charts on other tabs
/// stay in sync without each screen knowing about the others.
@MainActor @Observable
final class AppModel {
  /// What every screen reads and writes: the demo repository while in demo mode.
  private(set) var repo: WalletRepository?
  /// The Supabase-backed repository (nil without `WalletConfig.plist`).
  private let liveRepo: WalletRepository?
  private(set) var isSignedIn = false
  private(set) var isDemo = false
  private(set) var dataVersion = 0
  /// Message of the last failed write, shown as an alert.
  var actionError: String?

  init() {
    let live = WalletConfig.fromBundle().map { WalletRepository(config: $0) }
    liveRepo = live
    repo = live
    isSignedIn = live?.hasSession ?? false
    if let repo = live {
      // The watch app has no login screen: it signs in with this session.
      let bridge = SessionBridge.shared
      bridge.currentTokens = { await repo.freshSessionTokens() }
      bridge.activate()
      Task { await self.observeAuth(repo) }
    }
    #if DEBUG
      // `-startDemo YES` opens straight into demo mode (handy for simulator screenshots).
      if UserDefaults.standard.bool(forKey: "startDemo") { startDemo() }
    #endif
  }

  private func observeAuth(_ repo: WalletRepository) async {
    for await (_, session) in repo.client.auth.authStateChanges {
      // The demo is not tied to the Supabase session; leave it alone.
      guard !isDemo else { continue }
      isSignedIn = session != nil
      // Sign-in, token refresh and sign-out all reach the watch.
      SessionBridge.shared.send(session.map { SessionTokens(accessToken: $0.accessToken, refreshToken: $0.refreshToken) })
    }
  }

  func didSignIn() { isSignedIn = true }

  /// Enters demo mode: a new fake ledger dated around today, kept in memory.
  /// Nothing is sent to Supabase, saved to disk or reported to `wallet_actions`.
  func startDemo() {
    AppLog.isDemo = true
    repo = WalletRepository(demo: DemoStore())
    isDemo = true
    isSignedIn = true
    dataVersion += 1
  }

  /// Leaves demo mode (dropping its data) or signs out of the real account.
  func signOut() async {
    if isDemo {
      AppLog.isDemo = false
      isDemo = false
      repo = liveRepo
      isSignedIn = liveRepo?.hasSession ?? false
      dataVersion += 1
      return
    }
    try? await repo?.signOut()
    isSignedIn = false
  }

  /// Runs a write; on success bumps [dataVersion], on failure shows an alert.
  @discardableResult
  func perform(_ label: String, _ action: (WalletRepository) async throws -> Void) async -> Bool {
    guard let repo else { return false }
    do {
      try await action(repo)
      dataVersion += 1
      return true
    } catch {
      AppLog.error(label, error)
      actionError = L("unexpectedError")
      return false
    }
  }
}

/// A screen's loaded value, plus where it came from.
struct Loadable<T: Sendable> {
  var value: T?
  var failure: LoadFailure?
  var fromCache = false

  var isLoading: Bool { value == nil && failure == nil }

  /// Fetches and returns the next state; keeps the last value on refresh failures.
  func loaded(_ fetch: () async throws -> Served<T>) async -> Loadable<T> {
    var next = self
    do {
      let served = try await fetch()
      next.value = served.value
      next.fromCache = served.fromCache
      next.failure = nil
    } catch is CancellationError {
    } catch {
      AppLog.error("load failed", error)
      if next.value == nil { next.failure = LoadFailure(error) }
    }
    return next
  }
}
