import SwiftUI
import WalletCore

/// Deferred installments due this month, and the credits that end with them.
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
        LabeledContent(L("creditsDueThisMonthLabel")) {
          Text(Money.text(abs(CreditLedger.dueIn(month: month, flat)))).monospacedDigit().foregroundStyle(.red)
        }
        LabeledContent(L("creditsEndsThisMonthLabel")) {
          Text(Money.text(abs(CreditLedger.endingInMonthTotal(month, flat)))).monospacedDigit()
            .foregroundStyle(Money.incomeOnDark)
        }
      }
      if groups.isEmpty {
        Text(L("creditsEmptyForSelectedMonth")).font(.footnote).foregroundStyle(.secondary)
      }
      ForEach(groups) { g in
        let total = CreditLedger.installmentCount(group: g.id, flat)
        let left = CreditLedger.countAfter(month: month, group: g.id, flat)
        let title = CreditDescription.strip(g.rows.first?.description).trimmingCharacters(in: .whitespaces)
        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(title.isEmpty ? L("creditsUntitledGroup") : title).lineLimit(1)
            Spacer(minLength: 4)
            Text("\(total - left)/\(total)").font(.caption).monospacedDigit()
              .foregroundStyle(left == 0 ? Money.incomeOnDark : .secondary)
          }
          Text(Money.text(abs(g.rows.reduce(0) { $0 + $1.value }))).font(.caption2).monospacedDigit()
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(L("creditsTitle"))
  }
}
