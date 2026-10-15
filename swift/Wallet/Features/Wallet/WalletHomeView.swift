import SwiftUI
import WalletCore
import WalletData

/// The Wallet tab: one place for everything that used to live in the
/// Flutter drawer. Accounts and cards show their balances inline; the rest
/// are grouped as Money (loans, recurring, assets) and Organize (categories, tags).
struct WalletHomeView: View {
  @Environment(AppModel.self) private var model
  @State private var accounts = Loadable<[Account]>()
  @State private var cards = Loadable<[Card]>()
  @State private var credits: [String: CardCreditTotals] = [:]
  @State private var editor: SubEditor?

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink { AccountsView() } label: {
            SummaryRow(
              title: L("accounts"), symbol: "building.columns.fill", color: .blue,
              value: accounts.value.map { $0.reduce(0) { $0 + $1.balance } })
          }
          NavigationLink { CardsView() } label: {
            SummaryRow(
              title: L("cards"), symbol: "creditcard.fill", color: .purple,
              value: cards.value.map { $0.reduce(0) { $0 + CreditLedger.postedBalance($1.balance, credits[$1.id]) } })
          }
        }
        Section(L("walletMoneySection")) {
          NavigationLink { LoansView() } label: { SummaryRow(title: L("loans"), symbol: "banknote.fill", color: .orange) }
          NavigationLink { RecurringMovementsView() } label: {
            SummaryRow(title: L("recurringMovements"), symbol: "repeat", color: .teal)
          }
          NavigationLink { AssetsView() } label: { SummaryRow(title: L("assets"), symbol: "shippingbox.fill", color: .brown) }
        }
        Section(L("walletOrganizeSection")) {
          NavigationLink { NamedItemsView(isTags: false) } label: {
            SummaryRow(title: L("categories"), symbol: "square.grid.2x2.fill", color: .pink)
          }
          NavigationLink { NamedItemsView(isTags: true) } label: { SummaryRow(title: L("tags"), symbol: "tag.fill", color: .indigo) }
        }
      }
      .navigationTitle(L("tabWallet"))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          NavigationLink { SettingsView() } label: { Label(L("settings"), systemImage: "gearshape") }
        }
        ToolbarItem(placement: .primaryAction) {
          Menu(L("addMenu"), systemImage: "plus") {
            Button(L("newAccount"), systemImage: "building.columns") { editor = .account(nil) }
            Button(L("newCard"), systemImage: "creditcard") { editor = .card(nil) }
            Divider()
            Button(L("newCategory"), systemImage: "square.grid.2x2") { editor = .category(nil) }
            Button(L("newTag"), systemImage: "tag") { editor = .tag(nil) }
          }
        }
      }
      .refreshable { await load() }
      .task(id: model.dataVersion) { await load() }
      .sheet(item: $editor) { $0.view }
    }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    accounts = await accounts.loaded { try await repo.accounts() }
    cards = await cards.loaded { try await repo.cards() }
    credits = CreditLedger.totalsByCard((try? await repo.creditInstallments().value) ?? [])
  }
}

struct SummaryRow: View {
  let title: String
  let symbol: String
  let color: Color
  var value: Double?

  var body: some View {
    HStack(spacing: 12) {
      IconTile(symbol: symbol, color: color)
      Text(title)
      Spacer()
      if let value { AmountText(value: value, font: .callout.weight(.semibold)) }
    }
  }
}

// MARK: - Shared list behavior

/// Long-press to select rows; the summary then totals the selection only.
struct SelectionState {
  var ids: Set<String> = []
  var isActive: Bool { !ids.isEmpty }
  mutating func toggle(_ id: String) { if ids.remove(id) == nil { ids.insert(id) } }
}

/// A delete waiting for confirmation, tied to the row it was started from.
struct PendingDelete {
  var id: String
  var name: String
  var title: String
  var message: String?
  var action: () async -> Void
}

/// Confirms a destructive delete, then runs it. Attach to each row (not the
/// list) so the dialog is anchored to the row being deleted.
struct DeleteConfirmation: ViewModifier {
  @Binding var item: PendingDelete?
  let id: String

  func body(content: Content) -> some View {
    content.confirmationDialog(
      item?.title ?? "", isPresented: Binding(get: { item?.id == id }, set: { if !$0 { item = nil } }),
      titleVisibility: .visible
    ) {
      Button(L("delete"), role: .destructive) {
        let a = item?.action
        Task { await a?() }
      }
    } message: {
      Text(item?.message ?? L("confirmDeleteAccount", item?.name ?? ""))
    }
  }
}

extension View {
  func confirmDelete(_ item: Binding<PendingDelete?>, id: String) -> some View {
    modifier(DeleteConfirmation(item: item, id: id))
  }

  /// Leading "selected" check shown while selecting.
  func selectable(_ selecting: Bool, selected: Bool) -> some View {
    HStack(spacing: 12) {
      if selecting {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
          .font(.title3)
          .transition(.move(edge: .leading).combined(with: .opacity))
      }
      self
    }
  }

