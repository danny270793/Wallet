import Foundation
import Testing

@testable import WalletCore

private func d(_ y: Int, _ m: Int, _ day: Int = 1) -> Date { WalletCalendar.date(y, m, day) }

private func tx(
  _ at: Date, _ value: Double, account: String? = "a", card: String? = nil, credit: String? = nil,
  percentage: Double = 100, ignore: Bool = false, group: String? = nil, tag: String? = nil
) -> Transaction {
  Transaction(
    id: "\(at.timeIntervalSince1970)_\(value)_\(card ?? "")", userId: "u", accountId: account, cardId: card,
    tagId: tag, transactedAt: at, value: value, ignore: ignore, percentage: percentage, transferGroupId: group,
    creditId: credit, createdAt: at, updatedAt: at)
}

@Suite struct CumulativeProjectionTests {
  let now = d(2026, 9, 24)
  let txs = [tx(d(2025, 12, 10), 1000), tx(d(2026, 3, 5), -200), tx(d(2026, 9, 1), 50), tx(d(2026, 11, 1), -300)]

  @Test func currentYearRealThenRecurring() {
    let r = YearlyMath.cumulativeWithProjection(txs, year: 2026, netForMonth: { _ in 100 }, today: now)
    #expect(r.projectedFromIndex == 9)
    #expect(r.monthly[0] == 1000)
    #expect(r.monthly[2] == 800)
    #expect(r.monthly[8] == 850)
    #expect(r.monthly[9] == 950)
    #expect(r.monthly[10] == 750)
    #expect(r.monthly[11] == 850)
  }

  @Test func pastYearAllReal() {
    let r = YearlyMath.cumulativeWithProjection(txs, year: 2025, netForMonth: { _ in 100 }, today: now)
    #expect(r.projectedFromIndex == 12)
    #expect(r.monthly[11] == 1000)
    #expect(r.monthly[10] == 0)
  }

  @Test func futureYearContinues() {
    let r = YearlyMath.cumulativeWithProjection(txs, year: 2027, netForMonth: { _ in 100 }, today: now)
    #expect(r.projectedFromIndex == 0)
    #expect(r.monthly[0] == 850 - 300 + 100 * 4)
    #expect(r.monthly[11] == 850 - 300 + 100 * 15)
  }

  @Test func monthlyEstimate() {
    let real = (0..<12).map { Double($0 + 1) }
    let cur = YearlyMath.withEstimate(real, year: 2026, estimate: { _ in 50 }, today: now)
    #expect(cur.projectedFromIndex == 9)
    #expect(cur.monthly[8] == 9)
    #expect(cur.monthly[9] == 60)
    #expect(YearlyMath.withEstimate(real, year: 2025, estimate: { _ in 50 }, today: now).monthly == real)
    let future = YearlyMath.withEstimate(real, year: 2027, estimate: { _ in 50 }, today: now)
    #expect(future.monthly[0] == 51)
  }

  @Test func perMonthNetAccumulates() {
    let net: (Date) -> Double = {
      switch WalletCalendar.month($0) {
      case 10: 100
      case 11: 40
      default: 0
      }
    }
    let r = YearlyMath.cumulativeWithProjection(txs, year: 2026, netForMonth: net, today: now)
    #expect(r.monthly[9] == 950)
    #expect(r.monthly[10] == 690)
    #expect(r.monthly[11] == 690)
  }
}

@Suite struct AutomaticMovementTests {
  let today = d(2026, 10, 14)
  let epoch = Date(timeIntervalSince1970: 1_767_225_600)

  var source: AutomaticMovementsSource {
    let card = Card(
      id: "c", userId: "u", name: "Card", createdAt: epoch, updatedAt: epoch, nominalInterestRate: 12, balance: -1000)
    let loan = Loan(
      id: "l", userId: "u", accountId: "a", name: "Loan", value: 1200, termMonths: 12, paymentDay: 30,
      firstPaymentDate: d(2026, 1, 30), createdAt: epoch, updatedAt: epoch)
    return AutomaticMovementsSource(
      loans: [loan], cards: [card],
      creditInstallments: [
        tx(d(2026, 10, 5), -100, account: nil, card: "c", credit: "credit"),
        tx(d(2026, 11, 5), -100, account: nil, card: "c", credit: "credit"),
        tx(d(2026, 12, 5), -100, account: nil, card: "c", credit: "credit"),
      ])
  }

  func amount(_ rows: [AutomaticMovement], _ match: (AutomaticMovement) -> Bool) -> Double {
    rows.filter(match).reduce(0) { $0 + $1.monthlyAmount }
  }

  func isDeferred(_ a: AutomaticMovement) -> Bool { if case .cardDeferred = a { true } else { false } }
  func isInterest(_ a: AutomaticMovement) -> Bool { if case .cardInterest = a { true } else { false } }
  func isLoan(_ a: AutomaticMovement) -> Bool { if case .loan = a { true } else { false } }

