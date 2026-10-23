import Foundation
import WalletCore

/// In-memory ledger behind a demo `WalletRepository`.
///
/// It answers the same reads and applies the same writes as the `wallet_*`
/// tables, but nothing leaves the process: no Supabase, no offline cache file,
/// no `wallet_actions`. Balances are computed on every read, like the
/// `wallet_*_with_balance` views, and a delete removes the row (the database
/// only marks it deleted, which readers filter out anyway).
public actor DemoStore {
  private var accounts: [Account]
  private var cards: [Card]
  private var categories: [WalletCore.Category]
  private var tags: [Tag]
  private var assets: [Asset]
  private var loans: [Loan]
  private var capitalPayments: [LoanCapitalPayment]
  private var recurring: [RecurringMovement]
  private var credits: [WalletCredit]
  private var transactions: [Transaction]

  private let userId = DemoDataGenerator.userId

  public init(_ data: DemoDataSet) {
    accounts = data.accounts
    cards = data.cards
    categories = data.categories
    tags = data.tags
    assets = data.assets
    loans = data.loans
    capitalPayments = data.capitalPayments
    recurring = data.recurringMovements
    credits = data.credits
    transactions = data.transactions
  }

  /// A fresh random demo ledger dated around today.
  public init() { self.init(DemoDataGenerator.make()) }

  private func newId() -> String { UUID().uuidString.lowercased() }

  private func missing(_ what: String) -> WalletError { .softDeleteFailed(what) }

  // MARK: Accounts

  func listAccounts() -> [Account] { DemoBalances.accounts(accounts, transactions) }

  func createAccount(name: String) -> Account {
    let now = Date.now
    let a = Account(id: newId(), userId: userId, name: name, createdAt: now, updatedAt: now)
    accounts.append(a)
    return DemoBalances.accounts([a], transactions)[0]
  }

  func updateAccount(id: String, name: String) {
    guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
    accounts[i].name = name
    accounts[i].updatedAt = .now
  }

  func deleteAccount(id: String) throws {
    guard accounts.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_account") }
    accounts.removeAll { $0.id == id }
  }

  // MARK: Cards

  func listCards() -> [Card] { DemoBalances.cards(cards, transactions) }

  func createCard(name: String, type: CardType, rate: Double?, cutDay: Int, payDay: Int) {
    let now = Date.now
    cards.append(
      Card(
        id: newId(), userId: userId, name: name, type: type, createdAt: now, updatedAt: now, cutDay: cutDay,
        payDay: payDay, nominalInterestRate: rate))
  }

  func updateCard(id: String, name: String, type: CardType, rate: Double?, cutDay: Int, payDay: Int) {
    guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
    cards[i].name = name
    cards[i].type = type
    cards[i].nominalInterestRate = rate
    cards[i].cutDay = cutDay
    cards[i].payDay = payDay
    cards[i].updatedAt = .now
  }

  func deleteCard(id: String) throws {
    guard cards.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_card") }
    cards.removeAll { $0.id == id }
  }

  // MARK: Categories & tags

  func listCategories() -> [WalletCore.Category] { categories }

  func createCategory(name: String, description: String?) -> WalletCore.Category {
    let now = Date.now
    let c = WalletCore.Category(id: newId(), userId: userId, name: name, description: description, createdAt: now, updatedAt: now)
    categories.append(c)
    return c
  }

  func updateCategory(id: String, name: String, description: String?) {
    guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
    categories[i].name = name
    categories[i].description = description
    categories[i].updatedAt = .now
  }

  func deleteCategory(id: String) throws {
    guard categories.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_category") }
    categories.removeAll { $0.id == id }
  }

  func listTags() -> [Tag] { tags }

  func createTag(name: String, description: String?) -> Tag {
    let now = Date.now
    let t = Tag(id: newId(), userId: userId, name: name, description: description, createdAt: now, updatedAt: now)
    tags.append(t)
    return t
  }

  func updateTag(id: String, name: String, description: String?, hidden: Bool) {
    guard let i = tags.firstIndex(where: { $0.id == id }) else { return }
    tags[i].name = name
    tags[i].description = description
    tags[i].hidden = hidden
    tags[i].updatedAt = .now
  }

  func deleteTag(id: String) throws {
    guard tags.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_tag") }
    tags.removeAll { $0.id == id }
  }

  // MARK: Assets

  func listAssets() -> [Asset] { assets.sorted { $0.boughtAt > $1.boughtAt } }

  func saveAsset(
    id: String?, name: String, provider: String, value: Double, boughtAt: Date, endedAt: Date?, soldValue: Double?
  ) {
    let now = Date.now
    if let id, let i = assets.firstIndex(where: { $0.id == id }) {
      assets[i].name = name
      assets[i].provider = provider
      assets[i].value = value
      assets[i].boughtAt = boughtAt
      assets[i].endedAt = endedAt
      assets[i].soldValue = soldValue
      assets[i].updatedAt = now
    } else {
      assets.append(
        Asset(
          id: newId(), userId: userId, name: name, provider: provider, value: value, boughtAt: boughtAt,
          endedAt: endedAt, soldValue: soldValue, createdAt: now, updatedAt: now))
    }
  }

  func deleteAsset(id: String) throws {
    guard assets.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_asset") }
    assets.removeAll { $0.id == id }
  }

  // MARK: Loans

  func listLoans() -> [Loan] { loans }

  func saveLoan(
    id: String?, accountId: String, name: String, value: Double, rate: Double?, termMonths: Int, paymentDay: Int,
    firstPaymentDate: Date
  ) {
    let now = Date.now
    if let id, let i = loans.firstIndex(where: { $0.id == id }) {
      loans[i].accountId = accountId
      loans[i].name = name
      loans[i].value = value
      loans[i].nominalInterestRate = rate
      loans[i].termMonths = termMonths
      loans[i].paymentDay = paymentDay
      loans[i].firstPaymentDate = firstPaymentDate
      loans[i].updatedAt = now
    } else {
      loans.append(
        Loan(
          id: newId(), userId: userId, accountId: accountId, name: name, value: value, nominalInterestRate: rate,
          termMonths: termMonths, paymentDay: paymentDay, firstPaymentDate: firstPaymentDate, createdAt: now,
          updatedAt: now))
    }
  }

  func deleteLoan(id: String) throws {
    guard loans.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_loan") }
    loans.removeAll { $0.id == id }
    capitalPayments.removeAll { $0.loanId == id }
  }

  func listCapitalPayments() -> [LoanCapitalPayment] { capitalPayments.sorted { $0.paidAt < $1.paidAt } }

  func createCapitalPayment(loanId: String, value: Double, paidAt: Date) {
    capitalPayments.append(
      LoanCapitalPayment(id: newId(), userId: userId, loanId: loanId, value: value, paidAt: paidAt, createdAt: .now))
  }

  func deleteCapitalPayment(id: String) throws {
    guard capitalPayments.contains(where: { $0.id == id }) else {
      throw missing("soft_delete_wallet_loan_capital_payment")
    }
    capitalPayments.removeAll { $0.id == id }
  }

  // MARK: Recurring movements

  func listRecurring() -> [RecurringMovement] { recurring }

  func saveRecurring(
    id: String?, name: String, description: String?, value: Double, categoryId: String, tagId: String, yearly: Bool
  ) {
    let now = Date.now
    let category = categories.first { $0.id == categoryId }, tag = tags.first { $0.id == tagId }
    if let id, let i = recurring.firstIndex(where: { $0.id == id }) {
      recurring[i].name = name
      recurring[i].description = description
      recurring[i].value = value
      recurring[i].categoryId = categoryId
      recurring[i].tagId = tagId
      recurring[i].categoryName = category?.name
      recurring[i].tagName = tag?.name
      recurring[i].yearlyPayment = yearly
      recurring[i].updatedAt = now
    } else {
      recurring.append(
        RecurringMovement(
          id: newId(), userId: userId, name: name, description: description, value: value, categoryId: categoryId,
          tagId: tagId, categoryName: category?.name, tagName: tag?.name, yearlyPayment: yearly, createdAt: now,
          updatedAt: now))
    }
  }

  func deleteRecurring(id: String) throws {
    guard recurring.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_recurring_movement") }
    recurring.removeAll { $0.id == id }
  }

  // MARK: Transactions

  /// The embedded `name`s PostgREST would join, refreshed from the live lists.
  /// A deleted account or category keeps the name the row already had.
  private func resolved(_ t: Transaction) -> Transaction {
    var t = t
    if let id = t.accountId, let a = accounts.first(where: { $0.id == id }) { t.accountName = a.name }
    if let id = t.cardId, let c = cards.first(where: { $0.id == id }) { t.cardName = c.name }
    if let id = t.categoryId, let c = categories.first(where: { $0.id == id }) { t.categoryName = c.name }
    if let id = t.tagId, let g = tags.first(where: { $0.id == id }) { t.tagName = g.name }
    if let id = t.creditId, let c = credits.first(where: { $0.id == id }) { t.creditTransactedAt = c.transactedAt }
    return t
  }

  private func newestFirst(_ list: [Transaction]) -> [Transaction] {
    list.map(resolved).sorted { $0.transactedAt > $1.transactedAt }
  }

  func listTransactions(from start: Date, to end: Date) -> [Transaction] {
    newestFirst(transactions.filter { $0.transactedAt >= start && $0.transactedAt < end })
  }

  func listTransactions(before end: Date) -> [Transaction] {
    newestFirst(transactions.filter { $0.transactedAt < end })
  }

  func search(_ query: String, limit: Int) -> [Transaction] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return [] }
    return Array(newestFirst(transactions.filter { ($0.description ?? "").lowercased().contains(needle) }).prefix(limit))
  }

  func listCreditInstallments() -> [Transaction] { newestFirst(transactions.filter { $0.creditKey != nil }) }

  func installments(credit: String) -> [Transaction] {
    transactions.filter { $0.creditId == credit }.map(resolved).sorted { $0.transactedAt < $1.transactedAt }
  }

  func createTransaction(_ d: WalletRepository.TransactionDraft) {
    let now = Date.now
    transactions.append(
      Transaction(
        id: newId(), userId: userId, accountId: d.accountId, cardId: d.cardId, categoryId: d.categoryId,
        tagId: d.tagId, description: d.description, transactedAt: d.transactedAt, value: d.value, ignore: d.ignore,
        percentage: d.percentage, transferGroupId: d.transferGroupId, creditId: d.creditId, createdAt: now,
        updatedAt: now))
  }

  func updateTransaction(id: String, _ d: WalletRepository.TransactionDraft) {
    guard let i = transactions.firstIndex(where: { $0.id == id }) else { return }
    transactions[i].accountId = d.accountId
    transactions[i].cardId = d.cardId
    transactions[i].categoryId = d.categoryId
    transactions[i].tagId = d.tagId
    // The update sends every relation, so a cleared one also loses its name.
    transactions[i].accountName = nil
    transactions[i].cardName = nil
    transactions[i].categoryName = nil
    transactions[i].tagName = nil
    transactions[i].description = d.description
    transactions[i].transactedAt = d.transactedAt
    transactions[i].value = d.value
    transactions[i].ignore = d.ignore
    transactions[i].percentage = d.percentage
    transactions[i].transferGroupId = d.transferGroupId
    transactions[i].creditId = d.creditId
    transactions[i].updatedAt = .now
  }

  func deleteTransaction(id: String) throws {
    guard transactions.contains(where: { $0.id == id }) else { throw missing("soft_delete_wallet_transaction") }
    transactions.removeAll { $0.id == id }
  }

  // MARK: Wallet credits

  func insertCredit(transactedAt: Date, graceMonths: Int, termMonths: Int, description: String?) -> WalletCredit {
    let now = Date.now
    let note = description?.trimmingCharacters(in: .whitespacesAndNewlines)
    let credit = WalletCredit(
      id: newId(), userId: userId, transactedAt: transactedAt, graceMonths: graceMonths, termMonths: termMonths,
      description: (note ?? "").isEmpty ? nil : note, createdAt: now, updatedAt: now)
    credits.append(credit)
    return credit
  }

  func credit(id: String) -> WalletCredit? { credits.first { $0.id == id } }

  func updateCredit(id: String, graceMonths: Int, termMonths: Int, transactedAt: Date?) {
    guard let i = credits.firstIndex(where: { $0.id == id }) else { return }
    credits[i].graceMonths = graceMonths
    credits[i].termMonths = termMonths
    if let transactedAt { credits[i].transactedAt = transactedAt }
    credits[i].updatedAt = .now
  }
}
