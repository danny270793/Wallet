import Foundation

// MARK: - Automatic recurring movements

/// Read-only monthly amount derived from a loan or a card, shown with the
/// user's recurring movements and counted in totals and estimates.
public enum AutomaticMovement: Hashable, Sendable, Identifiable {
  /// The installment of a loan due that month.
  case loan(Loan, installment: Double)
  /// Interest of a card's revolving balance (balance × rate / 12). Positive.
  case cardInterest(Card, interest: Double)
  /// Deferred installments of a card due that month. Negative.
  case cardDeferred(Card, amount: Double)

  /// Prefixed with the kind so it never collides with a movement id.
  public var id: String {
    switch self {
    case .loan(let l, _): "loan:\(l.id)"
    case .cardInterest(let c, _): "card-interest:\(c.id)"
    case .cardDeferred(let c, _): "card-deferred:\(c.id)"
    }
  }

  public var name: String {
    switch self {
    case .loan(let l, _): l.name
    case .cardInterest(let c, _), .cardDeferred(let c, _): c.name
    }
  }

  /// Signed (negative = outcome).
  public var monthlyAmount: Double {
    switch self {
    case .loan(_, let i): -i
    case .cardInterest(_, let i): -i
    case .cardDeferred(_, let a): a
    }
  }

  public var cardType: CardType? {
    switch self {
    case .loan: nil
    case .cardInterest(let c, _), .cardDeferred(let c, _): c.type
    }
  }
}

/// Data behind the automatic rows, loaded once so any month can be computed.
public struct AutomaticMovementsSource: Sendable {
  public var loans: [Loan] = []
  public var capitalPayments: [LoanCapitalPayment] = []
  public var cards: [Card] = []
  public var creditInstallments: [Transaction] = []

  public init(
    loans: [Loan] = [], capitalPayments: [LoanCapitalPayment] = [], cards: [Card] = [],
    creditInstallments: [Transaction] = []
  ) {
    self.loans = loans
    self.capitalPayments = capitalPayments
    self.cards = cards
    self.creditInstallments = creditInstallments
  }

  /// Rows for [month]'s calendar month. Future card spending is unknown, so the
  /// revolving balance is assumed to stay as today, growing only by deferred
  /// installments posted between today and that month.
  public func forMonth(_ month: Date, today: Date = .now) -> [AutomaticMovement] {
    let monthStart = WalletCalendar.startOfMonth(month)
    let nextMonth = WalletCalendar.monthStart(month, offset: 1)
    var out: [AutomaticMovement] = []
    for loan in loans {
      for case .installment(let i) in LoanMath.schedule(loan, capitalPayments: capitalPayments)
      where i.date >= monthStart && i.date < nextMonth {
        out.append(.loan(loan, installment: i.payment))
      }
    }

    let todayDay = WalletCalendar.startOfDay(today)
    let credits = CreditLedger.totalsByCard(creditInstallments, today: today)
    var deferred: [String: Double] = [:]
    var postedBeforeMonth: [String: Double] = [:]
    for t in creditInstallments {
      guard let card = t.cardId else { continue }
      let day = WalletCalendar.startOfDay(t.transactedAt)
      if day >= monthStart && day < nextMonth {
        deferred[card, default: 0] += t.value
      } else if day > todayDay && day < monthStart {
        postedBeforeMonth[card, default: 0] += t.value
      }
    }
    let isPast = nextMonth <= todayDay
    for card in cards {
      let revolving =
        CreditLedger.postedBalance(card.balance, credits[card.id]) + (isPast ? 0 : postedBeforeMonth[card.id] ?? 0)
      let rate = card.nominalInterestRate ?? 0
      let interest = revolving < 0 ? -revolving * rate / 100 / 12 : 0
      if interest >= 0.005 { out.append(.cardInterest(card, interest: interest)) }
      if let d = deferred[card.id], d <= -0.005 { out.append(.cardDeferred(card, amount: d)) }
    }
    return out
  }
}

// MARK: - Yearly dashboard

/// Monthly series for a year: 12 values and where estimates begin.
public struct YearSeries: Hashable, Sendable {
  public var monthly: [Double]
  /// First estimated month index (0–11), or 12 when none.
  public var projectedFromIndex: Int
}

