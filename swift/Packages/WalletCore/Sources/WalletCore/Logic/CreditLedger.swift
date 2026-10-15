import Foundation

/// Installments of one deferred purchase, oldest first.
public struct CreditGroup: Identifiable, Hashable, Sendable {
  public var id: String
  public var rows: [Transaction]
}

/// Posted vs still-to-come deferred installments of one card.
public struct CardCreditTotals: Hashable, Sendable {
  public var billed: Double = 0
  public var pending: Double = 0
  public init(billed: Double = 0, pending: Double = 0) {
    self.billed = billed
    self.pending = pending
  }
}

public enum CreditLedger {
  /// Groups by credit id; newest groups (by latest date) first.
  public static func grouped(_ flat: [Transaction]) -> [CreditGroup] {
    var map: [String: [Transaction]] = [:]
    for t in flat {
      guard let k = t.creditKey else { continue }
      map[k, default: []].append(t)
    }
    let groups = map.map { CreditGroup(id: $0.key, rows: $0.value.sorted { $0.transactedAt < $1.transactedAt }) }
    return groups.sorted { ($0.rows.last?.transactedAt ?? .distantPast) > ($1.rows.last?.transactedAt ?? .distantPast) }
  }

  /// Posted when the local due day is today or earlier.
  public static func isPaidThroughToday(_ t: Transaction, today: Date = .now) -> Bool {
    WalletCalendar.startOfDay(t.transactedAt) <= WalletCalendar.startOfDay(today)
  }

  public static func totalsByCard(_ flat: [Transaction], today: Date = .now) -> [String: CardCreditTotals] {
    var out: [String: CardCreditTotals] = [:]
    for t in flat where t.creditKey != nil {
      guard let card = t.cardId, !card.isEmpty else { continue }
      if isPaidThroughToday(t, today: today) {
        out[card, default: .init()].billed += t.value
      } else {
        out[card, default: .init()].pending += t.value
      }
    }
    return out
  }

  /// Card ledger plus installments already posted (the main card amount).
  public static func postedBalance(_ ledgerBalance: Double, _ credits: CardCreditTotals?) -> Double {
    ledgerBalance + (credits?.billed ?? 0)
  }

  /// Installments whose local date falls in [monthStart]'s month.
  public static func installments(inMonth monthStart: Date, _ flat: [Transaction]) -> [Transaction] {
    flat.filter { $0.creditKey != nil && WalletCalendar.isSameMonth($0.transactedAt, monthStart) }
  }

  static func firstDayAfter(_ monthStart: Date) -> Date { WalletCalendar.monthStart(monthStart, offset: 1) }

  public static func totalValue(group: String, _ flat: [Transaction]) -> Double {
    flat.filter { $0.creditKey == group }.reduce(0) { $0 + $1.value }
  }

  public static func installmentCount(group: String, _ flat: [Transaction]) -> Int {
    flat.filter { $0.creditKey == group }.count
  }

  /// Installments due after [monthStart]'s month.
  public static func countAfter(month monthStart: Date, group: String, _ flat: [Transaction]) -> Int {
    let cutoff = firstDayAfter(monthStart)
    return flat.filter { $0.creditKey == group && WalletCalendar.startOfDay($0.transactedAt) >= cutoff }.count
  }

  public static func valueAfter(month monthStart: Date, group: String, _ flat: [Transaction]) -> Double {
    let cutoff = firstDayAfter(monthStart)
    return flat.filter { $0.creditKey == group && WalletCalendar.startOfDay($0.transactedAt) >= cutoff }
      .reduce(0) { $0 + $1.value }
  }

  /// Groups ending this month first, then 1 pending, 2 pending…; ties keep incoming order.
  public static func sortedByPending(_ groups: [CreditGroup], _ flat: [Transaction], month: Date) -> [CreditGroup] {
    let pending = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, countAfter(month: month, group: $0.id, flat)) })
    return groups.enumerated().sorted {
      let a = pending[$0.element.id]!, b = pending[$1.element.id]!
      return a != b ? a < b : $0.offset < $1.offset
    }.map(\.element)
  }

  /// Unpaid installments due on or after the first day of [monthStart].
  public static func pendingTotal(from monthStart: Date, _ flat: [Transaction], today: Date = .now) -> Double {
    let first = WalletCalendar.startOfMonth(monthStart)
    return flat.filter {
      $0.creditKey != nil && !isPaidThroughToday($0, today: today)
        && WalletCalendar.startOfDay($0.transactedAt) >= first
    }.reduce(0) { $0 + $1.value }
  }

  public static func dueIn(month monthStart: Date, _ flat: [Transaction]) -> Double {
    installments(inMonth: monthStart, flat).reduce(0) { $0 + $1.value }
  }

  /// Installments due this month of the credits with nothing left afterwards.
  public static func endingInMonthTotal(_ monthStart: Date, _ flat: [Transaction]) -> Double {
    grouped(installments(inMonth: monthStart, flat))
      .filter { countAfter(month: monthStart, group: $0.id, flat) == 0 }
      .reduce(0) { $0 + $1.rows.reduce(0) { $0 + $1.value } }
  }

  /// The one installment left after this month, for credits with exactly one left.
  public static func endingNextMonthTotal(_ monthStart: Date, _ flat: [Transaction]) -> Double {
    grouped(installments(inMonth: monthStart, flat))
      .filter { countAfter(month: monthStart, group: $0.id, flat) == 1 }
      .reduce(0) { $0 + valueAfter(month: monthStart, group: $1.id, flat) }
  }
}

public enum DeferredCreditSchedule {
  public enum ScheduleError: Error { case termTooShort, negativeGrace }

  /// Local due dates for each installment of a deferred card purchase.
  ///
  /// [graceMonths] full billing cycles are skipped before the first payment. If
  /// the purchase day is on or after [cardCutDay] the purchase month is past the
  /// cut and one extra month is skipped. Each installment keeps the purchase day
  /// (clamped) and time of day.
  public static func installments(purchase: Date, graceMonths: Int, termMonths: Int, cardCutDay: Int) throws -> [Date] {
    guard termMonths >= 2 else { throw ScheduleError.termTooShort }
    guard graceMonths >= 0 else { throw ScheduleError.negativeGrace }
    let cal = WalletCalendar.self
    let extra = cal.day(purchase) < cardCutDay ? 0 : 1
    let firstMonthOffset = graceMonths + extra
    let first = cal.dayInMonth(
      year: cal.year(purchase), month: cal.month(purchase) + firstMonthOffset, day: cal.day(purchase),
      timeFrom: purchase)
    return (0..<termMonths).map { cal.addCalendarMonths(first, $0) }
  }
}
