import Foundation
import Observation
import WalletCore
import WalletData

/// Watch app state: the repository, the session from the iPhone, and the
/// month's data shared by every screen.
@MainActor @Observable
final class WatchModel {
  let repo: WalletRepository?
  private(set) var isSignedIn = false
  var month = WalletCalendar.startOfMonth(.now)

  private(set) var transactions: [Transaction] = []
  /// Rows of the month's year, for the Year page.
  private(set) var yearTransactions: [Transaction] = []
  private var loadedYear: Int?
  private(set) var credits: [Transaction] = []
  private(set) var accounts: [Account] = []
  private(set) var cards: [Card] = []
  private(set) var categories: [WalletCore.Category] = []
  private(set) var tags: [Tag] = []
  private(set) var loading = false
  private(set) var failure: LoadFailure?
  private(set) var fromCache = false

  init() {
    repo = WalletConfig.fromBundle().map { WalletRepository(config: $0, borrowsSession: true) }
    // Signed in while the token the iPhone handed over still works.
    isSignedIn = repo?.hasSession ?? false
    guard let repo else { return }
    let bridge = SessionBridge.shared
    bridge.onTokens = { [weak self] tokens in
      Task { @MainActor in await self?.receive(tokens, repo: repo) }
    }
    bridge.activate()
  }

  /// Tokens from the iPhone: adopt them, or sign out when it signed out.
  private func receive(_ tokens: SessionTokens?, repo: WalletRepository) async {
    guard let tokens else {
      if isSignedIn { try? await repo.signOut() }
      isSignedIn = false
      return
    }
    do {
      try repo.adopt(tokens)
      let wasSignedIn = isSignedIn
      isSignedIn = true
      scheduleTokenRenewal()
      if !wasSignedIn || transactions.isEmpty { await load() }
    } catch {
      AppLog.error("watch: adopting iPhone session failed", error)
    }
  }

  private var renewal: Task<Void, Never>?

  /// Asks the iPhone for a new token a minute before this one expires.
  private func scheduleTokenRenewal() {
    renewal?.cancel()
    guard let expiry = repo?.accessTokenExpiry else { return }
    renewal = Task {
      try? await Task.sleep(for: .seconds(max(expiry.timeIntervalSinceNow - 60, 5)))
      guard !Task.isCancelled else { return }
      SessionBridge.shared.request()
    }
  }

  /// On launch and when the app comes back: get the iPhone's current token.
  func refreshSessionFromPhone() {
    if let expiry = repo?.accessTokenExpiry, expiry <= .now { isSignedIn = false }
    SessionBridge.shared.request()
  }

  func retrySessionRequest() { SessionBridge.shared.request() }

  func load() async {
    guard let repo, isSignedIn else { return }
    loading = true
    defer { loading = false }
    let m = month
    do {
      let served = try await repo.transactions(month: m)
      guard m == month else { return }
      transactions = served.value
      fromCache = served.fromCache
      failure = nil
    } catch {
      if transactions.isEmpty { failure = LoadFailure(error) }
    }
    let y = WalletCalendar.year(m)
    if let rows = try? await repo.transactions(inYear: y).value, WalletCalendar.year(month) == y {
      yearTransactions = rows
      loadedYear = y
    }
    credits = (try? await repo.creditInstallments().value) ?? credits
    accounts = Sorting.byName((try? await repo.accounts().value) ?? accounts, \.name)
    cards = Sorting.byName((try? await repo.cards().value) ?? cards, \.name)
    categories = Sorting.byName((try? await repo.categories().value) ?? categories, \.name)
    tags = Sorting.visibleThenByName((try? await repo.tags().value) ?? tags).filter { !$0.hidden }
  }

  func shiftMonth(_ n: Int) async {
    month = WalletCalendar.monthStart(month, offset: n)
    transactions = []
    await load()
  }

  var year: Int { WalletCalendar.year(month) }

  /// The year's rows up to today: what has actually happened so far.
  var yearToDate: [Transaction] {
    loadedYear == year ? yearTransactions.filter { $0.transactedAt <= .now } : []
  }

  /// Sum of all account balances (the iPhone's Accounts total).
  var accountsTotal: Double { accounts.reduce(0) { $0 + $1.balance } }

  /// Weighted totals for the month, the default page of the iPhone footer.
  var totals: Totals { TotalsMode.weighted.totals(transactions) }

  /// Newest rows first, transfers shown as one row like on the iPhone.
  var recent: [LedgerRow] { Ledger.groupedByDay(transactions).flatMap(\.rows).prefix(15).map { $0 } }

  /// Most recent non-transfer row, used to prefill the quick-add form.
  var lastUsed: Transaction? {
    transactions.first { !$0.isTransferLeg && !$0.isCreditInstallment && $0.categoryId != nil && $0.tagId != nil }
  }

  func save(_ draft: WalletRepository.TransactionDraft) async -> Bool {
    guard let repo else { return false }
    do {
      try await repo.createTransaction(draft)
      await load()
      return true
    } catch {
      AppLog.error("watch: create transaction failed", error)
      return false
    }
  }
}
