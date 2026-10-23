import Foundation
import Testing

@testable import WalletCore

private func demo(seed: UInt64 = 7, now: Date = .now) -> DemoDataSet { DemoDataGenerator.make(now: now, seed: seed) }

@Suite struct DemoDataGeneratorTests {
  @Test func everyEntityHasData() {
    let d = demo()
    #expect(d.accounts.count >= 3)
    #expect(d.cards.count >= 2)
    #expect(d.categories.count >= 10)
    #expect(d.tags.count >= 5)
    #expect(d.tags.contains { $0.hidden })
    #expect(d.assets.count >= 3)
    #expect(d.assets.contains { $0.isEnded })
    #expect(!d.loans.isEmpty)
    #expect(!d.capitalPayments.isEmpty)
    #expect(d.recurringMovements.contains { $0.yearlyPayment })
    #expect(d.recurringMovements.contains { $0.value > 0 })
    #expect(d.recurringMovements.contains { $0.value < 0 })
    #expect(!d.credits.isEmpty)
    #expect(d.transactions.count > 300)
  }

  @Test func transactionsSpanAtLeastTwelveMonths() {
    let now = Date.now
    let d = demo(now: now)
    let months = Set(d.transactions.filter { $0.transactedAt <= now }.map { WalletCalendar.startOfMonth($0.transactedAt) })
    #expect(months.count >= 13)
    // Current and previous month always have rows to show on the Activity tab.
    #expect(months.contains(WalletCalendar.startOfMonth(now)))
    #expect(months.contains(WalletCalendar.monthStart(now, offset: -1)))
    let ahead = d.transactions.filter { $0.transactedAt > now }
    #expect(ahead.allSatisfy { $0.isCreditInstallment })
  }

  @Test func neverDatesRegularRowsInTheFuture() {
    let now = Date.now
    for seed in 1...5 as ClosedRange<UInt64> {
      let d = demo(seed: seed, now: now)
      let regular = d.transactions.filter { !$0.isCreditInstallment }
      #expect(regular.allSatisfy { $0.transactedAt <= now })
    }
  }

  @Test func sameSeedAndDateGiveTheSameData() {
    let now = WalletCalendar.date(2026, 6, 15, hour: 10)
    let a = demo(seed: 99, now: now), b = demo(seed: 99, now: now), c = demo(seed: 100, now: now)
    #expect(a.transactions == b.transactions)
    #expect(a.transactions != c.transactions)
  }

