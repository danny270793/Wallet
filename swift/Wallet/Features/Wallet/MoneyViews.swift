import SwiftUI
import WalletCore
import WalletData

// MARK: - Recurring movements

struct RecurringMovementsView: View {
  @Environment(AppModel.self) private var model
  @State private var state = Loadable<[RecurringMovement]>()
  @State private var source = AutomaticMovementsSource()
  @State private var month = WalletCalendar.startOfMonth(.now)
  @State private var selection = SelectionState()
  @State private var editing: RecurringMovement?
  @State private var creating = false
  @State private var deleting: PendingDelete?

  private enum Row: Identifiable {
    case movement(RecurringMovement)
    case automatic(AutomaticMovement)
    var id: String {
      switch self {
      case .movement(let m): m.id
      case .automatic(let a): a.id
      }
    }
    var name: String {
      switch self {
      case .movement(let m): m.name
      case .automatic(let a): a.name
      }
    }
    var monthly: Double {
      switch self {
      case .movement(let m): m.monthlyAmount
      case .automatic(let a): a.monthlyAmount
      }
    }
  }

  /// Highest to lowest monthly amount, then name.
  private var rows: [Row] {
    let all = (state.value ?? []).map(Row.movement) + source.forMonth(month).map(Row.automatic)
    return all.sorted { $0.monthly != $1.monthly ? $0.monthly > $1.monthly : $0.name.lowercased() < $1.name.lowercased() }
  }

  var body: some View {
    let rows = rows
    List {
      LoadableContent(state: state, retry: load) { _ in
        if rows.isEmpty {
          ContentUnavailableView(L("noRecurringMovements"), systemImage: "repeat").listRowBackground(Color.clear)
        }
        ForEach(rows) { row in
          Button {
            if selection.isActive {
              withAnimation { selection.toggle(row.id) }
            } else if case .movement(let m) = row {
              editing = m
            }
          } label: {
            rowView(row).selectable(selection.isActive, selected: selection.ids.contains(row.id))
          }
          .tint(.primary)
          .selectMenu($selection, id: row.id)
            .swipeActions(edge: .trailing) {
              if case .movement(let m) = row, !selection.isActive {
                Button(L("delete"), systemImage: "trash", role: .destructive) {
                  deleting = PendingDelete(
                    id: m.id, name: m.name, title: L("deleteRecurringMovement"),
                    message: L("confirmDeleteRecurringMovement", m.name)
                  ) { await model.perform("failed to delete recurring movement") { try await $0.deleteRecurringMovement(id: m.id) } }
                }
                Button(L("edit"), systemImage: "pencil") { editing = m }.tint(.blue)
              }
            }
        }
      }
    }
    // On the list itself, so the floating summary's pager doesn't inherit it.
    .refreshable { await load() }
    .offlineBanner(state.fromCache)
    .confirmDelete($deleting)
    .selectionToolbar($selection, title: L("recurringMovements"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) { MonthSwitcher(month: $month) }
      ToolbarItem(placement: .primaryAction) { Button(L("newRecurringMovement"), systemImage: "plus") { creating = true } }
    }
    .onChange(of: month) { selection.ids = selection.ids.filter { !$0.contains(":") } }
    .safeAreaInset(edge: .bottom) {
      if state.value != nil {
        let picked = selection.isActive ? rows.filter { selection.ids.contains($0.id) } : rows
        let income = picked.filter { $0.monthly > 0 }.reduce(0) { $0 + $1.monthly }
        let outcome = picked.filter { $0.monthly < 0 }.reduce(0) { $0 - $1.monthly }
        SummaryCard(pages: [SummaryCard.totals(Totals(income: income, outcome: outcome, balance: income - outcome))])
      }
    }
    .task(id: model.dataVersion) { await load() }
    .sheet(item: $editing) { RecurringMovementEditor(movement: $0) }
    .sheet(isPresented: $creating) { RecurringMovementEditor(movement: nil) }
  }

