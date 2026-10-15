import SwiftUI
import WalletCore
import WalletData

/// New / edit transaction sheet.
///
/// Rules carried over from the Flutter editor:
/// - payment method, category and tag are required; amount is non-zero; % is 0–100;
/// - "Deferred" (cards only, new rows) splits the amount into monthly
///   installments with grace/term; installments are always saved as ignored;
/// - editing an installment edits the whole purchase (total amount, grace,
///   term; changing grace/term reschedules every installment);
/// - typing a description suggests past transactions; picking one fills the
///   empty fields.
struct TransactionEditor: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss

  let transaction: Transaction?
  let preset: TransactionPreset

  @State private var date: Date
  @State private var description: String
  @State private var amount: String
  @State private var percentage: String
  @State private var ignore: Bool
  @State private var accountId: String?
  @State private var cardId: String?
  @State private var categoryId: String?
  @State private var tagId: String?
  @State private var deferred: Bool
  @State private var graceMonths: String
  @State private var termMonths = ""
  /// Linked `wallet_credits` row: grace/term can be edited (reschedules).
  @State private var creditEditable = false

  @State private var accounts: [Account] = []
  @State private var cards: [Card] = []
  @State private var categories: [WalletCore.Category] = []
  @State private var tags: [Tag] = []
  @State private var loadingLookups = true
  @State private var loadingCreditTotal: Bool
  @State private var saving = false
  @State private var showErrors = false
  @State private var picker: PickerKind?

  @State private var suggestions: [Transaction] = []
  @State private var suggestionsLoading = false
  /// After applying a suggestion, hide the list until the text changes again.
  @State private var suppressedSuggestionFor: String?

  enum PickerKind: Identifiable {
    case payment, category, tag
    var id: Self { self }
  }

  init(transaction: Transaction?, preset: TransactionPreset) {
    self.transaction = transaction
    self.preset = preset
    let t = transaction
    let isCredit = t?.isCreditInstallment ?? false
    _date = State(initialValue: (isCredit ? t?.creditTransactedAt : nil) ?? t?.transactedAt ?? .now)
    _description = State(initialValue: isCredit ? CreditDescription.strip(t?.description) : t?.description ?? "")
    _amount = State(initialValue: t.map { $0.value.fixed2 } ?? "")
    _percentage = State(initialValue: t.map { String(format: "%g", $0.percentage) } ?? "100")
    _ignore = State(initialValue: t?.ignore ?? preset.deferred)
    _accountId = State(initialValue: t?.accountId ?? (preset.cardsOnly ? nil : preset.accountId))
    _cardId = State(initialValue: t?.cardId ?? preset.cardId)
    _categoryId = State(initialValue: t?.categoryId ?? preset.categoryId)
    _tagId = State(initialValue: t?.tagId ?? preset.tagId)
    _deferred = State(initialValue: isCredit || (t == nil && preset.deferred))
    _graceMonths = State(initialValue: t == nil && preset.deferred ? "0" : "")
    _loadingCreditTotal = State(initialValue: isCredit)
  }

  private var isEdit: Bool { transaction != nil }
  private var isCreditEdit: Bool { transaction?.isCreditInstallment ?? false }
  private var cardsOnly: Bool { preset.cardsOnly || deferred }
  /// New deferred installments are saved ignored regardless of the toggle.
  private var creatingInstallments: Bool { !isEdit && deferred && cardId != nil }
  private var ignoreLocked: Bool { creatingInstallments || isCreditEdit }

  // MARK: Validation

  private var amountError: String? {
    if amount.trimmingCharacters(in: .whitespaces).isEmpty { return L("fieldRequired") }
    guard let v = AmountInput.parse(amount) else { return L("transactionAmountInvalidNumber") }
    return v == 0 ? L("transactionAmountMustBeNonZero") : nil
  }

  private var percentageError: String? {
    guard let p = Double(percentage.trimmingCharacters(in: .whitespaces)) else { return L("fieldRequired") }
    return p < 0 || p > 100 ? L("transactionPercentageInvalidRange") : nil
  }

  private var termError: String? {
    guard deferred, cardId != nil, !isCreditEdit || creditEditable else { return nil }
    guard let n = Int(termMonths) else { return L("fieldRequired") }
    return n < 2 ? L("transactionTermMonthsInvalid") : nil
  }

  private var graceError: String? {
    guard deferred, cardId != nil else { return nil }
    if graceMonths.isEmpty { return isCreditEdit && creditEditable ? L("fieldRequired") : nil }
    return Int(graceMonths) == nil ? L("transactionGraceMonthsInvalid") : nil
  }

  private var isValid: Bool {
    amountError == nil && percentageError == nil && termError == nil && graceError == nil
      && (accountId != nil || cardId != nil) && categoryId != nil && tagId != nil
  }

  // MARK: View

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker(L("transactionDateTime"), selection: $date)
          TextField(L("accountDescription"), text: $description)
            .submitLabel(.next)
          if showSuggestions { suggestionRows }
        }

        Section {
          if loadingCreditTotal {
            LabeledContent(L("transactionAmount")) { ProgressView() }
          } else {
            AmountField(label: L("transactionAmount"), text: $amount, error: showErrors ? amountError : nil)
          }
          PickerField(
            label: L("transactionPaymentMethod"), value: paymentName, badge: selectedCard?.type,
            loading: loadingLookups, invalid: showErrors && accountId == nil && cardId == nil
          ) { picker = .payment }
        } footer: {
          if isCreditEdit { Text(L("transactionAmountCreditGroupHint")) }
        }

        if !loadingLookups, cardId != nil, !isEdit || isCreditEdit {
          Section {
            Toggle(L("transactionDeferred"), isOn: $deferred)
              .disabled(isEdit || preset.deferred)
              .onChange(of: deferred) { _, on in
                if on {
                  if graceMonths.isEmpty { graceMonths = "0" }
                  ignore = true
                } else {
                  graceMonths = ""
                  termMonths = ""
                }
              }
            if deferred {
              if loadingCreditTotal {
                LabeledContent(L("transactionGraceMonths")) { ProgressView() }
              } else {
                IntField(label: L("transactionGraceMonths"), text: $graceMonths, disabled: isCreditEdit && !creditEditable)
                IntField(label: L("transactionMesesPlazo"), text: $termMonths, disabled: isCreditEdit && !creditEditable)
                if showErrors, let e = termError ?? graceError { Text(e).font(.caption).foregroundStyle(.red) }
              }
            }
          } footer: {
            if isCreditEdit && !creditEditable { Text(L("creditEditGraceNotApplicable")) }
          }
        }

        Section {
          PickerField(
            label: L("transactionCategory"), value: categories.first { $0.id == categoryId }?.name,
            loading: loadingLookups, invalid: showErrors && categoryId == nil
          ) { picker = .category }
          PickerField(
            label: L("transactionTag"), value: tags.first { $0.id == tagId }?.name, loading: loadingLookups,
            invalid: showErrors && tagId == nil
          ) { picker = .tag }
        }

        Section {
          LabeledContent(L("transactionPercentage")) {
            TextField("100", text: $percentage)
              .keyboardType(.decimalPad).multilineTextAlignment(.trailing).monospacedDigit()
          }
          if showErrors, let e = percentageError { Text(e).font(.caption).foregroundStyle(.red) }
          Toggle(L("transactionIgnore"), isOn: Binding(get: { creatingInstallments || ignore }, set: { ignore = $0 }))
            .disabled(ignoreLocked)
        }
      }
      .navigationTitle(isEdit ? L("editTransaction") : L("newTransaction"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(role: .confirm) {
            Task { await save() }
          } label: {
            if saving { ProgressView() } else { Label(L("save"), systemImage: "checkmark") }
          }
          .disabled(saving || loadingLookups)
        }
      }
      .sheet(item: $picker) { kind in pickerSheet(kind) }
      .task { await loadLookups() }
      .task { await loadCreditGroup() }
      .task(id: description) { await loadSuggestions() }
    }
    .interactiveDismissDisabled(saving)
  }

  private var selectedCard: Card? { cards.first { $0.id == cardId } }
  private var paymentName: String? { accounts.first { $0.id == accountId }?.name ?? selectedCard?.name }

  // MARK: Suggestions

  private var showSuggestions: Bool {
    !isEdit && !description.trimmingCharacters(in: .whitespaces).isEmpty && suppressedSuggestionFor != description
  }

  @ViewBuilder private var suggestionRows: some View {
    if suggestionsLoading && suggestions.isEmpty {
      ProgressView().frame(maxWidth: .infinity)
    } else if suggestions.isEmpty {
      Text(L("transactionsSearchNoResults")).font(.footnote).foregroundStyle(.secondary)
    } else {
      ForEach(suggestions.prefix(6)) { t in
        Button { apply(t) } label: { TransactionRowView(transaction: t) }
          .tint(.primary)
          .disabled(loadingLookups)
      }
    }
  }

  private func loadSuggestions() async {
    guard showSuggestions, let repo = model.repo else {
      suggestions = []
      return
    }
    let q = description
    suggestionsLoading = true
    try? await Task.sleep(for: .milliseconds(400))
    guard !Task.isCancelled else { return }
    let remote = (try? await repo.searchTransactions(q, limit: 80)) ?? []
    guard !Task.isCancelled, q == description else { return }
    suggestions = remote
    suggestionsLoading = false
  }

  /// Fills the empty fields from a past transaction.
  private func apply(_ t: Transaction) {
    if accountId == nil && cardId == nil {
      accountId = cardsOnly ? nil : t.accountId
      cardId = accountId == nil ? t.cardId : nil
    }
    categoryId = categoryId ?? t.categoryId
    tagId = tagId ?? t.tagId
    ignore = t.ignore
    if (AmountInput.parse(amount) ?? 0) == 0 { amount = t.value.fixed2 }
    percentage = String(format: "%g", t.percentage)
    description = t.description ?? ""
    suppressedSuggestionFor = description
    suggestions = []
  }

  // MARK: Loading

  private func loadLookups() async {
    guard let repo = model.repo else { return }
    async let a = try? repo.accounts().value
    async let c = try? repo.cards().value
    async let cat = try? repo.categories().value
    async let tg = try? repo.tags().value
    accounts = Sorting.byName(await a ?? [], \.name)
    cards = Sorting.byName(await c ?? [], \.name)
    categories = Sorting.byName(await cat ?? [], \.name)
    tags = Sorting.visibleThenByName(await tg ?? [])
    if let id = accountId, !accounts.contains(where: { $0.id == id }) { accountId = nil }
    if let id = cardId, !cards.contains(where: { $0.id == id }) { cardId = nil }
    if cardsOnly { accountId = nil }
    if accountId != nil { cardId = nil }
    if let id = categoryId, !categories.contains(where: { $0.id == id }) { categoryId = nil }
    if let id = tagId, !tags.contains(where: { $0.id == id }) { tagId = nil }
    loadingLookups = false
  }

  /// For an installment: show the purchase total and its grace/term.
  private func loadCreditGroup() async {
    guard let key = transaction?.creditKey, let repo = model.repo else { return }
    let rows = (try? await repo.installments(credit: key)) ?? []
    let credit = try? await repo.credit(id: key)
    amount = rows.reduce(0) { $0 + $1.value }.fixed2
    if let credit {
      termMonths = "\(credit.termMonths)"
      graceMonths = "\(credit.graceMonths)"
      creditEditable = true
    } else {
      termMonths = rows.isEmpty ? "" : "\(rows.count)"
      graceMonths = "—"
    }
    loadingCreditTotal = false
  }

  // MARK: Save

  private func save() async {
    showErrors = true
    guard isValid, let value = AmountInput.parse(amount), let pct = Double(percentage) else { return }
    saving = true
    let note = description.trimmingCharacters(in: .whitespacesAndNewlines)
    let draft = WalletRepository.TransactionDraft(
      accountId: accountId, cardId: cardId, categoryId: categoryId, tagId: tagId, description: note.isEmpty ? nil : note,
      transactedAt: date, value: value, ignore: ignore, percentage: pct, transferGroupId: transaction?.transferGroupId,
      creditId: transaction?.creditId)
    let isDeferred = deferred && cardId != nil
    let grace = Int(graceMonths) ?? 0
    let term = Int(termMonths)
    let ok: Bool
    if let t = transaction {
      ok = await model.perform("failed to update transaction") {
        try await $0.updateTransaction(
          id: t.id, draft, creditGraceMonths: creditEditable ? grace : nil, creditTermMonths: creditEditable ? term : nil)
      }
    } else {
      ok = await model.perform("failed to create transaction") {
        try await $0.createTransaction(draft, deferred: isDeferred, graceMonths: grace, termMonths: term ?? 1)
      }
    }
    saving = false
    if ok { dismiss() }
  }

  // MARK: Pickers

  @ViewBuilder private func pickerSheet(_ kind: PickerKind) -> some View {
    switch kind {
    case .payment:
      SearchablePicker(
        title: L("transactionPaymentMethod"),
        sections: [
          (L("accounts"), cardsOnly ? [] : accounts.map { PickItem(id: "a:\($0.id)", name: $0.name) }),
          (L("cards"), cards.map { PickItem(id: "c:\($0.id)", name: $0.name, badge: $0.type, isCard: true) }),
        ],
        selected: accountId.map { "a:\($0)" } ?? cardId.map { "c:\($0)" },
        emptyMessage: L("transactionPaymentMethodSearchNoResults"),
        addOptions: (cardsOnly ? [] : [.init(title: L("newAccount"), symbol: "building.columns", editor: .account(nil))])
          + [.init(title: L("newCard"), symbol: "creditcard", editor: .card(nil))],
        editorFor: { item in
          if item.isCard { return cards.first { "c:\($0.id)" == item.id }.map(SubEditor.card) }
          return accounts.first { "a:\($0.id)" == item.id }.map(SubEditor.account)
        },
        onEditorClosed: { await loadLookups() },
        onDelete: { item in
          let id = String(item.id.dropFirst(2))
          if await model.perform("failed to delete", { item.isCard ? try await $0.deleteCard(id: id) : try await $0.deleteAccount(id: id) }) {
            await loadLookups()
          }
        },
        deleteMessage: { L($0.isCard ? "confirmDeleteCard" : "confirmDeleteAccount", $0.name) }
      ) { item in
        let id = String(item.id.dropFirst(2))
        if item.isCard {
          cardId = id
          accountId = nil
          if deferred {
            ignore = true
            if graceMonths.isEmpty { graceMonths = "0" }
          }
        } else {
          accountId = id
          cardId = nil
          if !isEdit && !preset.deferred { deferred = false }
        }
      }
    case .category:
      SearchablePicker(
        title: L("transactionCategory"), sections: [(nil, categories.map { PickItem(id: $0.id, name: $0.name) })],
        selected: categoryId, emptyMessage: L("noCategories"),
        addOptions: [.init(title: L("newCategory"), symbol: "square.grid.2x2", editor: .category(nil))],
        editorFor: { item in categories.first { $0.id == item.id }.map(SubEditor.category) },
        onEditorClosed: { await loadLookups() },
        onDelete: { item in
          if await model.perform("failed to delete category", { try await $0.deleteCategory(id: item.id) }) {
            await loadLookups()
          }
        },
        deleteMessage: { L("confirmDeleteCategory", $0.name) }
      ) { categoryId = $0.id }
    case .tag:
      SearchablePicker(
        title: L("transactionTag"),
        sections: [(nil, tags.filter { !$0.hidden }.map { PickItem(id: $0.id, name: $0.name) })],
        selected: tagId, emptyMessage: L("noTags"),
        addOptions: [.init(title: L("newTag"), symbol: "tag", editor: .tag(nil))],
        editorFor: { item in tags.first { $0.id == item.id }.map(SubEditor.tag) },
        onEditorClosed: { await loadLookups() },
        onDelete: { item in
          if await model.perform("failed to delete tag", { try await $0.deleteTag(id: item.id) }) { await loadLookups() }
        },
        deleteMessage: { L("confirmDeleteTag", $0.name) }
      ) { tagId = $0.id }
    }
  }
}

/// Editors that can be opened on top of another editor.
enum SubEditor: Identifiable {
  case account(Account?)
  case card(Card?)
  case category(WalletCore.Category?)
  case tag(Tag?)

  var id: String {
    switch self {
    case .account(let a): "account-\(a?.id ?? "new")"
    case .card(let c): "card-\(c?.id ?? "new")"
    case .category(let c): "category-\(c?.id ?? "new")"
    case .tag(let t): "tag-\(t?.id ?? "new")"
    }
  }

  @MainActor @ViewBuilder var view: some View {
    switch self {
    case .account(let a): AccountEditor(account: a)
    case .card(let c): CardEditor(card: c)
    case .category(let c): NamedItemEditor(kind: .category(c))
    case .tag(let t): NamedItemEditor(kind: .tag(t))
    }
  }
}
