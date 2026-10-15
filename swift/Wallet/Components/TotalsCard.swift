import SwiftUI
import WalletCore

/// One labeled figure of a summary card.
struct Stat: Identifiable {
  let label: String
  let value: Double
  var color: Color?
  /// Owed amounts drop the sign; the label and color carry the meaning.
  var unsigned = false
  var id: String { label }
}

/// Floating glass summary pinned above the tab bar. With several pages,
/// swipe sideways to switch between them (the dots show where you are).
struct SummaryCard: View {
  struct Page: Identifiable {
    var caption: String?
    var stats: [Stat]
    var id: String { (caption ?? "") + stats.map(\.label).joined() }
  }

  let pages: [Page]
  @State private var index: Int? = 0

  var body: some View {
    VStack(spacing: 6) {
      if pages.count > 1 {
        ScrollView(.horizontal) {
          LazyHStack(spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
              PageView(page: p).containerRelativeFrame(.horizontal).id(i)
            }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $index)
        .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 6) {
          ForEach(pages.indices, id: \.self) { i in
            Circle()
              .fill(i == (index ?? 0) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.4)))
              .frame(width: 6, height: 6)
          }
        }
        .accessibilityHidden(true)
      } else if let p = pages.first {
        PageView(page: p)
      }
    }
    .padding(.vertical, 12)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
    .padding(.horizontal, 16)
    .padding(.bottom, 6)
    .accessibilityElement(children: .contain)
  }

  private struct PageView: View {
    let page: Page

    var body: some View {
      VStack(spacing: 6) {
        if let caption = page.caption {
          Text(caption).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        HStack(alignment: .top) {
          ForEach(page.stats) { s in
            VStack(spacing: 2) {
              Text(Money.text(s.unsigned ? abs(s.value) : s.value))
                .font(.headline).monospacedDigit()
                .foregroundStyle(s.color ?? Money.color(s.value))
                .contentTransition(.numericText(value: s.value))
                .lineLimit(1).minimumScaleFactor(0.6)
              Text(s.label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
          }
        }
        .padding(.horizontal, 12)
      }
      .animation(.smooth, value: page.stats.map(\.value))
    }
  }
}

extension SummaryCard {
  /// Income · Outcome · Balance.
  static func totals(_ t: Totals, caption: String? = nil) -> Page {
    Page(
      caption: caption,
      stats: [
        Stat(label: L("transactionsTotalIncome"), value: t.income, color: Money.income),
        Stat(label: L("transactionsTotalOutcome"), value: t.outcome, color: .red),
        Stat(label: L("transactionsTotalBalance"), value: t.balance),
      ])
  }

  /// The five totals modes of the transactions list.
  static func ledgerModes(_ txs: [Transaction]) -> [Page] {
    let captions = [
      "transactionsTotalsWeightedHint", "transactionsTotalsWeightedExcludingCreditHint",
      "transactionsTotalsWeightedExcludingIgnoredHint", "transactionsTotalsNotWeightedHint",
      "transactionsTotalsNotWeightedExcludingIgnoredHint",
    ]
    return TotalsMode.allCases.map { totals($0.totals(txs), caption: L(captions[$0.rawValue])) }
  }

  /// Single "Total" figure for list screens.
  static func total(_ v: Double) -> Page {
    Page(stats: [Stat(label: L("listBalanceTotalLabel"), value: v)])
  }
}
