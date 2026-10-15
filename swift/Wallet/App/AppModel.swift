import SwiftUI
import WalletCore
import WalletData

/// App-wide state: the repository, the session and a change counter.
///
/// Every successful write bumps [dataVersion]; screens reload in
/// `.task(id: model.dataVersion)`, so lists, totals and charts on other tabs
/// stay in sync without each screen knowing about the others.
@MainActor @Observable
final class AppModel {
  let repo: WalletRepository?
  private(set) var isSignedIn = false
  private(set) var dataVersion = 0
  /// Message of the last failed write, shown as an alert.
  var actionError: String?

  init() {
    repo = WalletConfig.fromBundle().map { WalletRepository(config: $0) }
    isSignedIn = repo?.hasSession ?? false
    if let repo { Task { await self.observeAuth(repo) } }
  }

  private func observeAuth(_ repo: WalletRepository) async {
    for await (_, session) in repo.client.auth.authStateChanges {
      isSignedIn = session != nil
    }
  }

  func didSignIn() { isSignedIn = true }

  func signOut() async {
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
