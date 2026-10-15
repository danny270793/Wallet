import SwiftUI
import WalletCore
import WalletData

/// Transfer between payment methods, or pay a card from an account.
///
/// Transfer: source is an account or card, target an account.
/// Pay: source is an account, target a card. Both legs share a group id.
struct TransferEditor: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss

  private let editing: (source: Transaction, target: Transaction)?
  private let payCard: Bool

  @State private var date: Date
  @State private var amount: String
  @State private var ignore: Bool
  @State private var source: WalletRepository.Leg?
  @State private var target: WalletRepository.Leg?
  @State private var accounts: [Account] = []
  @State private var cards: [Card] = []
  @State private var loading = true
  @State private var saving = false
  @State private var showErrors = false
  @State private var picking: Bool?  // true = source, false = target

  init(payCard: Bool) {
    editing = nil
    self.payCard = payCard
    _date = State(initialValue: .now)
    _amount = State(initialValue: "")
    _ignore = State(initialValue: false)
  }

  init(source: Transaction, target: Transaction) {
    editing = (source, target)
    payCard = target.cardId != nil
    _date = State(initialValue: source.transactedAt)
    _amount = State(initialValue: abs(target.value).fixed2)
    _ignore = State(initialValue: source.ignore || target.ignore)
    _source = State(initialValue: WalletRepository.Leg(source))
    _target = State(initialValue: WalletRepository.Leg(target))
  }

  private var canSubmitLegs: Bool {
    payCard ? !accounts.isEmpty && !cards.isEmpty : accounts.count >= 2 || (!accounts.isEmpty && !cards.isEmpty)
  }

  private var amountError: String? {
    if amount.isEmpty { return L("fieldRequired") }
    guard let v = AmountInput.parse(amount) else { return L("transactionAmountInvalidNumber") }
    return v <= 0 ? L("transferAmountMustBePositive") : nil
  }

  private var title: String {
    switch (editing != nil, payCard) {
    case (true, true): L("editPayTitle")
    case (true, false): L("editTransferTitle")
    case (false, true): L("paySheetTitle")
    case (false, false): L("transferSheetTitle")
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section { DatePicker(L("transactionDateTime"), selection: $date) }
        Section {
          if !loading && !canSubmitLegs {
            Text(L(payCard ? "payNeedAccountAndCard" : "transferNeedTwoAccounts"))
              .foregroundStyle(.secondary)
          } else {
            PickerField(
              label: L(payCard ? "transactionAccount" : "transferSourceAccount"), value: name(source),
              badge: card(source)?.type, loading: loading, invalid: showErrors && source == nil
            ) { picking = true }
            PickerField(
              label: L(payCard ? "transactionCard" : "transferTargetAccount"), value: name(target),
              badge: card(target)?.type, loading: loading, invalid: showErrors && target == nil
            ) { picking = false }
          }
        } footer: {
          if showErrors, source != nil, source == target { Text(L("transferAccountsMustDiffer")).foregroundStyle(.red) }
        }
        Section {
          AmountField(
            label: L("transactionAmount"), text: $amount, allowNegative: false, error: showErrors ? amountError : nil)
          if editing != nil { Toggle(L("transactionIgnore"), isOn: $ignore) }
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(role: .confirm) { Task { await save() } } label: {
            if saving { ProgressView() } else { Label(L("save"), systemImage: "checkmark") }
          }
          .disabled(saving || loading || !canSubmitLegs)
        }
      }
      .sheet(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } })) {
        legPicker(source: picking ?? true)
      }
      .task { await load() }
    }
    .presentationDetents([.medium, .large])
  }

  private func name(_ leg: WalletRepository.Leg?) -> String? {
    switch leg {
    case .account(let id): accounts.first { $0.id == id }?.name
    case .card(let id): cards.first { $0.id == id }?.name
    case nil: nil
    }
  }

  private func card(_ leg: WalletRepository.Leg?) -> Card? {
    guard case .card(let id) = leg else { return nil }
    return cards.first { $0.id == id }
  }

  private func load() async {
    guard let repo = model.repo else { return }
    accounts = Sorting.byName((try? await repo.accounts().value) ?? [], \.name)
    cards = Sorting.byName((try? await repo.cards().value) ?? [], \.name)
    // Drop picks that no longer exist or no longer fit this mode.
    func valid(_ l: WalletRepository.Leg?) -> Bool {
      switch l {
      case .account(let id): accounts.contains { $0.id == id }
      case .card(let id): cards.contains { $0.id == id }
      case nil: false
      }
    }
    if !valid(source) || (payCard && source?.cardId != nil) { source = nil }
    if !valid(target) || (payCard ? target?.cardId == nil : target?.cardId != nil) { target = nil }
    loading = false
  }

  @ViewBuilder private func legPicker(source isSource: Bool) -> some View {
    // Pay: source accounts, target cards. Transfer: source any, target accounts.
    let showAccounts = payCard ? isSource : true
    let showCards = payCard ? !isSource : isSource
    SearchablePicker(
      title: L(isSource ? (payCard ? "transactionAccount" : "transferSourceAccount")
        : (payCard ? "transactionCard" : "transferTargetAccount")),
      sections: [
        (L("accounts"), showAccounts ? accounts.map { PickItem(id: "a:\($0.id)", name: $0.name) } : []),
        (L("cards"), showCards ? cards.map { PickItem(id: "c:\($0.id)", name: $0.name, badge: $0.type, isCard: true) } : []),
      ],
      selected: nil, emptyMessage: L("transferAccountSearchNoResults")
    ) { item in
      let id = String(item.id.dropFirst(2))
      let leg: WalletRepository.Leg = item.isCard ? .card(id) : .account(id)
      if isSource { source = leg } else { target = leg }
    }
  }

  private func save() async {
    showErrors = true
    guard let s = source, let t = target, s != t, amountError == nil, let value = AmountInput.parse(amount) else { return }
    saving = true
    let ok: Bool
    if let editing {
      ok = await model.perform("failed transfer update") {
        try await $0.updateTransfer(
          source: editing.source, target: editing.target, from: s, to: t, amount: value, at: date, ignore: ignore)
      }
    } else {
      ok = await model.perform("failed transfer") { try await $0.transfer(from: s, to: t, amount: value, at: date) }
    }
    saving = false
    if ok { dismiss() }
  }
}
