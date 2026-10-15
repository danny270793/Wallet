import SwiftUI
import WalletCore
import WalletData

/// Shared shell for the simple editors: form, Cancel / Save, saving spinner.
struct EditorForm<Content: View>: View {
  let title: String
  let canSave: Bool
  let save: () async -> Bool
  @ViewBuilder let content: Content
  @Environment(\.dismiss) private var dismiss
  @State private var saving = false

  var body: some View {
    NavigationStack {
      Form { content }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
              Task {
                saving = true
                let ok = await save()
                saving = false
                if ok { dismiss() }
              }
            } label: {
              if saving { ProgressView() } else { Label(L("save"), systemImage: "checkmark") }
            }
            .disabled(!canSave || saving)
          }
        }
    }
    .interactiveDismissDisabled(saving)
  }
}

/// Account name, and on edit its balance: changing it posts an "Adjustment".
struct AccountEditor: View {
  @Environment(AppModel.self) private var model
  let account: Account?
  @State private var name: String
  @State private var balance: String

  init(account: Account?) {
    self.account = account
    _name = State(initialValue: account?.name ?? "")
    _balance = State(initialValue: account.map { $0.balance.fixed2 } ?? "")
  }

  var body: some View {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    EditorForm(
      title: L(account == nil ? "newAccount" : "editAccount"),
      canSave: !trimmed.isEmpty && (account == nil || AmountInput.parse(balance) != nil)
    ) {
      guard let account else {
        return await model.perform("failed to create account") { try await $0.createAccount(name: trimmed) }
      }
      let target = AmountInput.parse(balance) ?? account.balance
      return await model.perform("failed to update account") {
        try await $0.updateAccount(id: account.id, name: trimmed)
        try await $0.adjustBalance(.account(account.id), delta: target - account.balance)
      }
    } content: {
      TextField(L("accountName"), text: $name)
      if account != nil { AmountField(label: L("accountBalance"), text: $balance) }
    }
    .presentationDetents([.medium])
  }
}

/// Card name, network, rate, cut/pay days; on edit the posted balance is
/// adjustable and the deferred/total balances are shown.
struct CardEditor: View {
  @Environment(AppModel.self) private var model
  let card: Card?
  @State private var name: String
  @State private var type: CardType
  @State private var rate: String
  @State private var cutDay: Int?
  @State private var payDay: Int?
  @State private var balance = ""
  @State private var posted: Double?
  @State private var deferred: Double = 0

  init(card: Card?) {
    self.card = card
    _name = State(initialValue: card?.name ?? "")
    _type = State(initialValue: card?.type ?? .visa)
    _rate = State(initialValue: card?.nominalInterestRate.map { String(format: "%g", $0) } ?? "")
    _cutDay = State(initialValue: card?.cutDay ?? 24)
    _payDay = State(initialValue: card?.payDay ?? 24)
  }

  private var rateValue: Double?? {
    let t = rate.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return .some(nil) }
    guard let v = AmountInput.parse(t), v >= 0 else { return nil }
    return .some(v)
  }

  var body: some View {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    EditorForm(
      title: L(card == nil ? "newCard" : "editCard"),
      canSave: !trimmed.isEmpty && rateValue != nil && cutDay != nil && payDay != nil
        && (card == nil || AmountInput.parse(balance) != nil)
    ) {
      let r = rateValue ?? nil
      guard let card else {
        return await model.perform("failed to create card") {
          try await $0.createCard(name: trimmed, type: type, rate: r, cutDay: cutDay!, payDay: payDay!)
        }
      }
      return await model.perform("failed to update card") { repo in
        try await repo.updateCard(id: card.id, name: trimmed, type: type, rate: r, cutDay: cutDay!, payDay: payDay!)
        // Recompute the posted balance now so the adjustment uses fresh numbers.
        let credits = CreditLedger.totalsByCard((try? await repo.creditInstallments().value) ?? [])
        let current = CreditLedger.postedBalance(card.balance, credits[card.id])
        try await repo.adjustBalance(.card(card.id), delta: (AmountInput.parse(balance) ?? current) - current)
      }
    } content: {
      Section {
        TextField(L("accountName"), text: $name)
        Picker(L("cardType"), selection: $type) {
          ForEach(CardType.allCases, id: \.self) { t in
            Label(t.label, systemImage: t.symbol).tag(t)
          }
        }
        LabeledContent(L("cardNominalInterestRate")) {
          TextField("0", text: $rate).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
        if rateValue == nil { Text(L("cardNominalInterestRateInvalid")).font(.caption).foregroundStyle(.red) }
      }
      Section {
        DayOfMonthPicker(label: L("cardCutDay"), day: $cutDay)
        DayOfMonthPicker(label: L("cardPayDay"), day: $payDay)
      }
      if card != nil {
        Section {
          if posted == nil {
            LabeledContent(L("cardRevolvingBalance")) { ProgressView() }
          } else {
            AmountField(label: L("cardRevolvingBalance"), text: $balance)
          }
          LabeledContent(L("cardDeferredBalance")) { AmountText(value: deferred) }
          LabeledContent(L("cardTotalBalance")) {
            AmountText(value: (AmountInput.parse(balance) ?? posted ?? 0) + deferred)
          }
        }
      }
    }
    .task { await loadBalances() }
  }

  private func loadBalances() async {
    guard let card, let repo = model.repo else { return }
    let credits = CreditLedger.totalsByCard((try? await repo.creditInstallments().value) ?? [])[card.id]
    let p = CreditLedger.postedBalance(card.balance, credits)
    posted = p
    deferred = credits?.pending ?? 0
    balance = p.fixed2
  }
}