  @ViewBuilder private func rowView(_ row: Row) -> some View {
    switch row {
    case .movement(let m):
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(m.name)
          let rel = [m.categoryName, m.tagName].compactMap { $0 }.filter { !$0.isEmpty }
          if !rel.isEmpty { Text(rel.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
          if let d = m.description, !d.isEmpty { Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          AmountText(value: m.monthlyAmount)
          if m.yearlyPayment { Text(Money.text(m.value)).font(.caption).monospacedDigit().foregroundStyle(.secondary) }
        }
      }
    case .automatic(let a):
      HStack(spacing: 12) {
        if let t = a.cardType { CardBadge(type: t, size: 26) } else { IconTile(symbol: "banknote", color: .orange, size: 26) }
        VStack(alignment: .leading, spacing: 2) {
          Text(a.name)
          Text(L(automaticLabel(a))).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        AmountText(value: a.monthlyAmount)
      }
      .foregroundStyle(.secondary)
    }
  }

  private func automaticLabel(_ a: AutomaticMovement) -> String {
    switch a {
    case .cardInterest: "recurringAutomaticCardInterest"
    case .cardDeferred: "recurringAutomaticCardDeferred"
    }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    state = await state.loaded { try await repo.recurringMovements() }
    source = await repo.automaticSource()
  }
}

// MARK: - Assets

struct AssetsView: View {
  @Environment(AppModel.self) private var model
  @State private var state = Loadable<[Asset]>()
  @State private var editing: Asset?
  @State private var creating = false
  @State private var deleting: PendingDelete?

  var body: some View {
    let assets = (state.value ?? []).sorted { $0.boughtAt > $1.boughtAt }
    List {
      LoadableContent(state: state, retry: load) { _ in
        if assets.isEmpty {
          ContentUnavailableView(L("noAssets"), systemImage: "shippingbox").listRowBackground(Color.clear)
        }
        ForEach(assets) { a in
          Button { editing = a } label: {
            AssetRow(asset: a).frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
          }
          .tint(.primary)
            .swipeActions(edge: .trailing) {
              Button(L("delete"), systemImage: "trash", role: .destructive) {
                deleting = PendingDelete(
                  id: a.id, name: a.name, title: L("deleteAsset"), message: L("confirmDeleteAsset", a.name)
                ) { await model.perform("failed to delete asset") { try await $0.deleteAsset(id: a.id) } }
              }
              Button(L("edit"), systemImage: "pencil") { editing = a }.tint(.blue)
            }
        }
      }
    }
    // On the list itself, so the floating summary's pager doesn't inherit it.
    .refreshable { await load() }
    .offlineBanner(state.fromCache)
    .confirmDelete($deleting)
    .navigationTitle(L("assets"))
    .toolbar { ToolbarItem(placement: .primaryAction) { Button(L("newAsset"), systemImage: "plus") { creating = true } } }
    .task(id: model.dataVersion) { await load() }
    .sheet(item: $editing) { AssetEditor(asset: $0) }
    .sheet(isPresented: $creating) { AssetEditor(asset: nil) }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    state = await state.loaded { try await repo.assets() }
  }
}

/// Name, provider, period and held time; value and its monthly average.
struct AssetRow: View {
  let asset: Asset

  var body: some View {
    let a = asset
    let ymd = AssetHolding.ymd(boughtAt: a.boughtAt, endedAt: a.endedAt)
    let underAMonth = ymd.map { $0.years == 0 && $0.months == 0 } ?? true
    let perMonth = underAMonth ? nil : AssetHolding.valuePerMonth(a.value, boughtAt: a.boughtAt, endedAt: a.endedAt)
    let soldPerMonth = a.soldValue.flatMap { underAMonth ? nil : AssetHolding.valuePerMonth($0, boughtAt: a.boughtAt, endedAt: a.endedAt) }
    let period = a.endedAt.map { "\(Dates.short(a.boughtAt)) → \(Dates.short($0))" } ?? Dates.short(a.boughtAt)
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(a.name).font(.body.weight(.semibold))
          if a.isEnded {
            Text(L("assetSold")).font(.caption2.weight(.bold))
              .padding(.horizontal, 6).padding(.vertical, 2)
              .background(.secondary.opacity(0.15), in: .capsule)
          }
        }
        if !a.provider.isEmpty { Text(a.provider).font(.caption).foregroundStyle(.secondary) }
        Text(period).font(.caption).monospacedDigit().foregroundStyle(.secondary)
        Text(L("assetHeldDuration", AssetHolding.compactDuration(boughtAt: a.boughtAt, endedAt: a.endedAt)))
          .font(.caption).foregroundStyle(.secondary)
        if let s = a.soldValue {
          Text("\(L("assetSold")): \(Money.text(s))").font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        if let perMonth {
          Text(L("assetValuePerApproximateMonth", Money.text(perMonth)))
            .font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(a.isEnded ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
          Text(Money.text(a.value)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
        } else {
          Text(Money.text(a.value)).font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(.tint)
        }
        if let soldPerMonth {
          Text(L("assetSoldPerApproximateMonth", Money.text(soldPerMonth))).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
      }
    }
    .opacity(a.isEnded ? 0.75 : 1)
  }
}
