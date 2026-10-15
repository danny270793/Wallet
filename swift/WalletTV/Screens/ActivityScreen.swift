import SwiftUI
import WalletCore

/// The month's transactions grouped by day. Each row is focusable; selecting
/// one opens its details. Adding and editing stay on iPhone and Watch.
struct ActivityScreen: View {
  @Environment(TVModel.self) private var model

  var body: some View {
    let days = Ledger.groupedByDay(model.transactions)
    List {
      Section {
        TVMonthSwitcher()
      } footer: {
        Text(L("tvBrowseOnly"))
      }
      if days.isEmpty && !model.loading {
        Text(L("noTransactionsInMonth", model.month.formatted(.dateTime.month(.wide).year().locale(L10n.locale))))
          .foregroundStyle(.secondary)
      }
      ForEach(days) { day in
        Section(day.day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().locale(L10n.locale))) {
          ForEach(day.rows) { row in
            switch row {
            case .transaction(let t):
              NavigationLink { TVTransactionDetail(transaction: t) } label: { TVTransactionRow(transaction: t) }
            case .transfer(let s, let t):
              HStack(spacing: 24) {
                Image(systemName: t.cardId != nil ? "creditcard" : "arrow.left.arrow.right").foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                  Text(t.paymentMethodName ?? "—")
                  Text(s.paymentMethodName ?? "—").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Money.text(t.value)).monospacedDigit().foregroundStyle(.secondary)
              }
            }
          }
        }
      }
    }
    .navigationTitle(L("transactions"))
  }
}

struct TVTransactionRow: View {
  let transaction: Transaction

  var body: some View {
    let t = transaction
    HStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 4) {
        Text(t.description?.isEmpty == false ? t.description! : (t.categoryName ?? "—")).lineLimit(1)
        Text(t.relationNames.joined(separator: " · ")).font(.callout).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(Money.text(t.weightedValue)).font(.headline).monospacedDigit().foregroundStyle(Money.color(t.weightedValue))
        Text(t.transactedAt.formatted(.dateTime.hour().minute())).font(.caption).foregroundStyle(.secondary)
      }
    }
    .opacity(t.ignore ? 0.55 : 1)
  }
}

struct TVTransactionDetail: View {
  let transaction: Transaction

  var body: some View {
    let t = transaction
    HStack(alignment: .top, spacing: 80) {
      VStack(alignment: .leading, spacing: 16) {
        Text(t.description ?? "").font(.title2)
        Text(Money.text(t.weightedValue))
          .font(.system(size: 96, weight: .bold, design: .rounded)).monospacedDigit()
          .foregroundStyle(Money.color(t.weightedValue))
        if abs(t.percentage - 100) > 0.01 {
          Text("\(t.percentage.fixed2)% · \(Money.text(t.value))").foregroundStyle(.secondary)
        }
      }
      Form {
        LabeledContent(L("transactionDateTime"), value: t.transactedAt.formatted(date: .long, time: .shortened))
        if let p = t.paymentMethodName { LabeledContent(L("transactionPaymentMethod"), value: p) }
        if let c = t.categoryName { LabeledContent(L("transactionCategory"), value: c) }
        if let g = t.tagName { LabeledContent(L("transactionTag"), value: g) }
        if t.ignore { LabeledContent(L("transactionIgnore"), value: L("transactionIgnoredBadge")) }
      }
    }
    .padding(60)
  }
}