  /// Title and Done button for selection mode.
  func selectionToolbar(_ selection: Binding<SelectionState>, title: String) -> some View {
    navigationTitle(selection.wrappedValue.isActive ? L("listSelectedCount", selection.wrappedValue.ids.count) : title)
      .toolbar {
        if selection.wrappedValue.isActive {
          ToolbarItem(placement: .cancellationAction) {
            Button(L("done")) { withAnimation { selection.wrappedValue.ids.removeAll() } }
          }
        }
      }
  }
}

// MARK: - Accounts

struct AccountsView: View {
  @Environment(AppModel.self) private var model
  @State private var state = Loadable<[Account]>()
  @State private var selection = SelectionState()
  @State private var editor: SubEditor?
  @State private var deleting: PendingDelete?

  var body: some View {
    let items = Sorting.byName(state.value ?? [], \.name)
    List {
      LoadableContent(state: state, retry: load) { _ in
        if items.isEmpty {
          ContentUnavailableView(L("noAccounts"), systemImage: "building.columns").listRowBackground(Color.clear)
        }
        ForEach(items) { a in
          let row = HStack {
            Text(a.name)
            Spacer()
            AmountText(value: a.balance)
          }
          .selectable(selection.isActive, selected: selection.ids.contains(a.id))
          Group {
            if selection.isActive {
              Button { withAnimation { selection.toggle(a.id) } } label: { row }.tint(.primary)
            } else {
              NavigationLink {
                TransactionsView(scope: Ledger.Scope(accountId: a.id, title: a.name))
              } label: { row }
            }
          }
          .onLongPressGesture { withAnimation { selection.toggle(a.id) } }
          .swipeActions(edge: .trailing) {
            Button(L("delete"), systemImage: "trash", role: .destructive) {
              deleting = PendingDelete(
                id: a.id, name: a.name, title: L("deleteAccount"), message: L("confirmDeleteAccount", a.name)
              ) { await model.perform("failed to delete account") { try await $0.deleteAccount(id: a.id) } }
            }
            Button(L("edit"), systemImage: "pencil") { editor = .account(a) }.tint(.blue)
          }
          .confirmDelete($deleting, id: a.id)
        }
      }
    }
    // On the list itself, so the floating summary's pager doesn't inherit it.
    .refreshable { await load() }
    .offlineBanner(state.fromCache)
    .selectionToolbar($selection, title: L("accounts"))
    .toolbar { ToolbarItem(placement: .primaryAction) { Button(L("newAccount"), systemImage: "plus") { editor = .account(nil) } } }
    .safeAreaInset(edge: .bottom) {
      if !items.isEmpty {
        let picked = selection.isActive ? items.filter { selection.ids.contains($0.id) } : items
        SummaryCard(pages: [SummaryCard.total(picked.reduce(0) { $0 + $1.balance })])
      }
    }
    .task(id: model.dataVersion) { await load() }
    .sheet(item: $editor) { $0.view }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    state = await state.loaded { try await repo.accounts() }
  }
}

// MARK: - Cards

struct CardsView: View {
  @Environment(AppModel.self) private var model
  @State private var state = Loadable<[Card]>()
  @State private var credits: [String: CardCreditTotals] = [:]
  @State private var selection = SelectionState()
  @State private var editor: SubEditor?
  @State private var deleting: PendingDelete?

