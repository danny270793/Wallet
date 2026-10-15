import Foundation

/// One row of a loan's payment plan.
public enum LoanScheduleEntry: Hashable, Sendable {
  case installment(LoanInstallment)
  case capitalPayment(LoanCapitalPayment, remaining: Double)

  public var date: Date {
    switch self {
    case .installment(let i): i.date
    case .capitalPayment(let p, _): p.paidAt
    }
  }

  /// Principal still owed after this row.
  public var remaining: Double {
    switch self {
    case .installment(let i): i.remaining
    case .capitalPayment(_, let r): r
    }
  }

  /// Amount paid in this row.
  public var payment: Double {
    switch self {
    case .installment(let i): i.payment
    case .capitalPayment(let p, _): p.value
    }
  }

  public var installment: LoanInstallment? {
    if case .installment(let i) = self { return i }
    return nil
  }

  /// Installments are paid once their date is today or earlier; capital payments always are.
  public func isPaid(today: Date = .now) -> Bool {
    switch self {
    case .capitalPayment: true
    case .installment(let i): i.date <= WalletCalendar.startOfDay(today)
    }
  }
}

public struct LoanInstallment: Hashable, Sendable {
  public var number: Int
  public var date: Date
  public var payment: Double
  public var interest: Double
  public var principal: Double
  public var remaining: Double
}

public enum LoanMath {
  /// Fixed-payment (French) amortization: monthly rate = nominal annual / 12;
  /// with no rate the balance is split evenly.
  ///
  /// A capital payment dated before an installment lowers the balance first,
  /// and the remaining installments are recomputed over the same months left
  /// (the term stays, the monthly amount drops). Installments stop once the
  /// balance reaches 0; the last one absorbs rounding.
  public static func schedule(_ loan: Loan, capitalPayments: [LoanCapitalPayment] = []) -> [LoanScheduleEntry] {
    let n = loan.termMonths
    guard n > 0 else { return [] }
    let r = (loan.nominalInterestRate ?? 0) / 100 / 12
    let pending = capitalPayments.filter { $0.loanId == loan.id }.sorted {
      $0.paidAt != $1.paidAt ? $0.paidAt < $1.paidAt : $0.createdAt < $1.createdAt
    }

    var out: [LoanScheduleEntry] = []
    var balance = loan.value
    var p = 0

    func applyCapital(_ c: LoanCapitalPayment) {
      balance = max(0, balance - c.value)
      out.append(.capitalPayment(c, remaining: balance))
    }

    var i = 1
    while i <= n && balance > 1e-6 {
      let due = installmentDueDate(loan, index: i - 1)
      while p < pending.count && pending[p].paidAt < due {
        applyCapital(pending[p])
        p += 1
      }
      if balance <= 1e-6 { break }
      let left = n - i + 1
      // Recomputing every month keeps rounding from drifting; it equals the
      // fixed payment whenever no capital payment happened.
      let payment = annuity(balance, r, left)
      let interest = balance * r
      var principal = payment - interest
      if i == n || principal > balance { principal = balance }
      balance -= principal
      if abs(balance) < 1e-6 { balance = 0 }
      out.append(
        .installment(
          LoanInstallment(
            number: i, date: due, payment: principal + interest, interest: interest,
            principal: principal, remaining: balance)))
      i += 1
    }
    while p < pending.count {
      applyCapital(pending[p])
      p += 1
    }
    return out
  }

  static func annuity(_ balance: Double, _ r: Double, _ months: Int) -> Double {
    r == 0 ? balance / Double(months) : balance * r / (1 - pow(1 + r, -Double(months)))
  }

  /// Installment [index] (0 = first): `firstPaymentDate`, then `paymentDay` of
  /// each following month, clamped to short months.
  public static func installmentDueDate(_ loan: Loan, index: Int) -> Date {
    if index == 0 { return loan.firstPaymentDate }
    let first = loan.firstPaymentDate
    return WalletCalendar.dayInMonth(
      year: WalletCalendar.year(first), month: WalletCalendar.month(first) + index, day: loan.paymentDay)
  }

  /// Current monthly installment: the next unpaid one, or the last if all are paid.
  public static func currentPayment(_ loan: Loan, capitalPayments: [LoanCapitalPayment] = [], today: Date = .now)
    -> Double
  {
    let installments = schedule(loan, capitalPayments: capitalPayments).compactMap(\.installment)
    guard let last = installments.last else { return 0 }
    return installments.first { $0.date > WalletCalendar.startOfDay(today) }?.payment ?? last.payment
  }

  /// Principal owed at the end of [date].
  public static func balance(on date: Date, _ loan: Loan, capitalPayments: [LoanCapitalPayment] = []) -> Double {
    var balance = loan.value
    for e in schedule(loan, capitalPayments: capitalPayments) {
      if e.date > date { break }
      balance = e.remaining
    }
    return balance
  }

  /// The three amounts of a loan row: current installment, pending and total debt.
  public static func listAmounts(_ loan: Loan, capitalPayments: [LoanCapitalPayment], today: Date = .now)
    -> (monthly: Double, pending: Double, total: Double)
  {
    let s = schedule(loan, capitalPayments: capitalPayments)
    let total = s.reduce(0) { $0 + $1.payment }
    let paid = s.filter { $0.isPaid(today: today) }.reduce(0) { $0 + $1.payment }
    return (currentPayment(loan, capitalPayments: capitalPayments, today: today), total - paid, total)
  }

  /// `name (xx.xx %)` when the loan has a rate.
  public static func title(_ loan: Loan) -> String {
    guard let rate = loan.nominalInterestRate else { return loan.name }
    return "\(loan.name) (\(rate.fixed2) %)"
  }
}
