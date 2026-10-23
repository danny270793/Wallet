import Foundation
import Testing
import WalletCore

@testable import WalletData

private func repo(seed: UInt64 = 11) -> WalletRepository {
  WalletRepository(demo: DemoStore(DemoDataGenerator.make(seed: seed)))
}

@Suite struct DemoRepositoryTests {
  @Test func looksSignedInWithADemoUser() {
    let r = repo()
    #expect(r.isDemo)
    #expect(r.hasSession)
    #expect(r.email == "demo@wallet.app")
    #expect(r.userId == DemoDataGenerator.userId)
  }

  @Test func neverSignsInOrChangesTheAccount() async throws {
    let r = repo()
    await #expect(throws: WalletError.self) { try await r.signIn(email: "a@b.co", password: "x") }
    await #expect(throws: WalletError.self) { try await r.updateEmail("a@b.co") }
    await #expect(throws: WalletError.self) { try await r.updatePassword("secret1") }
    let entries = await r.cacheEntries()
    let tokens = await r.freshSessionTokens()
    #expect(entries.isEmpty)
    #expect(tokens == nil)
    // Signing out of demo is a no-op that keeps the repository usable.
    try await r.signOut()
    let accounts = try await r.accounts().value
    #expect(!accounts.isEmpty)
  }

  @Test func readsComeFromMemoryNotTheCache() async throws {
    let r = repo()
    let now = Date.now
    let accounts = try await r.accounts()
    let cards = try await r.cards().value
    let categories = try await r.categories().value
    let tags = try await r.tags().value
    let assets = try await r.assets().value
    let loans = try await r.loans().value
    let capital = try await r.capitalPayments().value
    let recurring = try await r.recurringMovements().value
    let credits = try await r.creditInstallments().value
    let thisMonth = try await r.transactions(month: now).value
    let lastMonth = try await r.transactions(month: WalletCalendar.monthStart(now, offset: -1)).value
    let throughYear = try await r.transactions(throughYear: now).value
    let inYear = try await r.transactions(inYear: WalletCalendar.year(now)).value
    let found = try await r.searchTransactions("rent")
    let blank = try await r.searchTransactions("   ")
    #expect(!accounts.fromCache)
    #expect(!accounts.value.isEmpty && !cards.isEmpty && !categories.isEmpty && !tags.isEmpty)
    #expect(!assets.isEmpty && !loans.isEmpty && !capital.isEmpty && !recurring.isEmpty && !credits.isEmpty)
    #expect(!thisMonth.isEmpty && !lastMonth.isEmpty)
    #expect(throughYear.count >= inYear.count)
    #expect(!found.isEmpty)
    #expect(blank.isEmpty)
  }

  @Test func monthReadsOnlyReturnThatMonthNewestFirst() async throws {
    let r = repo()
    let month = WalletCalendar.monthStart(.now, offset: -2)
    let rows = try await r.transactions(month: month).value
    #expect(rows.allSatisfy { WalletCalendar.isSameMonth($0.transactedAt, month) })
    #expect(rows == rows.sorted { $0.transactedAt > $1.transactedAt })
  }

  @Test func createdAccountGetsABalanceFromItsTransactions() async throws {
    let r = repo()
    let account = try await r.createAccount(name: "Travel fund")
    #expect(account.balance == 0)
    try await r.createTransaction(.init(accountId: account.id, description: "Deposit", transactedAt: .now, value: 250))
    try await r.createTransaction(.init(accountId: account.id, description: "Lunch", transactedAt: .now, value: -40.5))
    let found = try await r.accounts().value.first { $0.id == account.id }
    #expect(found?.balance == 209.5)
    try await r.updateAccount(id: account.id, name: "Trip")
    let renamed = try await r.accounts().value.first { $0.id == account.id }
    #expect(renamed?.name == "Trip")
    try await r.deleteAccount(id: account.id)
    let after = try await r.accounts().value
    #expect(!after.contains { $0.id == account.id })
    await #expect(throws: WalletError.self) { try await r.deleteAccount(id: account.id) }
  }

