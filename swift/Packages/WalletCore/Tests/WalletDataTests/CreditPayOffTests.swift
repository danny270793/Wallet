import Foundation
import Testing
import WalletCore

@testable import WalletData

private let label = "Credit payoff"

private func repo() -> WalletRepository {
  WalletRepository(demo: DemoStore(DemoDataGenerator.make(seed: 11)))
}

/// A 3-installment deferred purchase on [card], all due after today.
private func addCredit(_ r: WalletRepository, card: Card, name: String, value: Double) async throws -> String {
  try await r.createTransaction(
    WalletRepository.TransactionDraft(cardId: card.id, description: name, transactedAt: .now, value: value),
    deferred: true, graceMonths: 3, termMonths: 3)
  let rows = try await r.creditInstallments().value.filter { $0.description?.contains(name) == true }
  return try #require(rows.first?.creditId)
}

private func paymentLegs(_ r: WalletRepository) async throws -> [WalletCore.Transaction] {
  try await r.transactions(month: .now).value.filter { $0.description == label }
}

@Suite struct CreditPayOffTests {
  @Test func oneCardPaymentCoversEveryInstallmentAndHidesThem() async throws {
    let r = repo()
    let card = try #require(try await r.cards().value.first)
    let account = try #require(try await r.accounts().value.first)
    let credit = try await addCredit(r, card: card, name: "ZZ Couch", value: -300)

    #expect(try await r.payOffCredits([credit], fromAccount: account.id, description: label))

    // Off every list...
    #expect(try await r.creditInstallments().value.filter { $0.creditId == credit }.isEmpty)
    #expect(try await r.transactions(throughYear: .now).value.filter { $0.creditId == credit }.isEmpty)
    // ...but the card balance and a whole-credit delete still see them.
    #expect(try await r.creditInstallments(includePaid: true).value.filter { $0.creditId == credit }.count == 3)
    #expect(try await r.installments(credit: credit).count == 3)

    // A single transfer: outflow on the account, inflow on the card, same total.
    let legs = try await paymentLegs(r)
    #expect(legs.count == 2)
    let out = try #require(legs.first { $0.accountId == account.id })
    let into = try #require(legs.first { $0.cardId == card.id })
    #expect(abs(out.value - -300) < 0.005)
    #expect(abs(into.value - 300) < 0.005)
    #expect(out.transferGroupId != nil && out.transferGroupId == into.transferGroupId)
  }

  @Test func severalCreditsOnTheSameCardShareOnePayment() async throws {
    let r = repo()
    let card = try #require(try await r.cards().value.first)
    let account = try #require(try await r.accounts().value.first)
    let a = try await addCredit(r, card: card, name: "ZZ Couch", value: -300)
    let b = try await addCredit(r, card: card, name: "ZZ Table", value: -150)

    try await r.payOffCredits([a, b], fromAccount: account.id, description: label)

    let legs = try await paymentLegs(r)
    #expect(legs.count == 2)
    #expect(abs((legs.first { $0.accountId == account.id }?.value ?? 0) - -450) < 0.005)
  }

  @Test func deletingThePaymentMakesTheInstallmentsOwedAgain() async throws {
    let r = repo()
    let card = try #require(try await r.cards().value.first)
    let account = try #require(try await r.accounts().value.first)
    let credit = try await addCredit(r, card: card, name: "ZZ Couch", value: -300)
    try await r.payOffCredits([credit], fromAccount: account.id, description: label)
    let out = try #require(try await paymentLegs(r).first { $0.accountId == account.id })

    try await r.deleteTransaction(id: out.id)

    let back = try await r.creditInstallments().value.filter { $0.creditId == credit }
    #expect(back.count == 3)
    #expect(back.allSatisfy { $0.paidByTransactionId == nil })
  }

  @Test func nothingPendingIsANoOp() async throws {
    let r = repo()
    let card = try #require(try await r.cards().value.first)
    let account = try #require(try await r.accounts().value.first)
    let credit = try await addCredit(r, card: card, name: "ZZ Couch", value: -300)
    try await r.payOffCredits([credit], fromAccount: account.id, description: label)
    #expect(try await r.payOffCredits([credit], fromAccount: account.id, description: label) == false)
    #expect(try await paymentLegs(r).count == 2)
  }

  @Test func aCreditWithNothingLeftIsSettled() {
    let now = Date.now
    func row(_ id: String, monthsAhead: Int, paidBy: String? = nil) -> WalletCore.Transaction {
      Transaction(
        id: id, userId: "u", cardId: "c", transactedAt: WalletCalendar.monthStart(now, offset: monthsAhead),
        value: -10, creditId: "k", paidByTransactionId: paidBy, createdAt: now, updatedAt: now)
    }
    #expect(CreditLedger.settledIds([row("a", monthsAhead: -2), row("b", monthsAhead: -1)]) == ["k"])
    #expect(CreditLedger.settledIds([row("a", monthsAhead: -1), row("b", monthsAhead: 1)]).isEmpty)
    // Installments paid early count as settled too.
    #expect(CreditLedger.settledIds([row("a", monthsAhead: -1), row("b", monthsAhead: 1, paidBy: "p")]) == ["k"])
  }
}
