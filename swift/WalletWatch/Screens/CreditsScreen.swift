import SwiftUI
import WalletCore

/// Deferred card purchases: what is due this month, what is still owed, and
/// each credit's progress (ending ones first, like the iPhone).
struct CreditsScreen: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    let flat = model.credits
    let month = model.month
    let groups = CreditLedger.sortedByPending(
      CreditLedger.grouped(CreditLedger.installments(inMonth: month, flat)), flat, month: month)
    List {
      WatchMonthSwitcher().listRowBackground(Color.clear)
      Section {
        BigAmount(label: L("creditsDueThisMonthLabel"), value: -abs(CreditLedger.dueIn(month: month, flat)))
          .listRowBackground(Color.clear)
        AmountRow(L("creditsPendingTotalsLabel"), abs(CreditLedger.pendingTotal(from: month, flat)), .red)
        AmountRow(L("creditsEndsThisMonthLabel"), abs(CreditLedger.endingInMonthTotal(month, flat)), Money.incomeOnDark)
      }
      if groups.isEmpty {
        Text(L("creditsEmptyForSelectedMonth")).font(.footnote).foregroundStyle(.secondary)
      }
      ForEach(groups) { g in
        let total = CreditLedger.installmentCount(group: g.id, flat)
        let left = CreditLedger.countAfter(month: month, group: g.id, flat)
        let paid = total - left
        let title = CreditDescription.strip(g.rows.first?.description).trimmingCharacters(in: .whitespaces)
        let accent: Color = left == 0 ? Money.incomeOnDark : left == 1 ? .orange : .secondary
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(title.isEmpty ? L("creditsUntitledGroup") : title).font(.footnote).lineLimit(1)
            Spacer(minLength: 4)
            Text(Money.text(abs(g.rows.reduce(0) { $0 + $1.value }))).font(.footnote.weight(.semibold)).monospacedDigit()
          }
          Gauge(value: Double(paid), in: 0...Double(max(total, 1))) { EmptyView() }
            .gaugeStyle(.linearCapacity)
            .tint(accent)
          Text("\(paid)/\(total)").font(.caption2).monospacedDigit().foregroundStyle(accent)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .navigationTitle(L("creditsTitle"))
  }
}
