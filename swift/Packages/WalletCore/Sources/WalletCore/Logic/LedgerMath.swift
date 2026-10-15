import Foundation

public struct Totals: Hashable, Sendable {
  public var income: Double = 0
  public var outcome: Double = 0
  public var balance: Double = 0
  public init(income: Double = 0, outcome: Double = 0, balance: Double = 0) {
    self.income = income
    self.outcome = outcome
    self.balance = balance
  }
}

/// The five ways the transactions footer sums a month (swipe between them).
public enum TotalsMode: Int, CaseIterable, Sendable {
  case weighted, weightedExcludingCredit, weightedExcludingIgnored, notWeighted, notWeightedExcludingIgnored

  public func totals(_ txs: [Transaction]) -> Totals {
    switch self {
    case .weighted: Ledger.totals(txs, weighted: true)
    case .weightedExcludingCredit: Ledger.totals(txs, weighted: true) { !$0.isCreditInstallment }
    case .weightedExcludingIgnored: Ledger.totals(txs, weighted: true) { !$0.ignore }
    case .notWeighted: Ledger.totals(txs, weighted: false)
    case .notWeightedExcludingIgnored: Ledger.totals(txs, weighted: false) { !$0.ignore }
    }
  }
}

/// Row of a day-grouped transaction list.
public enum LedgerRow: Hashable, Sendable, Identifiable {
  case transaction(Transaction)
  case transfer(source: Transaction, target: Transaction)

  public var id: String {
    switch self {
    case .transaction(let t): t.id
    case .transfer(let s, let t): "pair_\(s.transferGroupId ?? "\(s.id)|\(t.id)")"
    }
  }
}

public struct LedgerDay: Hashable, Sendable, Identifiable {
  public var day: Date
  public var rows: [LedgerRow]
  public var id: Date { day }
}

public enum Ledger {
  /// Income (positives), outcome (absolute negatives) and net. Transfer legs never count.
  public static func totals(
    _ txs: [Transaction], weighted: Bool, include: (Transaction) -> Bool = { _ in true }
  ) -> Totals {
    var t = Totals()
    for tx in txs where !tx.isTransferLeg && include(tx) {
      let v = tx.amount(weighted: weighted)
      t.balance += v
      if v > 0 { t.income += v } else if v < 0 { t.outcome += -v }
    }
    return t
  }

  /// Days newest first, rows newest first; the two legs of a transfer become one row.
  ///
  /// With [fillFrom]..<[fillTo], every day in the range is listed even with no rows.
  public static func groupedByDay(_ list: [Transaction], fillFrom: Date? = nil, fillTo: Date? = nil) -> [LedgerDay] {
    var byDay: [Date: [Transaction]] = [:]
    for t in list { byDay[WalletCalendar.startOfDay(t.transactedAt), default: []].append(t) }
    var days = Set(byDay.keys)
    if let from = fillFrom, let to = fillTo {
      var d = WalletCalendar.startOfDay(from)
      let end = WalletCalendar.startOfDay(to)
      while d < end {
        days.insert(d)
        d = WalletCalendar.addDays(d, 1)
      }
    }
    return days.sorted(by: >).map { day in
      let dayList = (byDay[day] ?? []).sorted { $0.transactedAt > $1.transactedAt }
      var byGroup: [String: [Transaction]] = [:]
      for t in dayList where t.isTransferLeg { byGroup[t.transferGroupId!, default: []].append(t) }
      var used = Set<String>()
      var rows: [LedgerRow] = []
      for t in dayList {
        guard t.isTransferLeg, let gid = t.transferGroupId else {
          rows.append(.transaction(t))
          continue
        }
        if used.contains(t.id) { continue }
        let peers = byGroup[gid] ?? []
        if peers.count == 2, let src = peers.first(where: { $0.value < 0 }),
          let tgt = peers.first(where: { $0.value > 0 }), abs(abs(src.value) - abs(tgt.value)) < 0.0001
        {
          rows.append(.transfer(source: src, target: tgt))
          used.insert(src.id)
          used.insert(tgt.id)
          continue
        }
        rows.append(.transaction(t))
      }
      return LedgerDay(day: day, rows: rows)
    }
  }

  public struct Scope: Hashable, Sendable {
    public var accountId: String?
    public var cardId: String?
    public var categoryId: String?
    public var tagId: String?
    public var title: String?

    public init(
      accountId: String? = nil, cardId: String? = nil, categoryId: String? = nil, tagId: String? = nil,
      title: String? = nil
    ) {
      self.accountId = accountId
      self.cardId = cardId
      self.categoryId = categoryId
      self.tagId = tagId
      self.title = title
    }

    public static let all = Scope()
    public var isScoped: Bool { accountId != nil || cardId != nil || categoryId != nil || tagId != nil }
    public var isPaymentMethod: Bool { accountId != nil || cardId != nil }

    public func matches(_ t: Transaction) -> Bool {
      if let accountId, t.accountId != accountId { return false }
      if let cardId, t.cardId != cardId { return false }
      if let categoryId, t.categoryId != categoryId { return false }
      if let tagId, t.tagId != tagId { return false }
      return true
    }
  }

