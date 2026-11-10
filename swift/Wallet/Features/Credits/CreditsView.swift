import SwiftUI
import WalletCore
import WalletData

/// Deferred card purchases with installments due in the selected month.
///
/// Long press selects credits to pay off early: the footer then shows what is
/// still pending on the selection, and paying records one card payment from the
/// chosen account and takes those installments off every list.
///
/// Groups ending this month come first (green), then the ones with one
/// installment left (amber), then the rest. The summary card pages through
/// pending/due, "ends this month" and "ends next month".
struct CreditsView: View {
  @Environment(AppModel.self) private var model
  @State private var month = WalletCalendar.startOfMonth(.now)
  @State private var state = Loadable<[Transaction]>()
  @State private var cards: [Card] = []
  @State private var cardFilter: String?
  @State private var editor: EditorRoute?
  @State private var deleting: CreditGroup?
  /// Credits picked with a long press for a joint pay-off.
  @State private var selected = Set<String>()
  @State private var payOff: PayOffRequest?

  var body: some View {
    NavigationStack {
      let cardRows = (state.value ?? []).filter { cardFilter == nil || $0.cardId == cardFilter }
      // Credits with nothing left to pay (including ones just paid off) are settled:
      // they leave the list and every total on this screen.
      let settled = CreditLedger.settledIds(cardRows)
      let flat = cardRows.filter { $0.creditKey != nil && !settled.contains($0.creditKey!) }
      // Only credits with unpaid installments can be selected.
      let pendingById = CreditLedger.pendingRows(flat)
      let selectedPending = selected.filter { pendingById[$0] != nil }
      let selecting = !selectedPending.isEmpty
      let allGroups = CreditLedger.grouped(flat)
      let monthGroups = CreditLedger.sortedByPending(
        CreditLedger.grouped(CreditLedger.installments(inMonth: month, flat)), flat, month: month)
      let fullById = Dictionary(uniqueKeysWithValues: allGroups.map { ($0.id, $0) })
      List {
        LoadableContent(state: state, retry: load) { _ in
          if allGroups.isEmpty {
            ContentUnavailableView(L("creditsEmpty"), systemImage: "calendar.badge.clock").listRowBackground(Color.clear)
          } else if monthGroups.isEmpty {
            ContentUnavailableView(L("creditsEmptyForSelectedMonth"), systemImage: "calendar").listRowBackground(Color.clear)
          }
          ForEach(monthGroups) { g in
            CreditGroupRow(
              group: g, flat: flat, month: month,
              selection: selecting ? selectedPending.contains(g.id) : nil
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture {
              if selecting {
                toggle(g.id, pendingById)
              } else if let first = g.rows.first {
                editor = .editTransaction(first)
              }
            }
            .onLongPressGesture { toggle(g.id, pendingById) }
            .accessibilityAddTraits(.isButton)
            .listRowBackground(selectedPending.contains(g.id) ? Color.accentColor.opacity(0.15) : nil)
            .swipeActions(edge: .trailing) {
              Button(L("delete"), systemImage: "trash", role: .destructive) { deleting = fullById[g.id] }
              Button(L("edit"), systemImage: "pencil") { if let first = g.rows.first { editor = .editTransaction(first) } }
                .tint(.blue)
            }
          }
        }
      }
      // On the list itself, so the floating summary's pager doesn't inherit it.
      .refreshable { await load() }
      .offlineBanner(state.fromCache)
      .navigationTitle(selecting ? L("creditsSelectedCount", selectedPending.count) : L("creditsTitle"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) { MonthSwitcher(month: $month) }
        if selecting {
          ToolbarItem(placement: .topBarLeading) {
            Button(L("creditsClearSelection"), systemImage: "xmark") { selected.removeAll() }
          }
        } else if !cards.isEmpty {
          ToolbarItem(placement: .topBarLeading) { cardFilterMenu }
        }
        ToolbarItem(placement: .primaryAction) {
          Button(L("creditsNewDeferredPurchase"), systemImage: "plus") {
            editor = .newTransaction(TransactionPreset(deferred: true))
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        if selecting {
          selectionBar(selectedPending, pendingById)
        } else if state.value != nil && !allGroups.isEmpty {
          summary(flat)
        }
      }
      .sheet(item: $payOff) { request in
        CreditPayOffSheet(request: request) { selected.removeAll() }
      }
      .task(id: model.dataVersion) { await load() }
      .ledgerEditors($editor)
      .alert(
        L("deleteTransaction"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        presenting: deleting
      ) { full in
        Button(L("delete"), role: .destructive) {
          Task {
            await model.perform("failed to delete credit") { try await $0.deleteTransaction(id: full.rows[0].id, creditKey: full.id) }
          }
        }
        Button(L("cancel"), role: .cancel) {}
      } message: { _ in
        Text(L("confirmDeleteCreditGroupTransaction"))
      }
    }
  }

  private func toggle(_ id: String, _ pendingById: [String: [Transaction]]) {
    guard pendingById[id] != nil else { return }
    if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
  }

  /// Footer while credits are selected: what is still pending on them and the pay action.
  private func selectionBar(_ ids: Set<String>, _ pendingById: [String: [Transaction]]) -> some View {
    let rows = ids.flatMap { pendingById[$0] ?? [] }
    let total = rows.reduce(0) { $0 + $1.value }
    return HStack {
      VStack(alignment: .leading, spacing: 2) {
        AmountText(value: abs(total), font: .title3.weight(.bold), neutral: .secondary, colored: false)
          .foregroundStyle(.red)
        Text(L("creditsSelectedPendingLabel")).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Button(L("creditsPayOffAction")) {
        payOff = PayOffRequest(keys: ids.sorted(), installments: rows.count, total: total)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal, 20).padding(.vertical, 12)
    .background(.bar)
  }

  private var cardFilterMenu: some View {
    Menu {
      Picker(L("creditsFilterByCard"), selection: $cardFilter) {
        Label(L("creditsAllCards"), systemImage: "creditcard").tag(String?.none)
        ForEach(cards) { c in Text(c.name).tag(String?.some(c.id)) }
      }
    } label: {
      Label(L("creditsFilterByCard"), systemImage: cardFilter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
    }
  }

  private func summary(_ flat: [Transaction]) -> some View {
    func owed(_ v: Double) -> Color { abs(v) > 0.005 ? .red : .secondary }
    let pending = CreditLedger.pendingTotal(from: month, flat)
    let due = CreditLedger.dueIn(month: month, flat)
    let ending = CreditLedger.endingInMonthTotal(month, flat)
    let endingNext = CreditLedger.endingNextMonthTotal(month, flat)
    return SummaryCard(pages: [
      .init(stats: [
        Stat(label: L("creditsPendingTotalsLabel"), value: pending, color: owed(pending), unsigned: true),
        Stat(label: L("creditsDueThisMonthLabel"), value: due, color: owed(due), unsigned: true),
      ]),
      .init(stats: [
        Stat(label: L("creditsEndsThisMonthLabel"), value: ending, color: abs(ending) > 0.005 ? Money.income : .secondary, unsigned: true)
      ]),
      .init(stats: [
        Stat(label: L("creditsEndsNextMonthLabel"), value: endingNext, color: abs(endingNext) > 0.005 ? Money.endsNextMonth : .secondary, unsigned: true)
      ]),
    ])
  }

  private func load() async {
    guard let repo = model.repo else { return }
    state = await state.loaded { try await repo.creditInstallments() }
    cards = Sorting.byName((try? await repo.cards().value) ?? [], \.name)
    if let f = cardFilter, !cards.contains(where: { $0.id == f }) { cardFilter = nil }
  }
}

/// One deferred purchase: title, relations, purchase date, progress, and
/// this month's installment, the remaining debt and the total.
struct CreditGroupRow: View {
  /// The credit's installments in [month] (normally one).
  let group: CreditGroup
  let flat: [Transaction]
  let month: Date
  /// nil outside selection mode; otherwise whether this credit is selected.
  var selection: Bool?

  var body: some View {
    let first = group.rows[0]
    let total = CreditLedger.installmentCount(group: group.id, flat)
    let pendingAfter = CreditLedger.countAfter(month: month, group: group.id, flat)
    let remaining = CreditLedger.valueAfter(month: month, group: group.id, flat)
    let totalValue = CreditLedger.totalValue(group: group.id, flat)
    let monthly = group.rows.reduce(0) { $0 + $1.value }
    let accent: Color = pendingAfter == 0 ? Money.income : pendingAfter == 1 ? Money.endsNextMonth : .secondary
    let title = CreditDescription.strip(first.description).trimmingCharacters(in: .whitespaces)
    HStack(alignment: .top, spacing: 12) {
      if let selection {
        Image(systemName: selection ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(selection ? Color.accentColor : .secondary)
          .imageScale(.large)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(title.isEmpty ? L("creditsUntitledGroup") : title).font(.body.weight(.medium)).lineLimit(2)
        if !first.relationNames.isEmpty {
          Text(first.relationNames.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        if let at = first.creditTransactedAt {
          Text(at.formatted(date: .numeric, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
        }
        Text(pendingAfter > 0 ? L("creditsInstallmentsWithPending", total, pendingAfter) : L("creditsInstallmentsEndsThisMonth", total))
          .font(.caption.weight(.semibold)).foregroundStyle(accent)
        ProgressView(value: Double(total - pendingAfter), total: Double(max(total, 1)))
          .tint(accent)
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 2) {
        AmountText(value: monthly, font: .callout.weight(.semibold), neutral: .secondary)
        AmountText(value: remaining, font: .caption.weight(.medium), neutral: .secondary)
        AmountText(value: totalValue, font: .caption, neutral: .secondary, colored: false)
      }
    }
  }
}

/// Credits chosen for an early pay-off.
struct PayOffRequest: Identifiable {
  let id = UUID()
  var keys: [String]
  var installments: Int
  var total: Double
}

/// Asks which account pays, then records the card payment.
struct CreditPayOffSheet: View {
  let request: PayOffRequest
  let onPaid: () -> Void
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var accounts: [Account] = []
  @State private var accountId: String?
  @State private var paying = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(
            L(
              "creditsPayOffMessage", request.installments, request.keys.count,
              abs(request.total).formatted(.number.precision(.fractionLength(2))))
          )
        }
        Section {
          Picker(L("creditsPayOffAccountLabel"), selection: $accountId) {
            Text("—").tag(String?.none)
            ForEach(accounts) { a in Text(a.name).tag(String?.some(a.id)) }
          }
        }
      }
      .navigationTitle(L("creditsPayOffTitle"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task { await pay() }
          } label: {
            if paying { ProgressView() } else { Text(L("creditsPayOffAction")) }
          }
          .disabled(accountId == nil || paying)
        }
      }
      .task {
        accounts = Sorting.byName((try? await model.repo?.accounts().value) ?? [], \.name)
      }
    }
    .interactiveDismissDisabled(paying)
    .presentationDetents([.medium])
  }

  private func pay() async {
    guard let accountId else { return }
    paying = true
    let ok = await model.perform("failed to pay off credits") {
      try await $0.payOffCredits(
        request.keys, fromAccount: accountId, description: L("creditsPayOffTransactionDescription"))
    }
    paying = false
    if ok {
      onPaid()
      dismiss()
    }
  }
}
