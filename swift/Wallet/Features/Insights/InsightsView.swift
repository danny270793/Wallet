import SwiftUI
import WalletCore
import WalletData

/// Monthly and yearly dashboards in one tab, switched with a segmented
/// control in the navigation bar. Both share the same view options
/// (ignored / weighted / credits) and the tag ⇄ category cross filters.
struct InsightsView: View {
  enum Period: String, CaseIterable { case month, year }

  @State private var period: Period = .month
  @State private var options = DashboardOptions()
  @State private var showingOptions = false

  var body: some View {
    NavigationStack {
      Group {
        switch period {
        case .month: MonthlyInsights(options: options)
        case .year: YearlyInsights(options: options)
        }
      }
      .navigationTitle(L(period == .month ? "monthlyDashboard" : "yearlyDashboard"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Picker(L("tabInsights"), selection: $period.animation(.smooth)) {
            Text(L("month")).tag(Period.month)
            Text(L("year")).tag(Period.year)
          }
          .pickerStyle(.segmented)
          .fixedSize()
        }
        ToolbarItem(placement: .primaryAction) {
          Button(L("monthlyDashboardConfigureTooltip"), systemImage: "slider.horizontal.3") { showingOptions = true }
        }
      }
      .sheet(isPresented: $showingOptions) { DashboardOptionsSheet(options: $options) }
    }
  }
}

struct DashboardOptionsSheet: View {
  @Binding var options: DashboardOptions
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Toggle(L("dashboardIncludeIgnoredInTotals"), isOn: $options.includeIgnored)
        Toggle(L("dashboardUseWeightedAmounts"), isOn: $options.useWeightedAmounts)
        Toggle(L("dashboardShowCredits"), isOn: $options.showCredits)
      }
      .navigationTitle(L("monthlyDashboardOptionsSheetTitle"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(role: .close) { dismiss() } } }
    }
    .presentationDetents([.height(280)])
  }
}

/// Tag and category donuts plus the filtered month list and totals.
struct MonthlyInsights: View {
  @Environment(AppModel.self) private var model
  let options: DashboardOptions
  @State private var month = WalletCalendar.startOfMonth(.now)
  @State private var state = Loadable<[Transaction]>()
  @State private var tagFilter: Set<String>?
  @State private var categoryFilter: Set<String>?
  @State private var editor: EditorRoute?

  var body: some View {
    let slice = DashboardSlice(state.value ?? [], options: options, tagFilter: tagFilter, categoryFilter: categoryFilter)
    List {
      LoadableContent(state: state, retry: load) { _ in
        Section {
          ExpenseDonut(
            title: L("monthlyDashboardTagPieTitle"), dimension: .tag, transactions: slice.tagPieTransactions,
            options: options, filter: $tagFilter, onShowAll: { categoryFilter = nil })
        }
        Section {
          ExpenseDonut(
            title: L("monthlyDashboardCategoryPieTitle"), dimension: .category,
            transactions: slice.categoryPieTransactions, options: options, filter: $categoryFilter)
        }
        if slice.listTransactions.isEmpty {
          Section(L("monthlyDashboardTransactionsListTitle")) {
            Text(L("noTransactionsInMonth", Dates.monthYear(month))).foregroundStyle(.secondary)
          }
        } else {
          LedgerSections(days: Ledger.groupedByDay(slice.listTransactions), weighted: options.useWeightedAmounts, editor: $editor)
        }
      }
    }
    .offlineBanner(state.fromCache)
    .toolbar {
      ToolbarItem(placement: .principal) { MonthSwitcher(month: $month) }
      ToolbarItem(placement: .primaryAction) {
        AddLedgerMenu(
          editor: $editor,
          preset: TransactionPreset(
            scope: Ledger.Scope(
              categoryId: slice.categoryFilter?.count == 1 ? slice.categoryFilter?.first : nil,
              tagId: slice.tagFilter?.count == 1 ? slice.tagFilter?.first : nil)))
      }
    }
    .safeAreaInset(edge: .bottom) {
      if state.value != nil {
        SummaryCard(pages: [
          SummaryCard.totals(Ledger.totals(slice.listTransactions, weighted: options.useWeightedAmounts))
        ])
      }
    }
    .onChange(of: slice.tagFilter) { _, v in if v != tagFilter { tagFilter = v } }
    .onChange(of: slice.categoryFilter) { _, v in if v != categoryFilter { categoryFilter = v } }
    .refreshable { await load() }
    .task(id: "\(month.timeIntervalSince1970)-\(model.dataVersion)") { await load() }
    .ledgerEditors($editor)
  }