  /// Account/card views keep the other transfer leg so the row shows its direction.
  /// Totals still use the strictly filtered list.
  public static func withTransferPeers(_ filtered: [Transaction], all: [Transaction], scope: Scope) -> [Transaction] {
    guard scope.isPaymentMethod else { return filtered }
    let groups = Set(filtered.compactMap { $0.isTransferLeg ? $0.transferGroupId : nil })
    guard !groups.isEmpty else { return filtered }
    var byId = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
    for t in all where t.transferGroupId.map(groups.contains) == true { byId[t.id] = t }
    return byId.values.sorted { $0.transactedAt > $1.transactedAt }
  }

  /// Case-insensitive description match.
  public static func matching(_ txs: [Transaction], query: String) -> [Transaction] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return [] }
    return txs.filter { ($0.description ?? "").lowercased().contains(needle) }
  }

  public static func mergeNewestFirst(_ a: [Transaction], _ b: [Transaction]) -> [Transaction] {
    var byId: [String: Transaction] = [:]
    for t in a + b { byId[t.id] = t }
    return byId.values.sorted { $0.transactedAt > $1.transactedAt }
  }
}

// MARK: - Dashboard pies

/// Which dimension an expense pie groups by.
public enum PieDimension: Sendable {
  case tag, category

  func key(_ t: Transaction) -> String? {
    let id = self == .tag ? t.tagId : t.categoryId
    return (id ?? "").isEmpty ? nil : id
  }

  func label(_ t: Transaction) -> String? {
    let n = self == .tag ? t.tagName : t.categoryName
    return (n ?? "").isEmpty ? nil : n
  }
}

public struct PieSlice: Hashable, Sendable, Identifiable {
  public var key: String
  public var label: String
  public var expense: Double
  public var id: String { key }
}

/// Dashboard filters shared by the monthly and yearly views.
public struct DashboardOptions: Hashable, Sendable {
  /// Ignored rows count toward totals and charts.
  public var includeIgnored = true
  /// `value × percentage` instead of the full value.
  public var useWeightedAmounts = true
  /// When off, deferred installments are left out entirely.
  public var showCredits = true
  public init() {}
}

public enum ExpensePie {
  static func fallbackLabel(_ key: String) -> String { "#" + key.prefix(8) }

  /// Keys with at least one expense in [txs], sorted by label.
  public static func options(_ txs: [Transaction], _ dim: PieDimension, options o: DashboardOptions)
    -> [(key: String, label: String)]
  {
    var labels: [String: String] = [:]
    var seen = Set<String>()
    for t in txs where o.includeIgnored || !t.ignore {
      guard let k = dim.key(t), t.amount(weighted: o.useWeightedAmounts) < 0 else { continue }
      seen.insert(k)
      if let l = dim.label(t) { labels[k] = l }
    }
    return seen.map { (key: $0, label: labels[$0] ?? fallbackLabel($0)) }
      .sorted { $0.label.lowercased() < $1.label.lowercased() }
  }

  /// Drops stale keys; "everything selected" normalizes to nil (no filter).
  public static func prune(_ filter: Set<String>?, _ txs: [Transaction], _ dim: PieDimension, options o: DashboardOptions)
    -> Set<String>?
  {
    guard let filter else { return nil }
    let valid = Set(options(txs, dim, options: o).map(\.key))
    let pruned = filter.intersection(valid)
    return pruned.isEmpty || pruned.count == valid.count ? nil : pruned
  }

  /// Expense totals per key, largest first.
  public static func slices(
    _ txs: [Transaction], _ dim: PieDimension, options o: DashboardOptions, filter: Set<String>?
  ) -> [PieSlice] {
    var sums: [String: Double] = [:]
    var labels: [String: String] = [:]
    for t in txs where o.includeIgnored || !t.ignore {
      guard let k = dim.key(t) else { continue }
      if let filter, !filter.contains(k) { continue }
      let w = t.amount(weighted: o.useWeightedAmounts)
      guard w < 0 else { continue }
      sums[k, default: 0] += -w
      if let l = dim.label(t) { labels[k] = l }
    }
    return sums.filter { $0.value >= 1e-9 }
      .map { PieSlice(key: $0.key, label: labels[$0.key] ?? fallbackLabel($0.key), expense: $0.value) }
      .sorted { $0.expense > $1.expense }
  }

  public static func restrict(_ txs: [Transaction], _ dim: PieDimension, to filter: Set<String>?) -> [Transaction] {
    guard let filter else { return txs }
    return txs.filter { dim.key($0).map(filter.contains) == true }
  }
}

/// The filtered sets a dashboard shows: each pie is narrowed by the other's
/// filter, and the list/totals by both.
public struct DashboardSlice: Sendable {
  public var tagFilter: Set<String>?
  public var categoryFilter: Set<String>?
  public var tagPieTransactions: [Transaction]
  public var categoryPieTransactions: [Transaction]
  public var listTransactions: [Transaction]

  public init(
    _ txs: [Transaction], options o: DashboardOptions, tagFilter: Set<String>?, categoryFilter: Set<String>?
  ) {
    let base = o.showCredits ? txs : txs.filter { !$0.isCreditInstallment }
    let tf = ExpensePie.prune(tagFilter, base, .tag, options: o)
    let cf = ExpensePie.prune(categoryFilter, base, .category, options: o)
    self.tagFilter = tf
    self.categoryFilter = cf
    tagPieTransactions = ExpensePie.restrict(base, .category, to: cf)
    categoryPieTransactions = ExpensePie.restrict(base, .tag, to: tf)
    listTransactions = ExpensePie.restrict(ExpensePie.restrict(base, .tag, to: tf), .category, to: cf)
      .filter { o.includeIgnored || !$0.ignore }
  }
}
