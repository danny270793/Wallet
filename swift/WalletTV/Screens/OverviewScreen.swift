import Charts
import SwiftUI
import WalletCore

/// Month and year at a glance: four large cards and a chart of the year's
/// monthly balance, readable from across the room.
struct OverviewScreen: View {
  @Environment(TVModel.self) private var model

  var body: some View {
    let m = model.monthTotals
    let ytd = model.yearToDate
    let y = TotalsMode.weighted.totals(ytd)
    let monthly = YearlyMath.byMonth(ytd, year: model.year, kind: .net, options: DashboardOptions())
    let spent = m.income > 0 ? m.outcome / m.income : (m.outcome > 0 ? 1 : 0)
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        HStack {
          TVMonthSwitcher()
          Spacer()
          if model.fromCache { Label(L("cachedDataOfflineBanner"), systemImage: "icloud.slash").foregroundStyle(.orange) }
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 2), spacing: 40) {
          TVCard {
            VStack(alignment: .leading, spacing: 24) {
              TVStat(label: L("monthlyDashboard"), value: m.balance, large: true)
              // tvOS has no Gauge; a linear progress view shows the same ratio.
              ProgressView(value: min(spent, 1)) {
                HStack {
                  Text(L("tvSpentOfIncome"))
                  Spacer()
                  Text(spent.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit()
                }
                .font(.callout).foregroundStyle(.secondary)
              }
              .tint(spent > 1 ? .red : Money.income)
              HStack(spacing: 60) {
                TVStat(label: L("transactionsTotalIncome"), value: m.income, color: Money.income)
                TVStat(label: L("transactionsTotalOutcome"), value: m.outcome, color: .red)
              }
            }
          }
          TVCard {
            VStack(alignment: .leading, spacing: 24) {
              TVStat(label: "\(L("watchYearToDate")) · \(model.year)", value: y.balance, large: true)
              HStack(spacing: 60) {
                TVStat(label: L("transactionsTotalIncome"), value: y.income, color: Money.income)
                TVStat(label: L("transactionsTotalOutcome"), value: y.outcome, color: .red)
              }
            }
          }
          TVCard {
            VStack(alignment: .leading, spacing: 18) {
              TVStat(label: L("accounts"), value: model.accountsTotal, large: true)
              ForEach(model.accounts.prefix(4)) { a in
                HStack {
                  Text(a.name)
                  Spacer()
                  Text(Money.text(a.balance)).monospacedDigit().foregroundStyle(Money.color(a.balance))
                }
                .font(.callout)
              }
            }
          }
          TVCard {
            VStack(alignment: .leading, spacing: 18) {
              TVStat(label: L("cards"), value: model.cardsTotal, large: true)
              ForEach(model.cards.prefix(4)) { c in
                HStack {
                  Circle().fill((c.type ?? .other).tint).frame(width: 14, height: 14)
                  Text(c.name)
                  Spacer()
                  let v = CreditLedger.postedBalance(c.balance, model.cardCredits[c.id])
                  Text(Money.text(v)).monospacedDigit().foregroundStyle(Money.color(v))
                }
                .font(.callout)
              }
            }
          }
        }
        TVCard {
          VStack(alignment: .leading, spacing: 20) {
            Text(L("yearlyDashboardNetByMonthTitle")).font(.headline)
            YearNetChart(values: monthly, highlight: WalletCalendar.month(model.month) - 1)
              .frame(height: 320)
          }
        }
      }
      .padding(.horizontal, 60)
      .redacted(reason: model.loading && model.transactions.isEmpty ? .placeholder : [])
    }
  }
}

/// Monthly balance bars for the year with values on top; the selected month is bright.
struct YearNetChart: View {
  let values: [Double]
  let highlight: Int

  var body: some View {
    let symbols = Calendar(identifier: .gregorian).shortStandaloneMonthSymbols
    Chart(Array(values.enumerated()), id: \.offset) { i, v in
      BarMark(x: .value(L("month"), symbols[i]), y: .value(L("transactionAmount"), v))
        .foregroundStyle(v >= 0 ? Money.income : .red)
        .opacity(i == highlight ? 1 : 0.55)
        .cornerRadius(6)
        .annotation(position: v < 0 ? .bottom : .top) {
          if abs(v) >= 0.005 {
            Text(v.formatted(.number.notation(.compactName).precision(.significantDigits(1...3))))
              .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
          }
        }
    }
    .chartYAxis {
      AxisMarks(position: .leading) { v in
        AxisGridLine()
        AxisValueLabel { if let d = v.as(Double.self) { Text(d.formatted(.number.notation(.compactName))) } }
      }
    }
  }
}
