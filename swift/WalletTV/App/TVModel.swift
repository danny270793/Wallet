import Foundation
import Observation
import WalletCore
import WalletData

/// Apple TV app state: the repository, session, and the month/year data
/// every tab reads.
@MainActor @Observable
final class TVModel {
  let repo: WalletRepository?
  private(set) var isSignedIn = false
  var month = WalletCalendar.startOfMonth(.now)

  private(set) var transactions: [Transaction] = []
  private(set) var yearTransactions: [Transaction] = []
  private(set) var credits: [Transaction] = []
  private(set) var accounts: [Account] = []
  private(set) var cards: [Card] = []
  private(set) var cardCredits: [String: CardCreditTotals] = [:]
  private(set) var loading = false
  private(set) var failure: LoadFailure?
  private(set) var fromCache = false
  private var loadedYear: Int?

  init() {
    repo = WalletConfig.fromBundle().map { WalletRepository(config: $0) }
    isSignedIn = repo?.hasSession ?? false
    if let repo { Task { await observeAuth(repo) } }
  }

  private func observeAuth(_ repo: WalletRepository) async {
    for await (_, session) in repo.client.auth.authStateChanges { isSignedIn = session != nil }
  }

  func signIn(email: String, password: String) async throws {
    try await repo?.signIn(email: email, password: password)
    isSignedIn = true
  }

  func signOut() async {
    try? await repo?.signOut()
    isSignedIn = false
  }

  var year: Int { WalletCalendar.year(month) }

  func shiftMonth(_ n: Int) {
    month = WalletCalendar.monthStart(month, offset: n)
    transactions = []
  }

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
    if loadedYear != y || yearTransactions.isEmpty, let rows = try? await repo.transactions(inYear: y).value {
      yearTransactions = rows
      loadedYear = y
    }
    credits = (try? await repo.creditInstallments().value) ?? credits
    cardCredits = CreditLedger.totalsByCard(credits)
    accounts = Sorting.byName((try? await repo.accounts().value) ?? accounts, \.name)
    cards = Sorting.byName((try? await repo.cards().value) ?? cards, \.name)
  }

  var monthTotals: Totals { TotalsMode.weighted.totals(transactions) }

  /// The year's rows up to today.
  var yearToDate: [Transaction] { loadedYear == year ? yearTransactions.filter { $0.transactedAt <= .now } : [] }

  var accountsTotal: Double { accounts.reduce(0) { $0 + $1.balance } }
  var cardsTotal: Double { cards.reduce(0) { $0 + CreditLedger.postedBalance($1.balance, cardCredits[$1.id]) } }
}