  @Test func deferredFollowsMonth() {
    #expect(amount(source.forMonth(d(2026, 11), today: today), isDeferred) == -100)
    #expect(source.forMonth(d(2027, 1), today: today).filter(isDeferred).isEmpty)
  }

  @Test func interestGrowsWithPostedInstallments() {
    #expect(abs(amount(source.forMonth(d(2026, 10), today: today), isInterest) + 11) < 1e-9)
    #expect(abs(amount(source.forMonth(d(2026, 12), today: today), isInterest) + 12) < 1e-9)
  }

  @Test func loanOnlyInMonthsWithInstallment() {
    #expect(abs(amount(source.forMonth(d(2026, 10), today: today), isLoan) + 100) < 1e-9)
    #expect(source.forMonth(d(2027, 1), today: today).filter(isLoan).isEmpty)
  }
}

@Suite struct LedgerTests {
  @Test func totalsSkipTransfersAndWeigh() {
    let txs = [
      tx(d(2026, 1, 2), 100), tx(d(2026, 1, 3), -50, percentage: 50), tx(d(2026, 1, 4), -10, group: "g"),
      tx(d(2026, 1, 4), 10, group: "g"), tx(d(2026, 1, 5), -20, ignore: true),
    ]
    let w = TotalsMode.weighted.totals(txs)
    #expect(w == Totals(income: 100, outcome: 45, balance: 55))
    #expect(TotalsMode.notWeightedExcludingIgnored.totals(txs) == Totals(income: 100, outcome: 50, balance: 50))
  }

  @Test func transferLegsPairIntoOneRow() {
    let days = Ledger.groupedByDay([tx(d(2026, 1, 4), -10, group: "g"), tx(d(2026, 1, 4), 10, account: "b", group: "g")])
    #expect(days.count == 1)
    guard case .transfer(let s, let t) = days[0].rows.first else {
      Issue.record("expected a transfer row")
      return
    }
    #expect(s.value == -10 && t.value == 10)
  }

  @Test func fillRangeListsEmptyDays() {
    let days = Ledger.groupedByDay([tx(d(2026, 1, 2), 1)], fillFrom: d(2026, 1, 1), fillTo: d(2026, 1, 4))
    #expect(days.map(\.day) == [d(2026, 1, 3), d(2026, 1, 2), d(2026, 1, 1)])
    #expect(days[0].rows.isEmpty)
  }

  @Test func deferredScheduleRespectsCutDay() throws {
    let before = try DeferredCreditSchedule.installments(
      purchase: d(2026, 1, 10), graceMonths: 0, termMonths: 3, cardCutDay: 24)
    #expect(before == [d(2026, 1, 10), d(2026, 2, 10), d(2026, 3, 10)])
    let after = try DeferredCreditSchedule.installments(
      purchase: d(2026, 1, 31), graceMonths: 1, termMonths: 2, cardCutDay: 24)
    #expect(after == [d(2026, 3, 31), d(2026, 4, 30)])
  }

  @Test func splitsAmountsWithRemainderLast() {
    #expect(splitEqualAmountParts(100, 3) == [33.33, 33.33, 33.34])
    #expect(splitEqualAmountParts(-10, 4) == [-2.5, -2.5, -2.5, -2.5])
  }

  @Test func parsesAmountInput() {
    #expect(AmountInput.parse("12,5") == 12.5)
    #expect(AmountInput.parse("-3") == -3)
    #expect(AmountInput.parse("abc") == nil)
    #expect(AmountInput.filter("-1a2.3.4", allowNegative: false) == "12.34")
  }

  @Test func pieFiltersNormalize() {
    let txs = [tx(d(2026, 1, 1), -5, tag: "a"), tx(d(2026, 1, 1), -7, tag: "b")]
    let o = DashboardOptions()
    #expect(ExpensePie.prune(["a", "b"], txs, .tag, options: o) == nil)
    #expect(ExpensePie.prune(["a", "zz"], txs, .tag, options: o) == ["a"])
    #expect(ExpensePie.slices(txs, .tag, options: o, filter: nil).map(\.key) == ["b", "a"])
  }

  @Test func decodesPostgrestTransaction() throws {
    let json = """
      {"id":"1","userId":"u","accountId":null,"cardId":"c","value":"-12.5","ignore":true,"percentage":100,
       "transactedAt":"2026-03-01T10:20:30.123456+00:00","createdAt":"2026-03-01T10:20:30+00:00",
       "updatedAt":"2026-03-01T10:20:30Z","wallet_cards":{"name":"Visa"},"wallet_credits":[{"transactedAt":"2026-02-01T00:00:00+00:00"}]}
      """
    let t = try WalletJSON.decoder.decode(Transaction.self, from: Data(json.utf8))
    #expect(t.value == -12.5)
    #expect(t.cardName == "Visa")
    #expect(t.creditTransactedAt != nil)
    let back = try WalletJSON.decoder.decode(Transaction.self, from: WalletJSON.encoder.encode(t))
    #expect(back == t)
  }
}
