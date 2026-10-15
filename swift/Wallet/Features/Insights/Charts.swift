import Charts
import SwiftUI
import WalletCore

/// Distinct, accessible colors for pie slices.
enum SlicePalette {
  static let colors: [Color] = [.blue, .purple, .orange, .teal, .pink, .green, .indigo, .brown, .mint, .red, .cyan, .yellow]
  static func color(_ i: Int) -> Color { colors[i % colors.count] }
}

/// Donut of expenses by tag or category. Tapping a legend row (or a slice)
/// filters to it; tapping the lone filtered row again shows all. The filter
/// button lets you pick several.
struct ExpenseDonut: View {
  let title: String
  let dimension: PieDimension
  let transactions: [Transaction]
  let options: DashboardOptions
  @Binding var filter: Set<String>?
  /// Other pie's filter, cleared when this one is reset to all.
  var onShowAll: (() -> Void)?

  @State private var selectedAngle: Double?
  @State private var choosing = false

  var body: some View {
    let slices = ExpensePie.slices(transactions, dimension, options: options, filter: filter)
    let total = slices.reduce(0) { $0 + $1.expense }
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title).font(.headline)
        Spacer()
        Button(L(dimension == .tag ? "dashboardTagPieFilterTags" : "dashboardCategoryPieFilterCategories"),
               systemImage: filter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill") {
          choosing = true
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
      }
      if slices.isEmpty {
        Text(L(dimension == .tag ? "dashboardTagPieNoData" : "dashboardCategoryPieNoData"))
          .font(.footnote).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 80)
      } else {
        Chart(Array(slices.enumerated()), id: \.element.key) { i, s in
          SectorMark(angle: .value(L("transactionAmount"), s.expense), innerRadius: .ratio(0.62), angularInset: 1.5)
            .cornerRadius(4)
            .foregroundStyle(SlicePalette.color(i))
            .opacity(filter == nil || filter?.contains(s.key) == true ? 1 : 0.35)
        }
        .chartAngleSelection(value: $selectedAngle)
        .chartBackground { _ in
          VStack(spacing: 0) {
            Text(Money.text(total)).font(.title3.bold()).monospacedDigit()
            Text(L("transactionsTotalOutcome")).font(.caption).foregroundStyle(.secondary)
          }
        }
        .frame(height: 200)
        .onChange(of: selectedAngle) { _, angle in
          guard let angle else { return }
          var acc = 0.0
          if let hit = slices.first(where: { acc += $0.expense; return angle <= acc }) { toggle(hit.key) }
        }
        VStack(spacing: 2) {
          ForEach(Array(slices.enumerated()), id: \.element.key) { i, s in
            let only = filter?.count == 1 && filter?.contains(s.key) == true
            Button { toggle(s.key) } label: {
              HStack {
                Circle().fill(SlicePalette.color(i)).frame(width: 10, height: 10)
                Text(s.label).fontWeight(only ? .semibold : .regular).lineLimit(1)
                Spacer()
                Text(Money.text(s.expense)).monospacedDigit().fontWeight(.semibold)
              }
              .padding(.vertical, 6).padding(.horizontal, 10)
              .background(only ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
            }
            // Borderless: the card is one List row, and plain buttons in a row
            // all fire together (the last one wins), so every tap hit "Bank".
            .buttonStyle(.borderless)
            .tint(.primary)
          }
        }
        .font(.subheadline)
      }
    }
    .sheet(isPresented: $choosing) {
      PieFilterSheet(
        dimension: dimension, options: ExpensePie.options(transactions, dimension, options: options),
        current: filter
      ) { new in
        filter = new
        if new == nil { onShowAll?() }
      }
    }
  }

  private func toggle(_ key: String) {
    let only = filter?.count == 1 && filter?.contains(key) == true
    withAnimation(.smooth) {
      filter = only ? nil : [key]
      if only { onShowAll?() }
    }
  }
}