/// Recurring movement totals and loans/cards behind the yearly estimates.
public struct YearlyEstimates: Sendable {
  /// Sum of positive recurring monthly amounts.
  public var recurringIncome: Double = 0
  /// Sum of absolute negative recurring monthly amounts.
  public var recurringOutcome: Double = 0
  public var automatic = AutomaticMovementsSource()

  public init(recurring: [RecurringMovement] = [], automatic: AutomaticMovementsSource = .init()) {
    for m in recurring {
      if m.monthlyAmount > 0 { recurringIncome += m.monthlyAmount } else { recurringOutcome += -m.monthlyAmount }
    }
    self.automatic = automatic
  }

  /// Loan installments and card interest due in [month]. Deferred installments
  /// are left out: they are already transactions dated in their months.
  public func automaticOutcome(_ month: Date, today: Date = .now) -> Double {
    automatic.forMonth(month, today: today).reduce(0) {
      if case .cardDeferred = $1 { return $0 }
      return $0 - $1.monthlyAmount
    }
  }

  public func outcome(_ month: Date, today: Date = .now) -> Double {
    recurringOutcome + automaticOutcome(month, today: today)
  }

  public func net(_ month: Date, today: Date = .now) -> Double {
    recurringIncome - outcome(month, today: today)
  }
}

public enum YearlyMath {
  public enum Kind: Sendable { case income, outcome, net }

  /// Per local month of [year]: positive sums, absolute negatives, or net.
  public static func byMonth(
    _ txs: [Transaction], year: Int, kind: Kind, options o: DashboardOptions
  ) -> [Double] {
    var sums = Array(repeating: 0.0, count: 12)
    for t in txs where !t.isTransferLeg && (o.includeIgnored || !t.ignore) {
      guard WalletCalendar.year(t.transactedAt) == year else { continue }
      let w = t.amount(weighted: o.useWeightedAmounts)
      let i = WalletCalendar.month(t.transactedAt) - 1
      switch kind {
      case .income: if w > 0 { sums[i] += w }
      case .outcome: if w < 0 { sums[i] += -w }
      case .net: sums[i] += w
      }
    }
    return sums
  }

  /// Accounts total at the end of each month of [year], including earlier years.
  public static func accountsCumulative(_ txs: [Transaction], year: Int) -> [Double] {
    (0..<12).map { m in
      let cutoff = WalletCalendar.date(year, m + 2)
      return txs.filter { !($0.accountId ?? "").isEmpty && $0.transactedAt < cutoff }.reduce(0) { $0 + $1.value }
    }
  }

  /// Months after the current one are estimated: 12 for past years, 0 for future ones.
  static func firstEstimatedIndex(year: Int, today: Date) -> Int {
    let y = WalletCalendar.year(today)
    if year < y { return 12 }
    if year > y { return 0 }
    return WalletCalendar.month(today)
  }

  /// Real month-end balance, plus [netForMonth] carried once per month elapsed
  /// after the current one.
  public static func cumulativeWithProjection(
    _ txs: [Transaction], year: Int, netForMonth: (Date) -> Double, today: Date = .now
  ) -> YearSeries {
    let from = firstEstimatedIndex(year: year, today: today)
    let real = accountsCumulative(txs, year: year)
    var monthly = Array(repeating: 0.0, count: 12)
    var carried = 0.0
    var cursor = WalletCalendar.monthStart(today, offset: 1)
    for i in 0..<12 {
      if i < from {
        monthly[i] = real[i]
        continue
      }
      let target = WalletCalendar.date(year, i + 1)
      while cursor <= target {
        carried += netForMonth(cursor)
        cursor = WalletCalendar.monthStart(cursor, offset: 1)
      }
      monthly[i] = real[i] + carried
    }
    return YearSeries(monthly: monthly, projectedFromIndex: from)
  }

  /// Adds [estimate] to each month after the current one.
  public static func withEstimate(
    _ monthly: [Double], year: Int, estimate: (Date) -> Double, today: Date = .now
  ) -> YearSeries {
    let from = firstEstimatedIndex(year: year, today: today)
    return YearSeries(
      monthly: monthly.enumerated().map { i, v in i < from ? v : v + estimate(WalletCalendar.date(year, i + 1)) },
      projectedFromIndex: from)
  }
}