  private func load() async {
    guard let repo = model.repo else { return }
    let m = month
    var next = Loadable<[Transaction]>()
    if WalletCalendar.isSameMonth(state.value?.first?.transactedAt ?? m, m) { next = state }
    next = await next.loaded { try await repo.transactions(month: m) }
    if m == month { state = next }
  }
}

/// Cumulative balance, net, income and outcome by month (with estimates for
/// months ahead), the year's donuts and its transactions.
struct YearlyInsights: View {
  @Environment(AppModel.self) private var model
  let options: DashboardOptions
  @State private var year = WalletCalendar.year(.now)
  @State private var state = Loadable<[Transaction]>()
  @State private var estimates = YearlyEstimates()
  @State private var tagFilter: Set<String>?
  @State private var categoryFilter: Set<String>?
  @State private var editor: EditorRoute?

  var body: some View {
    let all = state.value ?? []
    let base = options.showCredits ? all : all.filter { !$0.isCreditInstallment }
    let inYear = base.filter { WalletCalendar.year($0.transactedAt) == year }
    let slice = DashboardSlice(inYear, options: options, tagFilter: tagFilter, categoryFilter: categoryFilter)
    List {
      LoadableContent(state: state, retry: load) { _ in
        Section {
          MonthlyBarChart(
            title: L("yearlyDashboardCumulativeByMonthTitle"),
            series: YearlyMath.cumulativeWithProjection(all, year: year, netForMonth: { estimates.net($0) }),
            color: .accentColor, signed: true, footnote: footnote(cumulative: true))
        }
        Section {
          MonthlyBarChart(
            title: L("yearlyDashboardNetByMonthTitle"),
            series: YearlyMath.withEstimate(
              YearlyMath.byMonth(base, year: year, kind: .net, options: options), year: year,
              estimate: { estimates.net($0) }),
            color: .accentColor, signed: true, footnote: footnote(cumulative: false))
        }
        Section {
          MonthlyBarChart(
            title: L("yearlyDashboardIncomeByMonthTitle"),
            series: YearlyMath.withEstimate(
              YearlyMath.byMonth(base, year: year, kind: .income, options: options), year: year,
              estimate: { _ in estimates.recurringIncome }),
            color: Money.income, footnote: footnote(cumulative: false))
        }
        Section {
          MonthlyBarChart(
            title: L("yearlyDashboardOutcomeByMonthTitle"),
            series: YearlyMath.withEstimate(
              YearlyMath.byMonth(base, year: year, kind: .outcome, options: options), year: year,
              estimate: { estimates.outcome($0) }),
            color: .red, footnote: footnote(cumulative: false))
        }
        Section {
          ExpenseDonut(
            title: L("monthlyDashboardTagPieTitle"), dimension: .tag, transactions: slice.tagPieTransactions,
            options: options, filter: $tagFilter, onShowAll: { categoryFilter = nil })
        }
        Section {
          ExpenseDonut(
            title: L("monthlyDashboardCategoryPieTitle"), dimension: .category,
            transactions: slice.categoryPieTransactions, options: options, filter: $categoryFilter)
        }
        if slice.listTransactions.isEmpty {
          Section(L("monthlyDashboardTransactionsListTitle")) {
            Text(L("noTransactionsInMonth", String(year))).foregroundStyle(.secondary)
          }
        } else {
          LedgerSections(days: Ledger.groupedByDay(slice.listTransactions), weighted: options.useWeightedAmounts, editor: $editor)
        }
      }
    }
    .offlineBanner(state.fromCache)
    .toolbar { ToolbarItem(placement: .principal) { YearSwitcher(year: $year) } }
    .onChange(of: slice.tagFilter) { _, v in if v != tagFilter { tagFilter = v } }
    .onChange(of: slice.categoryFilter) { _, v in if v != categoryFilter { categoryFilter = v } }
    .refreshable { await load() }
    .task(id: "\(year)-\(model.dataVersion)") { await load() }
    .ledgerEditors($editor)
  }

  private func footnote(cumulative: Bool) -> String? {
    guard year >= WalletCalendar.year(.now) else { return nil }
    return L(cumulative ? "yearlyDashboardCumulativeProjectionHint" : "yearlyDashboardMonthlyProjectionHint")
  }

  private func load() async {
    guard let repo = model.repo else { return }
    let y = year
    var next = Loadable<[Transaction]>()
    next = await next.loaded { try await repo.transactions(throughYear: WalletCalendar.date(y, 1)) }
    // Estimates are optional: a failure here must not block the dashboard.
    let recurring = (try? await repo.recurringMovements().value) ?? []
    let auto = await repo.automaticSource()
    guard y == year else { return }
    state = next
    estimates = YearlyEstimates(recurring: recurring, automatic: auto)
  }
}