/// Multi-select of which tags/categories the pie includes.
struct PieFilterSheet: View {
  let dimension: PieDimension
  let options: [(key: String, label: String)]
  let current: Set<String>?
  let apply: (Set<String>?) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var draft: Set<String> = []

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(options, id: \.key) { o in
            Button {
              if draft.contains(o.key) { draft.remove(o.key) } else { draft.insert(o.key) }
            } label: {
              HStack {
                Text(o.label).foregroundStyle(.primary)
                Spacer()
                if draft.contains(o.key) { Image(systemName: "checkmark").foregroundStyle(.tint) }
              }
            }
          }
        } footer: {
          Text(L(dimension == .tag ? "dashboardTagPieFilterDescription" : "dashboardCategoryPieFilterDescription"))
        }
      }
      .navigationTitle(L(dimension == .tag ? "dashboardTagPieFilterTags" : "dashboardCategoryPieFilterCategories"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
        ToolbarItem(placement: .topBarLeading) {
          Button(draft.count == options.count ? L("dashboardPieDeselectAll") : L("dashboardPieSelectAll")) {
            draft = draft.count == options.count ? [] : Set(options.map(\.key))
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(role: .confirm) {
            apply(draft.count == options.count ? nil : draft)
            dismiss()
          }
          .disabled(draft.isEmpty)
        }
      }
      .onAppear { draft = current ?? Set(options.map(\.key)) }
    }
    .presentationDetents([.medium, .large])
  }
}

/// Twelve monthly bars, each labeled with its compact value (e.g. 5,84K);
/// estimated months are faded.
struct MonthlyBarChart: View {
  let title: String
  let series: YearSeries
  let color: Color
  var signed = false
  var footnote: String?

  private var symbols: [String] {
    var c = Calendar(identifier: .gregorian)
    c.locale = L10n.locale
    return c.veryShortStandaloneMonthSymbols
  }

  /// 5843.2 → "5,84K", 52 → "52", in the app's locale.
  static func compact(_ v: Double) -> String {
    v.formatted(.number.notation(.compactName).precision(.significantDigits(1...3)).locale(L10n.locale))
  }

  /// Zero to the extremes, plus room past the longest bars for their labels.
  private var yDomain: ClosedRange<Double> {
    let hi = max(0, series.monthly.max() ?? 0)
    let lo = min(0, series.monthly.min() ?? 0)
    let span = max(hi - lo, 1)
    return (lo < 0 ? lo - span * 0.35 : 0)...(hi > 0 ? hi + span * 0.35 : 0)
  }

  /// Rotated text's on-screen height, so the annotation reserves the right space.
  static func labelLength(_ v: Double) -> CGFloat { CGFloat(compact(v).count) * 6 + 4 }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.headline)
      Chart(Array(series.monthly.enumerated()), id: \.offset) { i, v in
        let estimated = i >= series.projectedFromIndex
        BarMark(x: .value(L("month"), symbols[i] + "\u{200B}\(i)"), y: .value(L("transactionAmount"), v))
          .cornerRadius(5)
          .foregroundStyle(signed ? (v >= 0 ? Money.income : Color.red) : color)
          .opacity(estimated ? 0.35 : 1)
          .accessibilityLabel(symbols[i])
          .accessibilityValue("\(Money.text(v))\(estimated ? " · \(L("estimated"))" : "")")
          .annotation(position: v < 0 ? .bottom : .top, spacing: 4) {
            if abs(v) >= 0.005 {
              Text(Self.compact(v))
                .font(.system(size: 9, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 14, height: Self.labelLength(v))
                .accessibilityHidden(true)
            }
          }
      }
      .chartXAxis {
        AxisMarks { value in
          AxisValueLabel { if let s = value.as(String.self) { Text(String(s.prefix { $0 != "\u{200B}" })) } }
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          AxisGridLine()
          AxisValueLabel { if let d = value.as(Double.self) { Text(d.formatted(.number.notation(.compactName))) } }
        }
      }
      .chartYScale(domain: yDomain)
      .frame(height: 220)
      if let footnote { Text(footnote).font(.caption).foregroundStyle(.secondary) }
    }
  }
}

/// Rounded content card. Content stays off glass (glass is for controls).
struct InsightCard<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    content
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background.secondary, in: .rect(cornerRadius: 22))
  }
}
