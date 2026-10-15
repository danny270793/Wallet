import SwiftUI
import WalletCore

/// The month's latest transactions; tap one for its details (editing stays on the iPhone).
struct RecentScreen: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    List {
      WatchMonthSwitcher().listRowBackground(Color.clear)
      if model.recent.isEmpty {
        Text(L("noTransactionsInMonth", model.month.watchMonth)).font(.footnote).foregroundStyle(.secondary)
      }
      ForEach(model.recent) { row in
        switch row {
        case .transaction(let t):
          NavigationLink { TransactionDetail(transaction: t) } label: { TransactionCell(transaction: t) }
        case .transfer(let s, let t):
          HStack {
            Image(systemName: t.cardId != nil ? "creditcard" : "arrow.left.arrow.right").foregroundStyle(.secondary)
            VStack(alignment: .leading) {
              Text(t.paymentMethodName ?? "—").lineLimit(1)
              Text(s.paymentMethodName ?? "—").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(Money.text(t.value)).monospacedDigit().foregroundStyle(.secondary)
          }
        }
      }
    }
    .navigationTitle(L("watchRecent"))
  }
}

struct TransactionCell: View {
  let transaction: Transaction

  var body: some View {
    let t = transaction
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(t.description?.isEmpty == false ? t.description! : (t.categoryName ?? "—")).lineLimit(1)
        Spacer(minLength: 4)
        Text(Money.text(t.weightedValue)).font(.body.weight(.semibold)).monospacedDigit()
          .foregroundStyle(Money.color(t.weightedValue))
      }
      Text([t.categoryName, t.paymentMethodName].compactMap { $0 }.joined(separator: " · "))
        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    }
    .opacity(t.ignore ? 0.55 : 1)
  }
}

struct TransactionDetail: View {
  let transaction: Transaction

  var body: some View {
    let t = transaction
    List {
      Section {
        Text(Money.text(t.weightedValue))
          .font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
          .foregroundStyle(Money.color(t.weightedValue))
        if abs(t.percentage - 100) > 0.01 {
          LabeledContent(L("transactionPercentage"), value: "\(t.percentage.fixed2)%")
        }
      }
      Section {
        LabeledContent(L("transactionDateTime"), value: t.transactedAt.formatted(date: .abbreviated, time: .shortened))
        if let p = t.paymentMethodName { LabeledContent(L("transactionPaymentMethod"), value: p) }
        if let c = t.categoryName { LabeledContent(L("transactionCategory"), value: c) }
        if let g = t.tagName { LabeledContent(L("transactionTag"), value: g) }
        if t.ignore { Label(L("transactionIgnoredBadge"), systemImage: "eye.slash") }
      }
    }
    .navigationTitle(t.description ?? "")
  }
}
