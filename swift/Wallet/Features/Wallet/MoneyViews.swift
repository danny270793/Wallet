import SwiftUI
import WalletCore
import WalletData

// MARK: - Loans

struct LoansView: View {
  @Environment(AppModel.self) private var model
  @State private var state = Loadable<[Loan]>()
  @State private var capital: [String: [LoanCapitalPayment]] = [:]
  @State private var accountNames: [String: String] = [:]
  @State private var selection = SelectionState()
  @State private var editing: Loan?
  @State private var creating = false
  @State private var deleting: PendingDelete?

  var body: some View {
    let loans = Sorting.byName(state.value ?? [], \.name)
    List {
      LoadableContent(state: state, retry: load) { _ in
        if loans.isEmpty {
          ContentUnavailableView(L("noLoans"), systemImage: "banknote").listRowBackground(Color.clear)
        }
        ForEach(loans) { loan in
          let amounts = LoanMath.listAmounts(loan, capitalPayments: capital[loan.id] ?? [])
          let row = HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(LoanMath.title(loan))
              Text([accountNames[loan.accountId], L("loanTermMonths", loan.termMonths)].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
              AmountText(value: -amounts.monthly)
              AmountText(value: -amounts.pending, font: .caption, neutral: .secondary)
              AmountText(value: -amounts.total, font: .caption2, neutral: .secondary, colored: false)
            }
          }
          .selectable(selection.isActive, selected: selection.ids.contains(loan.id))
          Group {
            if selection.isActive {
              Button { withAnimation { selection.toggle(loan.id) } } label: { row }.tint(.primary)
            } else {
              NavigationLink { LoanDetailView(loanId: loan.id, initial: loan) } label: { row }
            }
          }
          .onLongPressGesture { withAnimation { selection.toggle(loan.id) } }
          .swipeActions(edge: .trailing) {
            Button(L("delete"), systemImage: "trash", role: .destructive) {
              deleting = PendingDelete(
                id: loan.id, name: loan.name, title: L("deleteLoan"), message: L("confirmDeleteLoan", loan.name)
              ) { await model.perform("failed to delete loan") { try await $0.deleteLoan(id: loan.id) } }
            }
            Button(L("edit"), systemImage: "pencil") { editing = loan }.tint(.blue)
          }
        }
      }
    }
    // On the list itself, so the floating summary's pager doesn't inherit it.
    .refreshable { await load() }
    .offlineBanner(state.fromCache)
    .confirmDelete($deleting)
    .selectionToolbar($selection, title: L("loans"))
    .toolbar { ToolbarItem(placement: .primaryAction) { Button(L("newLoan"), systemImage: "plus") { creating = true } } }
    .safeAreaInset(edge: .bottom) {
      if !loans.isEmpty {
        let picked = selection.isActive ? loans.filter { selection.ids.contains($0.id) } : loans
        SummaryCard(pages: [
          SummaryCard.total(picked.reduce(0) { $0 - LoanMath.listAmounts($1, capitalPayments: capital[$1.id] ?? []).pending })
        ])
      }
    }
    .task(id: model.dataVersion) { await load() }
    .sheet(item: $editing) { LoanEditor(loan: $0) }
    .sheet(isPresented: $creating) { LoanEditor(loan: nil) }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    state = await state.loaded { try await repo.loans() }
    capital = Dictionary(grouping: (try? await repo.capitalPayments().value) ?? [], by: \.loanId)
    accountNames = Dictionary(uniqueKeysWithValues: ((try? await repo.accounts().value) ?? []).map { ($0.id, $0.name) })
  }
}

/// A loan's terms and its payment plan, recomputed with capital payments.
struct LoanDetailView: View {
  @Environment(AppModel.self) private var model
  let loanId: String
  let initial: Loan
  @State private var loan: Loan?
  @State private var capital: [LoanCapitalPayment] = []
  @State private var accountName: String?
  @State private var addingCapital = false
  @State private var editing = false
  @State private var deleting: PendingDelete?

