import Foundation
import WalletCore

/// Multi-row ledger operations, ported from the Flutter `TransactionsCubit`
/// and the balance-adjustment / transfer use cases.
extension WalletRepository {
  public static let adjustmentLabel = "Adjustment"
  public static let transferDescription = "Transfer"

  /// Saves a new transaction. With [deferred] on a card and 2+ months, creates
  /// a `wallet_credits` header and one installment per month (saved as ignored).
  public func createTransaction(
    _ d: TransactionDraft, deferred: Bool = false, graceMonths: Int = 0, termMonths: Int = 1
  ) async throws {
    let grace = min(max(graceMonths, 0), 1200)
    guard deferred, let cardId = d.cardId, termMonths >= 2 else {
      try await createTransaction(d)
      return
    }
    let parts = splitEqualAmountParts(d.value, termMonths)
    guard let card = try await cards().value.first(where: { $0.id == cardId }) else {
      throw WalletError.invalidArgument("Deferred credit requires the selected card (cut/pay days).")
    }
    let schedule = try DeferredCreditSchedule.installments(
      purchase: d.transactedAt, graceMonths: grace, termMonths: termMonths, cardCutDay: card.cutDay)
    let header = try await insertCredit(
      transactedAt: d.transactedAt, graceMonths: grace, termMonths: termMonths, description: d.description)
    for i in 0..<termMonths {
      var row = d
      row.description = CreditDescription.prefixed(current: i + 1, total: termMonths, note: d.description)
      row.transactedAt = schedule[i]
      row.value = parts[i]
      row.ignore = true
      row.creditId = header.id
      try await createTransaction(row)
    }
  }

  /// Updates a transaction. For an installment of a deferred purchase every
  /// installment is rewritten: amounts are re-split, and either the plan is
  /// rescheduled (grace/term changed) or all dates shift by the same delta.
  public func updateTransaction(
    id: String, _ d: TransactionDraft, creditGraceMonths: Int? = nil, creditTermMonths: Int? = nil
  ) async throws {
    guard let creditKey = d.creditId, !creditKey.isEmpty else {
      try await updateTransaction(id: id, d)
      return
    }
    var siblings = try await installments(credit: creditKey)
    if siblings.isEmpty {
      try await updateTransaction(id: id, d)
      return
    }
    siblings.sort { $0.transactedAt < $1.transactedAt }
    let wc = try await credit(id: creditKey)

    if let wc, let cardId = d.cardId, !cardId.isEmpty, let ng = creditGraceMonths, let nt = creditTermMonths, nt >= 2,
      ng != wc.graceMonths || nt != wc.termMonths || nt != siblings.count
    {
      let grace = min(max(ng, 0), 1200)
      guard let card = try await cards().value.first(where: { $0.id == cardId }) else {
        throw WalletError.invalidArgument("Credit reschedule requires the card (cut/pay days).")
      }
      let schedule = try DeferredCreditSchedule.installments(
        purchase: d.transactedAt, graceMonths: grace, termMonths: nt, cardCutDay: card.cutDay)
      let parts = splitEqualAmountParts(d.value, nt)
      for i in 0..<nt {
        var row = d
        row.description = CreditDescription.prefixed(current: i + 1, total: nt, note: d.description)
        row.transactedAt = schedule[i]
        row.value = parts[i]
        row.creditId = creditKey
        if i < siblings.count {
          row.transferGroupId = siblings[i].transferGroupId
          try await updateTransaction(id: siblings[i].id, row)
        } else {
          row.transferGroupId = nil
          try await createTransaction(row)
        }
      }
      for s in siblings.dropFirst(nt) { try await deleteTransaction(id: s.id) }
      try await updateCredit(id: creditKey, graceMonths: grace, termMonths: nt, transactedAt: d.transactedAt)
      AppLog.info("credit group rescheduled (\(creditKey)): \(nt) rows")
      return
    }

    let baseline = wc?.transactedAt ?? (siblings.first { $0.id == id } ?? siblings[0]).transactedAt
    let delta = d.transactedAt.timeIntervalSince(baseline)
    let parts = splitEqualAmountParts(d.value, siblings.count)
    for (i, s) in siblings.enumerated() {
      var row = d
      row.description = CreditDescription.prefixed(current: i + 1, total: siblings.count, note: d.description)
      row.transactedAt = s.transactedAt.addingTimeInterval(delta)
      row.value = parts[i]
      row.transferGroupId = s.transferGroupId
      row.creditId = s.creditId
      try await updateTransaction(id: s.id, row)
    }
    if let wc {
      try await updateCredit(
        id: creditKey, graceMonths: wc.graceMonths, termMonths: wc.termMonths, transactedAt: d.transactedAt)
    }
  }