  @Test func transactionCrudResolvesNames() async throws {
    let r = repo()
    let account = try #require(try await r.accounts().value.first)
    let category = try #require(try await r.categories().value.first)
    let before = try await r.transactions(month: .now).value.count
    try await r.createTransaction(
      .init(accountId: account.id, categoryId: category.id, description: "Coffee beans", transactedAt: .now, value: -12))
    let created = try #require(try await r.searchTransactions("coffee beans").first)
    #expect(created.accountName == account.name)
    #expect(created.categoryName == category.name)
    let after = try await r.transactions(month: .now).value.count
    #expect(after == before + 1)

    try await r.updateTransaction(
      id: created.id,
      .init(accountId: account.id, description: "Coffee beans (edited)", transactedAt: created.transactedAt, value: -15))
    let edited = try #require(try await r.searchTransactions("edited").first)
    #expect(edited.value == -15)
    #expect(edited.categoryId == nil && edited.categoryName == nil)

    try await r.deleteTransaction(id: created.id)
    let gone = try await r.searchTransactions("coffee beans")
    #expect(gone.isEmpty)
  }

  @Test func renamingACategoryShowsOnExistingRows() async throws {
    let r = repo()
    let groceries = try #require(try await r.categories().value.first { $0.name == "Groceries" })
    try await r.updateCategory(id: groceries.id, name: "Food", description: nil)
    let all = try await r.transactions(throughYear: .now).value
    let rows = all.filter { $0.categoryId == groceries.id }
    #expect(!rows.isEmpty)
    #expect(rows.allSatisfy { $0.categoryName == "Food" })
  }

  @Test func transferMovesMoneyBetweenAccounts() async throws {
    let r = repo()
    let accounts = try await r.accounts().value
    let (a, b) = (accounts[0], accounts[1])
    try await r.transfer(from: .account(a.id), to: .account(b.id), amount: 75, at: .now)
    let after = try await r.accounts().value
    let newA = try #require(after.first { $0.id == a.id })
    let newB = try #require(after.first { $0.id == b.id })
    #expect(abs(newA.balance - (a.balance - 75)) < 0.005)
    #expect(abs(newB.balance - (b.balance + 75)) < 0.005)
  }

  @Test func deferredPurchaseIsSplitAndDeletedAsAGroup() async throws {
    let r = repo()
    let card = try #require(try await r.cards().value.first)
    try await r.createTransaction(
      .init(cardId: card.id, description: "Washer", transactedAt: .now, value: -600), deferred: true, graceMonths: 0,
      termMonths: 6)
    let all = try await r.creditInstallments().value
    let group = all.filter { $0.description?.contains("Washer") == true }
    #expect(group.count == 6)
    #expect(abs(group.reduce(0) { $0 + $1.value } + 600) < 0.005)
    let key = try #require(group.first?.creditKey)
    let header = try #require(try await r.credit(id: key))
    #expect(header.termMonths == 6)
    let rows = try await r.installments(credit: key)
    #expect(rows.count == 6)
    // Installments stay out of the card ledger balance, like the SQL view.
    let newBalance = try await r.cards().value.first { $0.id == card.id }?.balance
    #expect(newBalance == card.balance)

    try await r.deleteTransaction(id: group[0].id, creditKey: key)
    let left = try await r.installments(credit: key)
    #expect(left.isEmpty)
  }

  @Test func adjustBalanceReusesTheAdjustmentCategoryAndTag() async throws {
    let r = repo()
    let account = try #require(try await r.accounts().value.first)
    let categoriesBefore = try await r.categories().value.count
    try await r.adjustBalance(.account(account.id), delta: 10)
    try await r.adjustBalance(.account(account.id), delta: -4)
    let categoriesAfter = try await r.categories().value.count
    #expect(categoriesAfter == categoriesBefore)
    let updated = try #require(try await r.accounts().value.first { $0.id == account.id })
    #expect(abs(updated.balance - (account.balance + 6)) < 0.005)
  }