/// Category or tag: name, description; tags also have "hidden".
struct NamedItemEditor: View {
  enum Kind {
    case category(WalletCore.Category?)
    case tag(Tag?)
  }

  @Environment(AppModel.self) private var model
  let kind: Kind
  @State private var name: String
  @State private var description: String
  @State private var hidden: Bool

  init(kind: Kind) {
    self.kind = kind
    switch kind {
    case .category(let c):
      _name = State(initialValue: c?.name ?? "")
      _description = State(initialValue: c?.description ?? "")
      _hidden = State(initialValue: false)
    case .tag(let t):
      _name = State(initialValue: t?.name ?? "")
      _description = State(initialValue: t?.description ?? "")
      _hidden = State(initialValue: t?.hidden ?? false)
    }
  }

  private var title: String {
    switch kind {
    case .category(let c): L(c == nil ? "newCategory" : "editCategory")
    case .tag(let t): L(t == nil ? "newTag" : "editTag")
    }
  }

  var body: some View {
    let n = name.trimmingCharacters(in: .whitespaces)
    let d = description.trimmingCharacters(in: .whitespaces)
    let desc: String? = d.isEmpty ? nil : d
    EditorForm(title: title, canSave: !n.isEmpty) {
      switch kind {
      case .category(let c):
        return await model.perform("failed to save category") {
          if let c { try await $0.updateCategory(id: c.id, name: n, description: desc) } else {
            try await $0.createCategory(name: n, description: desc)
          }
        }
      case .tag(let t):
        return await model.perform("failed to save tag") {
          if let t { try await $0.updateTag(id: t.id, name: n, description: desc, hidden: hidden) } else {
            try await $0.createTag(name: n, description: desc)
          }
        }
      }
    } content: {
      Section {
        TextField(L("accountName"), text: $name)
        TextField(L("accountDescription"), text: $description, axis: .vertical).lineLimit(1...4)
      }
      if case .tag(.some) = kind {
        Section {
          Toggle(L("tagHidden"), isOn: $hidden)
        } footer: {
          Text(L("tagHiddenHint"))
        }
      }
    }
    .presentationDetents([.medium])
  }
}

/// Loan: account, amount, rate, term, first payment date and payment day.
struct LoanEditor: View {
  @Environment(AppModel.self) private var model
  let loan: Loan?
  @State private var name: String
  @State private var accountId: String?
  @State private var value: String
  @State private var rate: String
  @State private var term: String
  @State private var firstPayment: Date?
  @State private var paymentDay: Int?
  @State private var accounts: [Account] = []
  @State private var picking = false

  init(loan: Loan?) {
    self.loan = loan
    _name = State(initialValue: loan?.name ?? "")
    _accountId = State(initialValue: loan?.accountId)
    _value = State(initialValue: loan.map { $0.value.fixed2 } ?? "")
    _rate = State(initialValue: loan?.nominalInterestRate.map { String(format: "%g", $0) } ?? "")
    _term = State(initialValue: loan.map { "\($0.termMonths)" } ?? "")
    _firstPayment = State(initialValue: loan?.firstPaymentDate)
    _paymentDay = State(initialValue: loan?.paymentDay)
  }