  var body: some View {
    let items = Sorting.byName(state.value ?? [], \.name)
    List {
      LoadableContent(state: state, retry: load) { _ in
        if items.isEmpty {
          ContentUnavailableView(L("noCards"), systemImage: "creditcard").listRowBackground(Color.clear)
        }
        ForEach(items) { c in
          let row = HStack(spacing: 12) {
            CardBadge(type: c.type)
            VStack(alignment: .leading, spacing: 2) {
              Text(c.nominalInterestRate.map { "\(c.name) (\($0.fixed2) %)" } ?? c.name)
              Text(L("cardBillingCycleSummary", c.cutDay, c.payDay)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              AmountText(value: CreditLedger.postedBalance(c.balance, credits[c.id]))
              AmountText(value: credits[c.id]?.pending ?? 0, font: .caption, neutral: .secondary)
            }
          }
          .selectable(selection.isActive, selected: selection.ids.contains(c.id))
          Group {
            if selection.isActive {
              Button { withAnimation { selection.toggle(c.id) } } label: { row }.tint(.primary)
            } else {
              NavigationLink { TransactionsView(scope: Ledger.Scope(cardId: c.id, title: c.name)) } label: { row }
            }
          }
          .onLongPressGesture { withAnimation { selection.toggle(c.id) } }
          .swipeActions(edge: .trailing) {
            Button(L("delete"), systemImage: "trash", role: .destructive) {
              deleting = PendingDelete(
                id: c.id, name: c.name, title: L("deleteCard"), message: L("confirmDeleteCard", c.name)
              ) { await model.perform("failed to delete card") { try await $0.deleteCard(id: c.id) } }
            }
            Button(L("edit"), systemImage: "pencil") { editor = .card(c) }.tint(.blue)
          }
          .confirmDelete($deleting, id: c.id)
        }
      }
    }
    // On the list itself, so the floating summary's pager doesn't inherit it.
    .refreshable { await load() }
    .offlineBanner(state.fromCache)
    .selectionToolbar($selection, title: L("cards"))
    .toolbar { ToolbarItem(placement: .primaryAction) { Button(L("newCard"), systemImage: "plus") { editor = .card(nil) } } }
    .safeAreaInset(edge: .bottom) {
      if !items.isEmpty {
        let picked = selection.isActive ? items.filter { selection.ids.contains($0.id) } : items
        let nonCredits = picked.reduce(0) { $0 + CreditLedger.postedBalance($1.balance, credits[$1.id]) }
        let creditsTotal = picked.reduce(0) { $0 + (credits[$1.id]?.pending ?? 0) }
        SummaryCard(pages: [
          .init(stats: [
            Stat(label: L("cardsTotalNonCredits"), value: nonCredits),
            Stat(label: L("cardsTotalCredits"), value: creditsTotal),
            Stat(label: L("listBalanceTotalLabel"), value: nonCredits + creditsTotal),
          ])
        ])
      }
    }
    .task(id: model.dataVersion) { await load() }
    .sheet(item: $editor) { $0.view }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    state = await state.loaded { try await repo.cards() }
    credits = CreditLedger.totalsByCard((try? await repo.creditInstallments().value) ?? [])
  }
}

// MARK: - Categories & tags

struct NamedItemsView: View {
  @Environment(AppModel.self) private var model
  let isTags: Bool
  @State private var categories = Loadable<[WalletCore.Category]>()
  @State private var tags = Loadable<[Tag]>()
  @State private var editor: SubEditor?
  @State private var deleting: PendingDelete?

  private struct Item: Identifiable {
    var id: String, name: String, description: String?, hidden: Bool
  }

  var body: some View {
    let items: [Item] =
      isTags
      ? Sorting.visibleThenByName(tags.value ?? []).map { Item(id: $0.id, name: $0.name, description: $0.description, hidden: $0.hidden) }
      : Sorting.byName(categories.value ?? [], \.name).map { Item(id: $0.id, name: $0.name, description: $0.description, hidden: false) }
    let loaded = isTags ? tags.value != nil : categories.value != nil
    let failure = isTags ? tags.failure : categories.failure
    List {
      if let failure, !loaded {
        LoadFailureView(failure: failure, retry: load)
      } else if !loaded {
        ProgressView().frame(maxWidth: .infinity)
      } else if items.isEmpty {
        ContentUnavailableView(L(isTags ? "noTags" : "noCategories"), systemImage: isTags ? "tag" : "square.grid.2x2")
          .listRowBackground(Color.clear)
      }
      ForEach(items) { item in
        NavigationLink {
          TransactionsView(
            scope: isTags ? Ledger.Scope(tagId: item.id, title: item.name) : Ledger.Scope(categoryId: item.id, title: item.name))
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(item.name)
              if let d = item.description, !d.isEmpty { Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            if item.hidden {
              Spacer()
              Image(systemName: "eye.slash").foregroundStyle(.secondary).accessibilityLabel(L("tagHidden"))
            }
          }
          .opacity(item.hidden ? 0.55 : 1)
        }
        .swipeActions(edge: .trailing) {
          Button(L("delete"), systemImage: "trash", role: .destructive) {
            deleting = PendingDelete(
              id: item.id, name: item.name, title: L(isTags ? "deleteTag" : "deleteCategory"),
              message: L(isTags ? "confirmDeleteTag" : "confirmDeleteCategory", item.name)
            ) {
              await model.perform("failed to delete") {
                isTags ? try await $0.deleteTag(id: item.id) : try await $0.deleteCategory(id: item.id)
              }
            }
          }
          Button(L("edit"), systemImage: "pencil") {
            editor = isTags ? .tag(tags.value?.first { $0.id == item.id }) : .category(categories.value?.first { $0.id == item.id })
          }
          .tint(.blue)
        }
        .confirmDelete($deleting, id: item.id)
      }
    }
    // On the list itself, so the floating summary's pager doesn't inherit it.
    .refreshable { await load() }
    .offlineBanner(isTags ? tags.fromCache : categories.fromCache)
    .navigationTitle(L(isTags ? "tags" : "categories"))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(L(isTags ? "newTag" : "newCategory"), systemImage: "plus") { editor = isTags ? .tag(nil) : .category(nil) }
      }
    }
    .task(id: model.dataVersion) { await load() }
    .sheet(item: $editor) { $0.view }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    if isTags { tags = await tags.loaded { try await repo.tags() } } else { categories = await categories.loaded { try await repo.categories() } }
  }
}
