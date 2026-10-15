import SwiftUI
import WalletCore
import WalletData

/// A month of transactions, optionally scoped to an account, card, category or tag.
///
/// Liquid Glass layout: the month switcher lives in the navigation bar's
/// principal slot, "Add" is a toolbar menu (new / transfer / pay) instead of
/// a speed-dial FAB, and the five totals modes float on a swipeable glass
/// card above the tab bar.
struct TransactionsView: View {
  @Environment(AppModel.self) private var model
  var scope: Ledger.Scope = .all
  @State private var month = WalletCalendar.startOfMonth(.now)
  @State private var state = Loadable<[Transaction]>()
  @State private var editor: EditorRoute?

  private var all: [Transaction] { state.value ?? [] }
  private var filtered: [Transaction] { all.filter(scope.matches) }

  var body: some View {
    List {
      LoadableContent(state: state, retry: load) { _ in
        let rows = Ledger.withTransferPeers(filtered, all: all, scope: scope)
        if rows.isEmpty {
          ContentUnavailableView(
            L("noTransactionsInMonth", Dates.monthYear(month)), systemImage: "tray")
            .listRowBackground(Color.clear)
        } else {
          LedgerSections(days: days(rows), editor: $editor)
        }
      }
    }
    .listStyle(.insetGrouped)
    .offlineBanner(state.fromCache)
    .navigationTitle(scope.title.map { "\($0) · \(L("transactions"))" } ?? L("transactions"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) { MonthSwitcher(month: $month) }
      ToolbarItem(placement: .primaryAction) { AddLedgerMenu(editor: $editor, preset: TransactionPreset(scope: scope)) }
    }
    .safeAreaInset(edge: .bottom) {
      if state.value != nil { SummaryCard(pages: SummaryCard.ledgerModes(filtered)) }
    }
    .refreshable { await load() }
    .task(id: "\(month.timeIntervalSince1970)-\(model.dataVersion)") { await load() }
    .ledgerEditors($editor)
  }

  /// Every day of the month up to today is listed, so empty days show too.
  private func days(_ rows: [Transaction]) -> [LedgerDay] {
    let next = WalletCalendar.monthStart(month, offset: 1)
    let tomorrow = WalletCalendar.addDays(WalletCalendar.startOfDay(.now), 1)
    let end = min(next, tomorrow)
    return end > month
      ? Ledger.groupedByDay(rows, fillFrom: month, fillTo: end) : Ledger.groupedByDay(rows)
  }

  private func load() async {
    guard let repo = model.repo else { return }
    let m = month
    var next = state
    if !WalletCalendar.isSameMonth(next.value?.first?.transactedAt ?? m, m) { next = Loadable() }
    next = await next.loaded { try await repo.transactions(month: m) }
    if m == month { state = next }
  }
}

/// "+" menu: new transaction, transfer between accounts, pay a card.
struct AddLedgerMenu: View {
  @Binding var editor: EditorRoute?
  var preset = TransactionPreset()

  var body: some View {
    Menu {
      Button(L("newTransaction"), systemImage: "plus.circle") { editor = .newTransaction(preset) }
      Button(L("transactionsFabTransfer"), systemImage: "arrow.left.arrow.right") { editor = .transfer(payCard: false) }
      Button(L("transactionsFabPay"), systemImage: "creditcard.and.123") { editor = .transfer(payCard: true) }
    } label: {
      Label(L("addMenu"), systemImage: "plus")
    } primaryAction: {
      editor = .newTransaction(preset)
    }
  }
}
