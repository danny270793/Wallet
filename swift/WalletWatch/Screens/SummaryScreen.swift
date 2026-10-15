import SwiftUI
import WalletCore

/// Month totals: income, outcome and balance (weighted, like the iPhone footer).
struct SummaryScreen: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    let t = model.totals
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        WatchMonthSwitcher()
        if let failure = model.failure, model.transactions.isEmpty {
          Label(
            L(failure == .networkUnavailable ? "loadFailedNoConnectionTitle" : "loadFailedRequestFailedTitle"),
            systemImage: "wifi.slash"
          )
          .font(.footnote).foregroundStyle(.orange)
        } else if model.fromCache {
          Label(L("cachedDataOfflineBanner"), systemImage: "icloud.slash").font(.caption2).foregroundStyle(.orange)
        }
        row(L("transactionsTotalIncome"), t.income, Money.incomeOnDark)
        row(L("transactionsTotalOutcome"), t.outcome, .red)
        Divider()
        VStack(alignment: .leading, spacing: 0) {
          Text(L("transactionsTotalBalance")).font(.caption).foregroundStyle(.secondary)
          Text(Money.text(t.balance))
            .font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
            .foregroundStyle(Money.color(t.balance))
            .minimumScaleFactor(0.6).lineLimit(1)
            .contentTransition(.numericText(value: t.balance))
        }
      }
      .padding(.horizontal, 4)
      .redacted(reason: model.loading && model.transactions.isEmpty ? .placeholder : [])
    }
    .navigationTitle(L("transactionsTotalBalance"))
  }

  private func row(_ label: String, _ value: Double, _ color: Color) -> some View {
    HStack {
      Text(label).font(.footnote).foregroundStyle(.secondary)
      Spacer()
      Text(Money.text(value)).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(color)
        .minimumScaleFactor(0.6).lineLimit(1)
    }
  }
}