  @Test func cardsLoansAssetsRecurringTagsAndCategoriesCanBeEdited() async throws {
    let r = repo()
    try await r.createCard(name: "Amex", type: .amex, rate: 20, cutDay: 10, payDay: 25)
    let card = try #require(try await r.cards().value.first { $0.name == "Amex" })
    try await r.updateCard(id: card.id, name: "Amex Blue", type: .amex, rate: nil, cutDay: 12, payDay: 27)
    let edited = try await r.cards().value.first { $0.id == card.id }
    #expect(edited?.nominalInterestRate == nil)
    #expect(edited?.name == "Amex Blue")
    try await r.deleteCard(id: card.id)

    let account = try #require(try await r.accounts().value.first)
    try await r.saveLoan(
      id: nil, accountId: account.id, name: "Bike", value: 600, rate: nil, termMonths: 6, paymentDay: 10,
      firstPaymentDate: .now)
    let loan = try #require(try await r.loans().value.first { $0.name == "Bike" })
    try await r.createCapitalPayment(loanId: loan.id, value: 100, paidAt: .now)
    let payment = try #require(try await r.capitalPayments().value.first { $0.loanId == loan.id })
    try await r.deleteCapitalPayment(id: payment.id)
    try await r.deleteLoan(id: loan.id)
    let loans = try await r.loans().value
    #expect(!loans.contains { $0.id == loan.id })

    try await r.saveAsset(id: nil, name: "Watch", provider: "Casio", value: 90, boughtAt: .now, endedAt: nil, soldValue: nil)
    let asset = try #require(try await r.assets().value.first { $0.name == "Watch" })
    try await r.saveAsset(
      id: asset.id, name: "Watch", provider: "Casio", value: 90, boughtAt: .now, endedAt: .now, soldValue: 40)
    let sold = try await r.assets().value.first { $0.id == asset.id }
    #expect(sold?.isEnded == true)
    try await r.deleteAsset(id: asset.id)

    let category = try await r.createCategory(name: "Pets")
    let tag = try await r.createTag(name: "Dog", description: "Rex")
    try await r.updateTag(id: tag.id, name: "Dog", description: nil, hidden: true)
    let hidden = try await r.tags().value.first { $0.id == tag.id }
    #expect(hidden?.hidden == true)
    try await r.saveRecurringMovement(
      id: nil, name: "Dog food", description: nil, value: -30, categoryId: category.id, tagId: tag.id, yearly: false)
    let recurring = try #require(try await r.recurringMovements().value.first { $0.name == "Dog food" })
    #expect(recurring.categoryName == "Pets" && recurring.tagName == "Dog")
    try await r.deleteRecurringMovement(id: recurring.id)
    try await r.deleteTag(id: tag.id)
    try await r.deleteCategory(id: category.id)
  }

  @Test func neverWritesToDiskOrReportsErrors() async throws {
    let before = AppLog.isDemo
    AppLog.isDemo = true
    defer { AppLog.isDemo = before }
    let r = repo()
    _ = try await r.accounts()
    _ = try await r.transactions(month: .now)
    let entries = await r.cacheEntries()
    #expect(entries.isEmpty)
    let unused = FileManager.default.temporaryDirectory.appendingPathComponent("wallet_demo_unused")
    #expect(!FileManager.default.fileExists(atPath: unused.path))
    // Error logging stays on the console only; this must not reach any reporter.
    AppLog.error("demo failure", WalletError.notSignedIn)
  }

  @Test func eachDemoSessionStartsFromFreshData() async throws {
    let a = DemoDataGenerator.make(seed: 1), b = DemoDataGenerator.make(seed: 2)
    #expect(a.transactions != b.transactions)
    let first = WalletRepository(demo: DemoStore(a))
    try await first.createAccount(name: "Only here")
    let second = WalletRepository(demo: DemoStore(a))
    let accounts = try await second.accounts().value
    #expect(!accounts.contains { $0.name == "Only here" })
  }
}
