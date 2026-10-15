import SwiftUI
import WalletCore

/// Credits due this month: totals across the top, then one card per
/// purchase with its progress, ending ones first.
struct CreditsTVScreen: View {
  @Environment(TVModel.self) private var model

  var body: some View {
    let flat = model.credits
    let month = model.month
    let groups = CreditLedger.sortedByPending(
      CreditLedger.grouped(CreditLedger.installments(inMonth: month, flat)), flat, month: month)
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        TVMonthSwitcher()
        HStack(spacing: 40) {
          TVCard { TVStat(label: L("creditsDueThisMonthLabel"), value: abs(CreditLedger.dueIn(month: month, flat)), color: .red, large: true) }
          TVCard { TVStat(label: L("creditsPendingTotalsLabel"), value: abs(CreditLedger.pendingTotal(from: month, flat)), color: .red) }
          TVCard { TVStat(label: L("creditsEndsThisMonthLabel"), value: abs(CreditLedger.endingInMonthTotal(month, flat)), color: Money.income) }
        }
        .fixedSize(horizontal: false, vertical: true)
        if groups.isEmpty {
          Text(L("creditsEmptyForSelectedMonth")).foregroundStyle(.secondary)
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 3), spacing: 40) {
          ForEach(groups) { g in
            let total = CreditLedger.installmentCount(group: g.id, flat)
            let left = CreditLedger.countAfter(month: month, group: g.id, flat)
            let paid = total - left
            let title = CreditDescription.strip(g.rows.first?.description).trimmingCharacters(in: .whitespaces)
            let accent: Color = left == 0 ? Money.income : left == 1 ? .orange : .secondary
            TVCard {
              VStack(alignment: .leading, spacing: 14) {
                Text(title.isEmpty ? L("creditsUntitledGroup") : title).font(.headline).lineLimit(2)
                Text(g.rows.first?.relationNames.joined(separator: " · ") ?? "").font(.caption).foregroundStyle(.secondary)
                  .lineLimit(1)
                Text(Money.text(abs(g.rows.reduce(0) { $0 + $1.value }))).font(.title3.weight(.semibold)).monospacedDigit()
                ProgressView(value: Double(paid), total: Double(max(total, 1))) {
                  Text("\(paid)/\(total)").font(.caption).monospacedDigit()
                }
                .tint(accent)
                Text(left > 0 ? L("creditsInstallmentsWithPending", total, left) : L("creditsInstallmentsEndsThisMonth", total))
                  .font(.caption).foregroundStyle(accent)
              }
            }
          }
        }
      }
      .padding(.horizontal, 60)
    }
  }
}
