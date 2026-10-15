import Foundation
import Testing

@testable import WalletCore

private let epoch = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01 UTC

private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { WalletCalendar.date(y, m, day) }

private func loan(value: Double = 1000, rate: Double? = nil, term: Int = 12, day: Int = 30, first: Date? = nil) -> Loan {
  Loan(
    id: "l", userId: "u", accountId: "a", name: "Loan", value: value, nominalInterestRate: rate,
    termMonths: term, paymentDay: day, firstPaymentDate: first ?? d(2026, 1, 30), createdAt: epoch,
    updatedAt: epoch)
}

private func capital(_ value: Double, _ paidAt: Date) -> LoanCapitalPayment {
  LoanCapitalPayment(id: "c\(value)", userId: "u", loanId: "l", value: value, paidAt: paidAt, createdAt: epoch)
}

private func installments(_ s: [LoanScheduleEntry]) -> [LoanInstallment] { s.compactMap(\.installment) }

@Suite struct LoanScheduleTests {
  @Test func noRateSplitsEvenly() {
    let s = installments(LoanMath.schedule(loan(value: 1200, term: 12)))
    #expect(s.count == 12)
    #expect(s.allSatisfy { abs($0.payment - 100) < 1e-9 })
    #expect(s.last?.remaining == 0)
  }

  @Test func fixedPaymentWithInterestPaysOff() {
    let s = installments(LoanMath.schedule(loan(value: 10000, rate: 12, term: 12)))
    #expect(abs(s.first!.payment - 888.49) < 0.01)
    #expect(abs(s.first!.interest - 100) < 1e-9)
    #expect(abs(s.last!.payment - 888.49) < 0.01)
    #expect(abs(s.reduce(0) { $0 + $1.principal } - 10000) < 1e-6)
    #expect(s.last?.remaining == 0)
  }

  @Test func dueDatesClampToShortMonths() {
    let s = LoanMath.schedule(loan(term: 3))
    #expect(s.map(\.date) == [d(2026, 1, 30), d(2026, 2, 28), d(2026, 3, 30)])
  }

  @Test func firstInstallmentUsesOwnDate() {
    let s = LoanMath.schedule(loan(term: 3, day: 5, first: d(2026, 11, 20)))
    #expect(s.map(\.date) == [d(2026, 11, 20), d(2026, 12, 5), d(2027, 1, 5)])
  }

  @Test func capitalPaymentLowersLaterInstallments() {
    let s = LoanMath.schedule(loan(value: 1200, term: 12), capitalPayments: [capital(600, d(2026, 6, 15))])
    let inst = installments(s)
    #expect(inst.count == 12)
    #expect(abs(inst[4].payment - 100) < 1e-9)
    #expect(abs(inst[5].payment - 100.0 / 7) < 1e-9)
    #expect(inst.last?.remaining == 0)
    let idx = s.firstIndex { if case .capitalPayment = $0 { true } else { false } }
    #expect(idx == 5)
    #expect(abs(s[5].remaining - 100) < 1e-9)
  }

  @Test func capitalPaymentOfWholeBalanceEndsSchedule() {
    let s = LoanMath.schedule(loan(value: 1200, term: 12), capitalPayments: [capital(1100, d(2026, 2, 1))])
    #expect(installments(s).count == 1)
    #expect(s.last?.installment == nil)
    #expect(s.last?.remaining == 0)
  }

  @Test func pastEntriesArePaid() {
    let s = LoanMath.schedule(loan(term: 3))
    #expect(s.map { $0.isPaid(today: d(2026, 2, 28)) } == [true, true, false])
  }

  @Test func loanRoundTripsThroughJSON() throws {
    let l = loan()
    let data = try WalletJSON.encoder.encode(l)
    #expect(String(data: data, encoding: .utf8)!.contains("\"firstPaymentDate\":\"2026-01-30\""))
    #expect(try WalletJSON.decoder.decode(Loan.self, from: data) == l)
  }
}
