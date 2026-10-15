import SwiftUI
import WalletCore
import WalletData

/// Deferred card purchases with installments due in the selected month.
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

  var body: some View {
    NavigationStack {
      let flat = (state.value ?? []).filter { cardFilter == nil || $0.cardId == cardFilter }
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
              group: g, flat: flat, month: month, cardType: cards.first { $0.id == g.rows.first?.cardId }?.type
            )
            .contentShape(.rect)
            .onTapGesture { if let first = g.rows.first { editor = .editTransaction(first) } }
            .swipeActions(edge: .trailing) {
              Button(L("delete"), systemImage: "trash", role: .destructive) { deleting = fullById[g.id] }
              Button(L("edit"), systemImage: "pencil") { if let first = g.rows.first { editor = .editTransaction(first) } }
                .tint(.blue)
            }
            .confirmationDialog(
              L("deleteTransaction"), isPresented: Binding(get: { deleting?.id == g.id }, set: { if !$0 { deleting = nil } }),
              titleVisibility: .visible, presenting: deleting
            ) { full in
              Button(L("delete"), role: .destructive) {
                Task {
                  await model.perform("failed to delete credit") { try await $0.deleteTransaction(id: full.rows[0].id, creditKey: full.id) }
                }
              }
            } message: { _ in
              Text(L("confirmDeleteCreditGroupTransaction"))
            }
          }
        }
      }
      // On the list itself, so the floating summary's pager doesn't inherit it.
      .refreshable { await load() }
      .offlineBanner(state.fromCache)
      .navigationTitle(L("creditsTitle"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) { MonthSwitcher(month: $month) }
        if !cards.isEmpty {
          ToolbarItem(placement: .topBarLeading) { cardFilterMenu }
        }
        ToolbarItem(placement: .primaryAction) {
          Button(L("creditsNewDeferredPurchase"), systemImage: "plus") {
            editor = .newTransaction(TransactionPreset(deferred: true))
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        if state.value != nil && !allGroups.isEmpty { summary(flat) }
      }
      .task(id: model.dataVersion) { await load() }
      .ledgerEditors($editor)
    }
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
/// the remaining / total amounts.
struct CreditGroupRow: View {
  let group: CreditGroup
  let flat: [Transaction]
  let month: Date
  let cardType: CardType?

  var body: some View {
    let first = group.rows[0]
    let total = CreditLedger.installmentCount(group: group.id, flat)
    let pendingAfter = CreditLedger.countAfter(month: month, group: group.id, flat)
    let remaining = CreditLedger.valueAfter(month: month, group: group.id, flat)
    let totalValue = CreditLedger.totalValue(group: group.id, flat)
    let accent: Color = pendingAfter == 0 ? Money.income : pendingAfter == 1 ? Money.endsNextMonth : .secondary
    let title = CreditDescription.strip(first.description).trimmingCharacters(in: .whitespaces)
    HStack(alignment: .top, spacing: 12) {
      CardBadge(type: cardType, size: 30)
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
        AmountText(value: remaining, font: .callout.weight(.semibold), neutral: .secondary)
        AmountText(value: totalValue, font: .caption, neutral: .secondary, colored: false)
      }
    }
  }
}