  var body: some View {
    let loan = loan ?? initial
    let schedule = LoanMath.schedule(loan, capitalPayments: capital)
    let total = schedule.reduce(0) { $0 + $1.payment }
    let paidInstallments = schedule.filter { $0.installment != nil && $0.isPaid() }.reduce(0) { $0 + $1.payment }
    let paidCapital = schedule.filter { $0.installment == nil }.reduce(0) { $0 + $1.payment }
    let count = schedule.compactMap(\.installment).count
    List {
      Section(L("details")) {
        LabeledContent(L("loanAccount"), value: accountName ?? "")
        LabeledContent(L("loanValue")) { AmountText(value: loan.value, colored: false) }
        LabeledContent(L("loanTotalToPay")) { AmountText(value: total, colored: false) }
        LabeledContent(L("loanInterestToPay")) { AmountText(value: total - loan.value, colored: false) }
        LabeledContent(L("cardNominalInterestRate"), value: loan.nominalInterestRate.map { "\($0.fixed2) %" } ?? "—")
        LabeledContent(L("transactionMesesPlazo"), value: "\(loan.termMonths)")
        LabeledContent(L("loanFirstPaymentDate"), value: Dates.short(loan.firstPaymentDate))
        LabeledContent(L("loanPaymentDay"), value: "\(loan.paymentDay)")
        LabeledContent(L("loanMonthlyPayment")) {
          AmountText(value: LoanMath.currentPayment(loan, capitalPayments: capital), colored: false)
        }
      }
      Section(L("loanSchedule")) {
        ForEach(Array(schedule.enumerated()), id: \.offset) { _, entry in
          switch entry {
          case .installment(let i):
            let paid = entry.isPaid()
            HStack(spacing: 12) {
              Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(paid ? AnyShapeStyle(Money.income) : AnyShapeStyle(.tertiary))
              VStack(alignment: .leading, spacing: 2) {
                Text("\(i.number)/\(count) · \(Dates.short(i.date))")
                Text(L("loanInstallmentBreakdown", i.principal.fixed2, i.interest.fixed2, i.remaining.fixed2))
                  .font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              AmountText(value: -i.payment)
            }
            .opacity(paid ? 0.55 : 1)
          case .capitalPayment(let p, let remaining):
            HStack(spacing: 12) {
              IconTile(symbol: "arrow.down.to.line", color: .green, size: 26)
              VStack(alignment: .leading, spacing: 2) {
                Text("\(L("loanCapitalPayment")) · \(Dates.short(p.paidAt))")
                Text(L("loanCapitalPaymentLeft", remaining.fixed2)).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              AmountText(value: -p.value)
            }
            .swipeActions {
              Button(L("delete"), systemImage: "trash", role: .destructive) {
                deleting = PendingDelete(
                  id: p.id, name: "", title: L("loanDeleteCapitalPayment"), message: L("loanConfirmDeleteCapitalPayment")
                ) {
                  if await model.perform("failed to delete loan capital payment", { try await $0.deleteCapitalPayment(id: p.id) }) {
                    await load()
                  }
                }
              }
            }
          }
        }
      }
    }
    // On the list itself, so the floating summary's pager doesn't inherit it.
    .refreshable { await load() }
    .navigationTitle(loan.name)
    .confirmDelete($deleting)
    .toolbar {
      ToolbarItem(placement: .primaryAction) { Button(L("edit")) { editing = true } }
      ToolbarSpacer(.fixed, placement: .primaryAction)
      ToolbarItem(placement: .primaryAction) {
        Button(L("loanCapitalPayment"), systemImage: "plus") { addingCapital = true }
      }
    }
    .safeAreaInset(edge: .bottom) {
      SummaryCard(pages: [
        .init(stats: [
          Stat(label: L("loanPaidInstallments"), value: paidInstallments, color: .primary, unsigned: true),
          Stat(label: L("loanPaidToCapital"), value: paidCapital, color: .primary, unsigned: true),
          Stat(label: L("loanPending"), value: total - paidInstallments - paidCapital, color: .red, unsigned: true),
        ])
      ])
    }
    .task(id: model.dataVersion) { await load() }
    .sheet(isPresented: $addingCapital) {
      CapitalPaymentEditor(loan: loan, capital: capital) { await load() }
    }
    .sheet(isPresented: $editing) { LoanEditor(loan: loan) }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    if let found = try? await repo.loans().value.first(where: { $0.id == loanId }) { loan = found }
    capital = ((try? await repo.capitalPayments().value) ?? []).filter { $0.loanId == loanId }
    let id = (loan ?? initial).accountId
    accountName = try? await repo.accounts().value.first { $0.id == id }?.name
  }
}

/// Amount and day of a payment to capital (at most what is owed that day).
struct CapitalPaymentEditor: View {
  @Environment(AppModel.self) private var model
  let loan: Loan
  let capital: [LoanCapitalPayment]
  let onSaved: () async -> Void
  @State private var paidAt = WalletCalendar.startOfDay(.now)
  @State private var value = ""

  var body: some View {
    let max = LoanMath.balance(on: paidAt, loan, capitalPayments: capital)
    let v = AmountInput.parse(value) ?? 0
    let error: String? = value.isEmpty ? nil : v <= 0 ? L("loanValueInvalid") : v > max + 1e-6 ? L("loanCapitalPaymentMax", max.fixed2) : nil
    EditorForm(title: L("loanCapitalPayment"), canSave: v > 0 && v <= max + 1e-6) {
      let ok = await model.perform("failed to create loan capital payment") {
        try await $0.createCapitalPayment(loanId: loan.id, value: v, paidAt: WalletCalendar.startOfDay(paidAt))
      }
      if ok { await onSaved() }
      return ok
    } content: {
      DatePicker(L("loanCapitalPaymentDate"), selection: $paidAt, displayedComponents: .date)
      Section {
        AmountField(label: L("loanValue"), text: $value, allowNegative: false, error: error)
      } footer: {
        Text(L("loanCapitalPaymentMax", max.fixed2))
      }
    }
    .presentationDetents([.medium])
  }
}

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
          rowView(row)
            .selectable(selection.isActive, selected: selection.ids.contains(row.id))
            .contentShape(.rect)
            .onTapGesture { if selection.isActive { withAnimation { selection.toggle(row.id) } } else if case .movement(let m) = row { editing = m } }
            .onLongPressGesture { withAnimation { selection.toggle(row.id) } }
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
    case .loan: "recurringAutomaticLoan"
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
          AssetRow(asset: a)
            .contentShape(.rect)
            .onTapGesture { editing = a }
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
