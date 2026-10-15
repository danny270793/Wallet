import SwiftUI
import WalletCore

/// Month at a glance: the balance big, then income and outcome with a bar
/// showing how much of the income was spent.
struct SummaryScreen: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    let t = model.totals
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        WatchMonthSwitcher()
        WatchStatusLine()
        BigAmount(label: L("transactionsTotalBalance"), value: t.balance)
        SpendBar(income: t.income, outcome: t.outcome)
        AmountRow(L("transactionsTotalIncome"), t.income, Money.incomeOnDark)
        AmountRow(L("transactionsTotalOutcome"), t.outcome, .red)
      }
      .padding(.horizontal, 4)
      .redacted(reason: model.loading && model.transactions.isEmpty ? .placeholder : [])
    }
    .navigationTitle(L("month"))
  }
}

/// Year so far: balance big, income and outcome, and a mini chart of each
/// month's balance (current month highlighted).
struct YearScreen: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    let rows = model.yearToDate
    let t = TotalsMode.weighted.totals(rows)
    let monthly = YearlyMath.byMonth(rows, year: model.year, kind: .net, options: DashboardOptions())
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text(String(model.year)).font(.headline).foregroundStyle(.tint)
        BigAmount(label: L("watchYearToDate"), value: t.balance)
        MonthBars(values: monthly, highlight: WalletCalendar.month(model.month) - 1)
        AmountRow(L("transactionsTotalIncome"), t.income, Money.incomeOnDark)
        AmountRow(L("transactionsTotalOutcome"), t.outcome, .red)
        Divider()
        AmountRow(L("watchInAccounts"), model.accountsTotal, Money.color(model.accountsTotal))
      }
      .padding(.horizontal, 4)
      .redacted(reason: model.loading && rows.isEmpty ? .placeholder : [])
    }
    .navigationTitle(L("year"))
  }
}

// MARK: - Pieces

/// Offline / failed load notice, shown only when it applies.
struct WatchStatusLine: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    if let failure = model.failure, model.transactions.isEmpty {
      Label(
        L(failure == .networkUnavailable ? "loadFailedNoConnectionTitle" : "loadFailedRequestFailedTitle"),
        systemImage: "wifi.slash"
      )
      .font(.footnote).foregroundStyle(.orange)
    } else if model.fromCache {
      Label(L("cachedDataOfflineBanner"), systemImage: "icloud.slash").font(.caption2).foregroundStyle(.orange)
    }
  }
}

/// The page's key number, large and colored by sign.
struct BigAmount: View {
  let label: String
  let value: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      Text(Money.text(value))
        .font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
        .foregroundStyle(Money.color(value))
        .minimumScaleFactor(0.5).lineLimit(1)
        .contentTransition(.numericText(value: value))
    }
    .accessibilityElement(children: .combine)
  }
}

struct AmountRow: View {
  let label: String
  let value: Double
  let color: Color

  init(_ label: String, _ value: Double, _ color: Color) {
    self.label = label
    self.value = value
    self.color = color
  }

  var body: some View {
    HStack {
      Text(label).font(.footnote).foregroundStyle(.secondary)
      Spacer()
      Text(Money.text(value)).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(color)
        .minimumScaleFactor(0.6).lineLimit(1)
    }
    .accessibilityElement(children: .combine)
  }
}

/// How much of the income was spent: green while under, red past it.
struct SpendBar: View {
  let income: Double
  let outcome: Double

  var body: some View {
    let ratio = income > 0 ? outcome / income : (outcome > 0 ? 1 : 0)
    Gauge(value: min(ratio, 1)) {
      EmptyView()
    }
    .gaugeStyle(.linearCapacity)
    .tint(ratio > 1 ? .red : Money.incomeOnDark)
    .accessibilityLabel(L("transactionsTotalOutcome"))
    .accessibilityValue(ratio.formatted(.percent.precision(.fractionLength(0))))
  }
}

/// Twelve tiny bars of each month's balance; [highlight] is fully opaque.
struct MonthBars: View {
  let values: [Double]
  let highlight: Int

  var body: some View {
    let peak = max(values.map(abs).max() ?? 0, 1)
    HStack(alignment: .center, spacing: 2) {
      ForEach(values.indices, id: \.self) { i in
        let v = values[i]
        VStack(spacing: 0) {
          Rectangle().fill(v > 0 ? Money.incomeOnDark : .clear)
            .frame(height: max(CGFloat(v > 0 ? v / peak : 0) * 18, v > 0 ? 1 : 0))
            .frame(height: 18, alignment: .bottom)
          Rectangle().fill(v < 0 ? Color.red : .clear)
            .frame(height: max(CGFloat(v < 0 ? -v / peak : 0) * 18, v < 0 ? 1 : 0))
            .frame(height: 18, alignment: .top)
        }
        .clipShape(.rect(cornerRadius: 1.5))
        .opacity(i == highlight ? 1 : 0.5)
      }
    }
    .overlay { Rectangle().fill(.secondary.opacity(0.4)).frame(height: 0.5) }
    .accessibilityHidden(true)
  }
}
