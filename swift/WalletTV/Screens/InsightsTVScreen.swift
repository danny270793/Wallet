import Charts
import SwiftUI
import WalletCore

/// The month's expenses by tag and by category side by side: large donuts
/// with their top slices listed, sized for the TV.
struct InsightsTVScreen: View {
  @Environment(TVModel.self) private var model

  var body: some View {
    let txs = model.transactions
    let o = DashboardOptions()
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        TVMonthSwitcher()
        HStack(alignment: .top, spacing: 40) {
          TVCard {
            TVDonut(title: L("monthlyDashboardTagPieTitle"), slices: ExpensePie.slices(txs, .tag, options: o, filter: nil))
          }
          TVCard {
            TVDonut(
              title: L("monthlyDashboardCategoryPieTitle"), slices: ExpensePie.slices(txs, .category, options: o, filter: nil))
          }
        }
      }
      .padding(.horizontal, 60)
    }
  }
}

struct TVDonut: View {
  let title: String
  let slices: [PieSlice]

  private static let colors: [Color] = [.blue, .purple, .orange, .teal, .pink, .green, .indigo, .brown, .mint, .red, .cyan, .yellow]

  var body: some View {
    let total = slices.reduce(0) { $0 + $1.expense }
    VStack(alignment: .leading, spacing: 24) {
      Text(title).font(.headline)
      if slices.isEmpty {
        Text(L("dashboardCategoryPieNoData")).foregroundStyle(.secondary)
      } else {
        HStack(alignment: .center, spacing: 40) {
          Chart(Array(slices.enumerated()), id: \.element.key) { i, s in
            SectorMark(angle: .value(L("transactionAmount"), s.expense), innerRadius: .ratio(0.62), angularInset: 1.5)
              .cornerRadius(6)
              .foregroundStyle(Self.colors[i % Self.colors.count])
          }
          .chartBackground { _ in
            VStack {
              Text(Money.text(total)).font(.title3.bold()).monospacedDigit()
              Text(L("transactionsTotalOutcome")).font(.caption).foregroundStyle(.secondary)
            }
          }
          .frame(width: 320, height: 320)
          VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(slices.prefix(7).enumerated()), id: \.element.key) { i, s in
              HStack {
                Circle().fill(Self.colors[i % Self.colors.count]).frame(width: 16, height: 16)
                Text(s.label).lineLimit(1)
                Spacer()
                Text(Money.text(s.expense)).monospacedDigit()
              }
              .font(.callout)
            }
          }
        }
      }
    }
  }
}