  /// Deletes a row; with [creditKey], every installment of that purchase.
  public func deleteTransaction(id: String, creditKey: String?) async throws {
    var ids: [String] = [id]
    if let creditKey, !creditKey.isEmpty {
      for t in try await installments(credit: creditKey) where !ids.contains(t.id) { ids.append(t.id) }
    }
    for i in ids { try await deleteTransaction(id: i) }
  }

  public func deleteTransactions(_ ids: [String]) async throws {
    for id in Array(Set(ids)) { try await deleteTransaction(id: id) }
  }

  /// One end of a transfer: exactly one of account or card.
  public enum Leg: Hashable, Sendable {
    case account(String)
    case card(String)

    public var accountId: String? { if case .account(let id) = self { id } else { nil } }
    public var cardId: String? { if case .card(let id) = self { id } else { nil } }

    public init?(_ t: Transaction) {
      if let a = t.accountId { self = .account(a) } else if let c = t.cardId { self = .card(c) } else { return nil }
    }
  }

  /// Outflow on [source], inflow on [target]; both rows share a new transfer group id.
  public func transfer(from source: Leg, to target: Leg, amount: Double, at date: Date) async throws {
    guard source != target else { throw WalletError.invalidArgument("source and target payment method must differ") }
    guard amount > 0 else { throw WalletError.invalidArgument("amount must be positive") }
    let group = UUID().uuidString.lowercased()
    try await createTransaction(
      TransactionDraft(
        accountId: source.accountId, cardId: source.cardId, description: Self.transferDescription, transactedAt: date,
        value: -amount, transferGroupId: group))
    try await createTransaction(
      TransactionDraft(
        accountId: target.accountId, cardId: target.cardId, description: Self.transferDescription, transactedAt: date,
        value: amount, transferGroupId: group))
  }

  /// Rewrites both legs of an existing transfer.
  public func updateTransfer(
    source: Transaction, target: Transaction, from s: Leg, to t: Leg, amount: Double, at date: Date, ignore: Bool
  ) async throws {
    guard let gid = source.transferGroupId, !gid.isEmpty, gid == target.transferGroupId else {
      throw WalletError.invalidArgument("updateTransfer: invalid or mismatched group id")
    }
    for (row, leg, value) in [(source, s, -amount), (target, t, amount)] {
      try await updateTransaction(
        id: row.id,
        TransactionDraft(
          accountId: leg.accountId, cardId: leg.cardId, categoryId: row.categoryId, tagId: row.tagId,
          description: row.description, transactedAt: date, value: value, ignore: ignore, percentage: row.percentage,
          transferGroupId: gid, creditId: row.creditId))
    }
  }

  /// Creates an "Adjustment" movement (category and tag created on demand) so
  /// the account or card balance moves by [delta].
  public func adjustBalance(_ leg: Leg, delta: Double) async throws {
    guard abs(delta) >= 1e-9 else { return }
    let label = Self.adjustmentLabel
    let categoryId: String
    if let c = try await categories().value.first(where: { $0.name == label }) {
      categoryId = c.id
    } else {
      categoryId = try await createCategory(name: label).id
    }
    let tagId: String
    if let t = try await tags().value.first(where: { $0.name == label }) {
      tagId = t.id
    } else {
      tagId = try await createTag(name: label).id
    }
    try await createTransaction(
      TransactionDraft(
        accountId: leg.accountId, cardId: leg.cardId, categoryId: categoryId, tagId: tagId, description: label,
        transactedAt: .now, value: delta))
  }

  /// Loads loans, capital payments, cards and installments for automatic rows.
  /// Each source is optional: a failure leaves its rows out.
  public func automaticSource() async -> AutomaticMovementsSource {
    async let loans = try? self.loans().value
    async let capital = try? self.capitalPayments().value
    async let cards = try? self.cards().value
    async let installments = try? self.creditInstallments().value
    return await AutomaticMovementsSource(
      loans: loans ?? [], capitalPayments: capital ?? [], cards: cards ?? [], creditInstallments: installments ?? [])
  }
}