  private var rateValue: Double?? {
    let t = rate.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return .some(nil) }
    guard let v = AmountInput.parse(t), v >= 0 else { return nil }
    return .some(v)
  }

  var body: some View {
    let n = name.trimmingCharacters(in: .whitespaces)
    let v = AmountInput.parse(value) ?? 0
    let months = Int(term) ?? 0
    EditorForm(
      title: L(loan == nil ? "newLoan" : "editLoan"),
      canSave: !n.isEmpty && accountId != nil && v > 0 && months >= 1 && rateValue != nil && firstPayment != nil
        && paymentDay != nil
    ) {
      await model.perform("failed to save loan") {
        try await $0.saveLoan(
          id: loan?.id, accountId: accountId!, name: n, value: v, rate: rateValue ?? nil, termMonths: months,
          paymentDay: paymentDay!, firstPaymentDate: firstPayment!)
      }
    } content: {
      Section {
        TextField(L("accountName"), text: $name)
        PickerField(label: L("loanAccount"), value: accounts.first { $0.id == accountId }?.name) { picking = true }
      }
      Section {
        AmountField(label: L("loanValue"), text: $value, allowNegative: false,
                    error: !value.isEmpty && v <= 0 ? L("loanValueInvalid") : nil)
        LabeledContent(L("cardNominalInterestRate")) {
          TextField("0", text: $rate).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
        IntField(label: L("transactionMesesPlazo"), text: $term)
        if !term.isEmpty && months < 1 { Text(L("loanTermInvalid")).font(.caption).foregroundStyle(.red) }
      }
      Section {
        DatePicker(
          L("loanFirstPaymentDate"),
          selection: Binding(
            get: { firstPayment ?? WalletCalendar.startOfDay(.now) },
            set: { d in
              firstPayment = WalletCalendar.startOfDay(d)
              if paymentDay == nil { paymentDay = min(WalletCalendar.day(d), 30) }
            }),
          displayedComponents: .date)
        DayOfMonthPicker(label: L("loanPaymentDay"), day: $paymentDay)
      }
    }
    .sheet(isPresented: $picking) {
      SearchablePicker(
        title: L("loanAccount"), sections: [(nil, accounts.map { PickItem(id: $0.id, name: $0.name) })],
        selected: accountId, emptyMessage: L("noAccounts")
      ) { accountId = $0.id }
    }
    .task { accounts = Sorting.byName((try? await model.repo?.accounts().value) ?? [], \.name) }
  }
}

/// Expected monthly income/outcome with category, tag and yearly flag.
struct RecurringMovementEditor: View {
  @Environment(AppModel.self) private var model
  let movement: RecurringMovement?
  @State private var name: String
  @State private var value: String
  @State private var description: String
  @State private var categoryId: String?
  @State private var tagId: String?
  @State private var yearly: Bool
  @State private var categories: [WalletCore.Category] = []
  @State private var tags: [Tag] = []
  @State private var picker: TransactionEditor.PickerKind?

  init(movement: RecurringMovement?) {
    self.movement = movement
    _name = State(initialValue: movement?.name ?? "")
    _value = State(initialValue: movement.map { $0.value.fixed2 } ?? "")
    _description = State(initialValue: movement?.description ?? "")
    _categoryId = State(initialValue: movement?.categoryId)
    _tagId = State(initialValue: movement?.tagId)
    _yearly = State(initialValue: movement?.yearlyPayment ?? false)
  }

