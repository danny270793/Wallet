import Foundation

/// A complete fake ledger for demo mode: every list the app shows, with the
/// relations resolved (names on transactions and recurring movements) and the
/// balances the database views would compute.
public struct DemoDataSet: Sendable {
  public var accounts: [Account]
  public var cards: [Card]
  public var categories: [Category]
  public var tags: [Tag]
  public var assets: [Asset]
  public var loans: [Loan]
  public var capitalPayments: [LoanCapitalPayment]
  public var recurringMovements: [RecurringMovement]
  public var credits: [WalletCredit]
  public var transactions: [Transaction]

  public init(
    accounts: [Account], cards: [Card], categories: [Category], tags: [Tag], assets: [Asset], loans: [Loan],
    capitalPayments: [LoanCapitalPayment], recurringMovements: [RecurringMovement], credits: [WalletCredit],
    transactions: [Transaction]
  ) {
    self.accounts = accounts
    self.cards = cards
    self.categories = categories
    self.tags = tags
    self.assets = assets
    self.loans = loans
    self.capitalPayments = capitalPayments
    self.recurringMovements = recurringMovements
    self.credits = credits
    self.transactions = transactions
  }
}

/// The `balance` column of `wallet_accounts_with_balance` and
/// `wallet_cards_with_balance`, computed locally from live transactions.
public enum DemoBalances {
  private static func cents(_ v: Double) -> Double { Double(v.fixed2) ?? v }

  /// Sum of `value` (full amounts, not weighted) of the rows on each account.
  public static func accounts(_ accounts: [Account], _ transactions: [Transaction]) -> [Account] {
    var sums: [String: Double] = [:]
    for t in transactions {
      if let id = t.accountId, !id.isEmpty { sums[id, default: 0] += t.value }
    }
    return accounts.map {
      var a = $0
      a.balance = cents(sums[a.id] ?? 0)
      return a
    }
  }

  /// Sum of `value` of each card's rows without a `creditId` (deferred
  /// installments are tracked separately).
  public static func cards(_ cards: [Card], _ transactions: [Transaction]) -> [Card] {
    var sums: [String: Double] = [:]
    for t in transactions where t.creditKey == nil {
      if let id = t.cardId, !id.isEmpty { sums[id, default: 0] += t.value }
    }
    return cards.map {
      var c = $0
      c.balance = cents(sums[c.id] ?? 0)
      return c
    }
  }
}

/// SplitMix64: a tiny seedable generator so a seed reproduces the same demo.
struct DemoRandom: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  mutating func int(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &self) }

  /// An amount with two decimals.
  mutating func money(_ range: ClosedRange<Double>) -> Double {
    Double(Double.random(in: range, using: &self).fixed2) ?? range.lowerBound
  }

  mutating func chance(_ probability: Double) -> Bool { Double.random(in: 0..<1, using: &self) < probability }

  /// A random lower-case uuid, as stored in `id` columns.
  mutating func uuid() -> String {
    let a = next(), b = next()
    var bytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    withUnsafeMutableBytes(of: &bytes) { raw in
      raw.storeBytes(of: a, toByteOffset: 0, as: UInt64.self)
      raw.storeBytes(of: b, toByteOffset: 8, as: UInt64.self)
    }
    bytes.6 = (bytes.6 & 0x0F) | 0x40
    bytes.8 = (bytes.8 & 0x3F) | 0x80
    return UUID(uuid: bytes).uuidString.lowercased()
  }

  mutating func pick<T>(_ items: [T]) -> T { items[Int.random(in: 0..<items.count, using: &self)] }
}
