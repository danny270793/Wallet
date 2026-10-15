import SwiftUI
import WalletCore

/// Which editor sheet to show. One enum so any screen can open any editor.
enum EditorRoute: Identifiable {
  case newTransaction(TransactionPreset)
  case editTransaction(Transaction)
  case transfer(payCard: Bool)
  case editTransfer(source: Transaction, target: Transaction)

  var id: String {
    switch self {
    case .newTransaction(let p): "new-\(p.hashValue)"
    case .editTransaction(let t): "edit-\(t.id)"
    case .transfer(let pay): "transfer-\(pay)"
    case .editTransfer(let s, _): "edit-transfer-\(s.id)"
    }
  }
}

/// Defaults for a new transaction (from a scoped list or a dashboard filter).
struct TransactionPreset: Hashable {
  var accountId: String?
  var cardId: String?
  var categoryId: String?
  var tagId: String?
  /// Open in deferred-purchase mode (the Credits tab).
  var deferred = false
  /// Only cards in the payment method picker.
  var cardsOnly = false

  init(scope: Ledger.Scope = .all, deferred: Bool = false, cardsOnly: Bool = false) {
    accountId = scope.accountId
    cardId = scope.cardId
    categoryId = scope.categoryId
    tagId = scope.tagId
    self.deferred = deferred
    self.cardsOnly = cardsOnly || deferred
  }
}

extension View {
  /// Presents the transaction / transfer editors for [route].
  func ledgerEditors(_ route: Binding<EditorRoute?>) -> some View {
    sheet(item: route) { r in
      switch r {
      case .newTransaction(let preset): TransactionEditor(transaction: nil, preset: preset)
      case .editTransaction(let t): TransactionEditor(transaction: t, preset: TransactionPreset(cardsOnly: t.isCreditInstallment))
      case .transfer(let pay): TransferEditor(payCard: pay)
      case .editTransfer(let s, let t): TransferEditor(source: s, target: t)
      }
    }
  }
}

/// A single transaction: description (with % when partial), relations, amount and time.
struct TransactionRowView: View {
  let transaction: Transaction
  var weighted = true

  var body: some View {
    let t = transaction
    let primary = t.amount(weighted: weighted)
    let partial = abs(t.percentage - 100) > 0.01
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 4) {
          if partial {
            Text("\(t.percentage.fixed2)%")
              .font(.caption.weight(.bold)).monospacedDigit()
              .padding(.horizontal, 6).padding(.vertical, 2)
              .background(.tint.opacity(0.15), in: .capsule)
              .foregroundStyle(.tint)
          }
          if let d = t.description, !d.isEmpty {
            Text(d).font(.body.weight(.medium)).lineLimit(2)
          }
          if t.isCreditInstallment {
            Image(systemName: "calendar.badge.clock").font(.caption).foregroundStyle(.secondary)
          }
        }
        if !t.relationNames.isEmpty {
          Text(t.relationNames.joined(separator: " · "))
            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 2) {
        AmountText(value: primary, font: .body.weight(.semibold), neutral: .secondary)
        if partial {
          Text(Money.text(weighted ? t.value : t.weightedValue))
            .font(.caption2).monospacedDigit().strikethrough().foregroundStyle(.secondary)
        }
        Text(Dates.time(t.transactedAt)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
      }
    }
    .opacity(t.ignore ? 0.5 : 1)
    .accessibilityElement(children: .combine)
    .accessibilityValue(t.ignore ? L("transactionIgnoredBadge") : "")
  }
}

/// Both legs of a transfer (or card payment) as one row: target, from source.
struct TransferRowView: View {
  let source: Transaction
  let target: Transaction

  var body: some View {
    let pay = target.cardId != nil
    HStack(spacing: 12) {
      IconTile(symbol: pay ? "creditcard.and.123" : "arrow.left.arrow.right", color: pay ? .purple : .gray)
      VStack(alignment: .leading, spacing: 2) {
        Text(target.paymentMethodName ?? "—").font(.body.weight(.medium)).lineLimit(1)
        Label(source.paymentMethodName ?? "—", systemImage: "arrow.turn.down.right")
          .font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(Money.text(target.value)).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
        Text(Dates.time(source.transactedAt)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
      }
    }
    .opacity(source.ignore || target.ignore ? 0.5 : 1)
    .accessibilityElement(children: .combine)
  }
}

/// Day-grouped ledger section content with swipe-to-edit and swipe-to-delete.
struct LedgerSections: View {
  @Environment(AppModel.self) private var model
  let days: [LedgerDay]
  var weighted = true
  /// When set, tapping a row calls this instead of opening the editor.
  var onSelect: ((Transaction) -> Void)?
  @Binding var editor: EditorRoute?
  @State private var pendingDelete: LedgerRow?

  var body: some View {
    ForEach(days) { day in
      Section {
        if day.rows.isEmpty {
          Text(L("noTransactionsThisDay"))
            .font(.footnote).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
        }
        ForEach(day.rows) { row in
          rowView(row)
        }
      } header: {
        Text(Dates.dayHeader(day.day))
      }
    }
  }

  @ViewBuilder private func rowView(_ row: LedgerRow) -> some View {
    Button {
      switch row {
      case .transaction(let t): if let onSelect { onSelect(t) } else { editor = .editTransaction(t) }
      case .transfer(let s, let t): if let onSelect { onSelect(t) } else { editor = .editTransfer(source: s, target: t) }
      }
    } label: {
      switch row {
      case .transaction(let t): TransactionRowView(transaction: t, weighted: weighted)
      case .transfer(let s, let t): TransferRowView(source: s, target: t)
      }
    }
    .tint(.primary)
    .swipeActions(edge: .trailing) {
      Button(L("delete"), systemImage: "trash", role: .destructive) { pendingDelete = row }
    }
    .swipeActions(edge: .leading) {
      Button(L("edit"), systemImage: "pencil") {
        switch row {
        case .transaction(let t): editor = .editTransaction(t)
        case .transfer(let s, let t): editor = .editTransfer(source: s, target: t)
        }
      }
      .tint(.blue)
    }
    // Per row, so the dialog is anchored to the row being deleted.
    .confirmationDialog(
      deleteTitle, isPresented: Binding(get: { pendingDelete?.id == row.id }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible
    ) {
      Button(L("delete"), role: .destructive) { Task { await delete(row) } }
    } message: {
      Text(deleteMessage)
    }
  }

  private var deleteTitle: String {
    if case .transfer = pendingDelete { return L("deleteTransferPair") }
    return L("deleteTransaction")
  }

  private var deleteMessage: String {
    switch pendingDelete {
    case .transfer: L("confirmDeleteTransferPair")
    case .transaction(let t) where t.isCreditInstallment: L("confirmDeleteCreditGroupTransaction")
    default: L("confirmDeleteTransaction")
    }
  }

  private func delete(_ row: LedgerRow) async {
    switch row {
    case .transaction(let t):
      await model.perform("failed to delete transaction") { try await $0.deleteTransaction(id: t.id, creditKey: t.creditKey) }
    case .transfer(let s, let t):
      await model.perform("failed to delete transfer") { try await $0.deleteTransactions([s.id, t.id]) }
    }
  }
}