  var body: some View {
    let n = name.trimmingCharacters(in: .whitespaces)
    let v = AmountInput.parse(value) ?? 0
    let d = description.trimmingCharacters(in: .whitespaces)
    EditorForm(
      title: L(movement == nil ? "newRecurringMovement" : "editRecurringMovement"),
      canSave: !n.isEmpty && v != 0 && categoryId != nil && tagId != nil
    ) {
      await model.perform("failed to save recurring movement") {
        try await $0.saveRecurringMovement(
          id: movement?.id, name: n, description: d.isEmpty ? nil : d, value: v, categoryId: categoryId!,
          tagId: tagId!, yearly: yearly)
      }
    } content: {
      Section {
        TextField(L("accountName"), text: $name)
      }
      Section {
        AmountField(label: L("transactionAmount"), text: $value)
      } footer: {
        Text(L("recurringMovementValueHint"))
      }
      Section {
        PickerField(label: L("transactionCategory"), value: categories.first { $0.id == categoryId }?.name) {
          picker = .category
        }
        PickerField(label: L("transactionTag"), value: tags.first { $0.id == tagId }?.name) { picker = .tag }
        TextField(L("accountDescription"), text: $description, axis: .vertical).lineLimit(1...3)
      }
      Section {
        Toggle(L("transactionYearlyPayment"), isOn: $yearly)
      } footer: {
        Text(L("transactionYearlyPaymentHint"))
      }
    }
    .sheet(item: $picker) { kind in
      if kind == .category {
        SearchablePicker(
          title: L("transactionCategory"), sections: [(nil, categories.map { PickItem(id: $0.id, name: $0.name) })],
          selected: categoryId, emptyMessage: L("noCategories")
        ) { categoryId = $0.id }
      } else {
        SearchablePicker(
          title: L("transactionTag"),
          sections: [(nil, tags.filter { !$0.hidden }.map { PickItem(id: $0.id, name: $0.name) })],
          selected: tagId, emptyMessage: L("noTags")
        ) { tagId = $0.id }
      }
    }
    .task {
      categories = Sorting.byName((try? await model.repo?.categories().value) ?? [], \.name)
      tags = Sorting.visibleThenByName((try? await model.repo?.tags().value) ?? [])
    }
  }
}

/// Asset: provider, value, purchase date; optional end date and sold amount.
struct AssetEditor: View {
  @Environment(AppModel.self) private var model
  let asset: Asset?
  @State private var name: String
  @State private var provider: String
  @State private var value: String
  @State private var boughtAt: Date
  @State private var hasEnd: Bool
  @State private var endedAt: Date
  @State private var sold: String

  init(asset: Asset?) {
    self.asset = asset
    _name = State(initialValue: asset?.name ?? "")
    _provider = State(initialValue: asset?.provider ?? "")
    _value = State(initialValue: asset.map { $0.value.fixed2 } ?? "")
    _boughtAt = State(initialValue: asset?.boughtAt ?? .now)
    _hasEnd = State(initialValue: asset?.endedAt != nil)
    _endedAt = State(initialValue: asset?.endedAt ?? .now)
    _sold = State(initialValue: asset?.soldValue?.fixed2 ?? "")
  }

  var body: some View {
    let n = name.trimmingCharacters(in: .whitespaces)
    let v = AmountInput.parse(value)
    let soldValue = sold.isEmpty ? nil : AmountInput.parse(sold)
    let endBeforeStart = hasEnd && WalletCalendar.startOfDay(endedAt) < WalletCalendar.startOfDay(boughtAt)
    EditorForm(
      title: L(asset == nil ? "newAsset" : "editAsset"),
      canSave: !n.isEmpty && v != nil && (sold.isEmpty || soldValue != nil) && !endBeforeStart
    ) {
      await model.perform("failed to save asset") {
        try await $0.saveAsset(
          id: asset?.id, name: n, provider: provider.trimmingCharacters(in: .whitespaces), value: v!,
          boughtAt: boughtAt, endedAt: hasEnd ? endedAt : nil, soldValue: soldValue)
      }
    } content: {
      Section {
        TextField(L("accountName"), text: $name)
        TextField(L("assetProvider"), text: $provider)
        AmountField(label: L("assetValue"), text: $value, error: !value.isEmpty && v == nil ? L("assetInvalidNumber") : nil)
        DatePicker(L("assetPurchaseDate"), selection: $boughtAt, displayedComponents: .date)
      }
      Section {
        Toggle(L("assetEndDate"), isOn: $hasEnd.animation())
        if hasEnd {
          DatePicker(L("assetEndDate"), selection: $endedAt, displayedComponents: .date)
          if endBeforeStart { Text(L("assetEndBeforePurchase")).font(.caption).foregroundStyle(.red) }
        }
        AmountField(
          label: L("assetSoldAmountField"), text: $sold, allowNegative: false,
          error: !sold.isEmpty && soldValue == nil ? L("assetInvalidNumber") : nil)
      }
    }
  }
}