  @Test func referencesPointToExistingRows() {
    let d = demo()
    let accounts = Set(d.accounts.map(\.id)), cards = Set(d.cards.map(\.id))
    let categories = Set(d.categories.map(\.id)), tags = Set(d.tags.map(\.id))
    let credits = Dictionary(uniqueKeysWithValues: d.credits.map { ($0.id, $0) })
    for t in d.transactions {
      // Exactly one payment method per row.
      #expect((t.accountId == nil) != (t.cardId == nil))
      if let id = t.accountId { #expect(accounts.contains(id)) }
      if let id = t.cardId { #expect(cards.contains(id)) }
      if let id = t.categoryId { #expect(categories.contains(id)) }
      if let id = t.tagId { #expect(tags.contains(id)) }
      if let id = t.creditId { #expect(credits[id] != nil) }
      // Embedded names match the rows they point to.
      if let id = t.accountId { #expect(t.accountName == d.accounts.first { $0.id == id }?.name) }
      if let id = t.cardId { #expect(t.cardName == d.cards.first { $0.id == id }?.name) }
      if let id = t.categoryId { #expect(t.categoryName == d.categories.first { $0.id == id }?.name) }
      if let id = t.tagId { #expect(t.tagName == d.tags.first { $0.id == id }?.name) }
    }
    for l in d.loans { #expect(accounts.contains(l.accountId)) }
    for p in d.capitalPayments { #expect(d.loans.contains { $0.id == p.loanId }) }
    for m in d.recurringMovements {
      #expect(m.categoryId.map(categories.contains) == true)
      #expect(m.tagId.map(tags.contains) == true)
      #expect(m.categoryName != nil && m.tagName != nil)
    }
    let ids = d.transactions.map(\.id) + d.accounts.map(\.id) + d.cards.map(\.id) + d.credits.map(\.id)
    #expect(Set(ids).count == ids.count)
    let userIds = Set(d.transactions.map(\.userId))
    #expect(userIds == [DemoDataGenerator.userId])
  }

  @Test func balancesMatchTheDatabaseViews() {
    let d = demo()
    for a in d.accounts {
      let expected = d.transactions.filter { $0.accountId == a.id }.reduce(0) { $0 + $1.value }
      #expect(abs(a.balance - expected) < 0.01)
    }
    for c in d.cards {
      // Deferred installments are not part of the card ledger balance.
      let expected = d.transactions.filter { $0.cardId == c.id && $0.creditKey == nil }.reduce(0) { $0 + $1.value }
      #expect(abs(c.balance - expected) < 0.01)
    }
    #expect(d.accounts.contains { abs($0.balance) > 1 })
    #expect(d.accounts.reduce(0) { $0 + $1.balance } > 0)
  }

  @Test func transfersAreBalancedPairs() {
    let d = demo()
    let groups = Dictionary(grouping: d.transactions.filter(\.isTransferLeg), by: { $0.transferGroupId! })
    #expect(!groups.isEmpty)
    for (_, legs) in groups {
      #expect(legs.count == 2)
      #expect(abs(legs.reduce(0) { $0 + $1.value }) < 0.005)
      #expect(Set(legs.map(\.transactedAt)).count == 1)
    }
    // They collapse into single rows in the ledger, like real transfers.
    let day = Ledger.groupedByDay(d.transactions)
    let rows = day.flatMap(\.rows)
    #expect(rows.contains { if case .transfer = $0 { true } else { false } })
  }

  @Test func deferredPurchasesAreConsistent() {
    let d = demo()
    #expect(d.credits.count >= 3)
    for credit in d.credits {
      let rows = d.transactions.filter { $0.creditId == credit.id }.sorted { $0.transactedAt < $1.transactedAt }
      #expect(rows.count == credit.termMonths)
      #expect(rows.allSatisfy { $0.ignore && $0.value < 0 && $0.cardId != nil && $0.accountId == nil })
      #expect(rows.allSatisfy { $0.creditTransactedAt == credit.transactedAt })
      #expect(Set(rows.compactMap(\.cardId)).count == 1)
      // Installments are numbered "(n/total)".
      #expect(rows.enumerated().allSatisfy { $1.description?.hasPrefix("(\($0 + 1)/\(credit.termMonths))") == true })
    }
    // The Credits tab needs paid and pending installments.
    let totals = CreditLedger.totalsByCard(d.transactions.filter(\.isCreditInstallment))
    #expect(totals.values.contains { $0.billed < 0 })
    #expect(totals.values.contains { $0.pending < 0 })
  }

  @Test func loansHaveSchedulesAndPaidInstallments() {
    let now = Date.now
    let d = demo(now: now)
    for loan in d.loans {
      let payments = d.capitalPayments.filter { $0.loanId == loan.id }
      let schedule = LoanMath.schedule(loan, capitalPayments: payments)
      #expect(!schedule.isEmpty)
      #expect(schedule.contains { $0.isPaid(today: now) })
      #expect(schedule.contains { !$0.isPaid(today: now) })
      #expect(LoanMath.listAmounts(loan, capitalPayments: payments, today: now).pending > 0)
    }
    let loansWithExtra = Set(d.capitalPayments.map(\.loanId))
    #expect(d.loans.contains { loansWithExtra.contains($0.id) })
    // Paid installments are in the ledger, drawn from the loan's account.
    let loanRows = d.transactions.filter { $0.categoryName == "Loans" }
    #expect(!loanRows.isEmpty)
    #expect(loanRows.allSatisfy { $0.accountId == d.loans[0].accountId && $0.value < 0 })
  }

  @Test func dashboardsHaveSomethingToShow() {
    let now = Date.now
    let d = demo(now: now)
    let options = DashboardOptions()
    let year = WalletCalendar.year(now)
    let income = YearlyMath.byMonth(d.transactions, year: year, kind: .income, options: options)
    let outcome = YearlyMath.byMonth(d.transactions, year: year, kind: .outcome, options: options)
    #expect(income.contains { $0 > 0 })
    #expect(outcome.contains { $0 > 0 })
    let thisMonth = d.transactions.filter { WalletCalendar.isSameMonth($0.transactedAt, now) }
    #expect(ExpensePie.slices(thisMonth, .category, options: options, filter: nil).count >= 2)
    #expect(ExpensePie.slices(thisMonth, .tag, options: options, filter: nil).count >= 2)
    let totals = Ledger.totals(thisMonth, weighted: true)
    #expect(totals.income > 0 && totals.outcome > 0)
  }

  @Test func exercisesIgnoredAndPartialRows() {
    // Over several seeds the generator uses the optional fields too.
    let rows = (1...5 as ClosedRange<UInt64>).flatMap { demo(seed: $0).transactions }
    #expect(rows.contains { $0.percentage < 100 })
    #expect(rows.contains { $0.ignore && !$0.isCreditInstallment })
    #expect(rows.contains { $0.accountId != nil && $0.value > 0 })
  }

  @Test func recurringMovementsCoverMonthlyAndYearly() {
    let d = demo()
    let estimates = YearlyEstimates(recurring: d.recurringMovements)
    #expect(estimates.recurringIncome > 0)
    #expect(estimates.recurringOutcome > 0)
  }
}

@Suite struct DemoRandomTests {
  @Test func uuidsAreValidAndDistinct() {
    var rng = DemoRandom(seed: 1)
    let ids = (0..<500).map { _ in rng.uuid() }
    #expect(Set(ids).count == 500)
    #expect(ids.allSatisfy { UUID(uuidString: $0) != nil && $0 == $0.lowercased() })
  }

  @Test func moneyHasTwoDecimalsAndStaysInRange() {
    var rng = DemoRandom(seed: 3)
    for _ in 0..<200 {
      let v = rng.money(5...50)
      #expect(v >= 5 && v <= 50)
      #expect(abs(v * 100 - (v * 100).rounded()) < 1e-6)
    }
  }
}
