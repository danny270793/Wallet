import SwiftUI
import WalletCore
import WalletData

/// Quick expense: amount with the Digital Crown (or dictation), then payment
/// method, category and tag, prefilled from the last transaction.
struct QuickAddScreen: View {
  @Environment(WatchModel.self) private var model
  @State private var amount = 0.0
  @State private var note = ""
  @State private var leg: WalletRepository.Leg?
  @State private var categoryId: String?
  @State private var tagId: String?
  @State private var saving = false
  @State private var saved = false
  @State private var prefilled = false

  private var canSave: Bool { amount > 0 && leg != nil && categoryId != nil && tagId != nil && !saving }

  var body: some View {
    Form {
      Section {
        Text("-\(Money.text(amount))")
          .font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
          .foregroundStyle(amount > 0 ? .red : .secondary)
          .frame(maxWidth: .infinity)
          .focusable()
          .digitalCrownRotation(
            $amount, from: 0, through: 100_000, by: 0.5, sensitivity: .medium, isContinuous: false,
            isHapticFeedbackEnabled: true)
        TextField(L("accountDescription"), text: $note)
      }
      Section {
        Picker(L("transactionPaymentMethod"), selection: $leg) {
          Text(L("none")).tag(WalletRepository.Leg?.none)
          ForEach(model.accounts) { Text($0.name).tag(WalletRepository.Leg?.some(.account($0.id))) }
          ForEach(model.cards) { Text($0.name).tag(WalletRepository.Leg?.some(.card($0.id))) }
        }
        Picker(L("transactionCategory"), selection: $categoryId) {
          Text(L("none")).tag(String?.none)
          ForEach(model.categories) { Text($0.name).tag(String?.some($0.id)) }
        }
        Picker(L("transactionTag"), selection: $tagId) {
          Text(L("none")).tag(String?.none)
          ForEach(model.tags) { Text($0.name).tag(String?.some($0.id)) }
        }
      }
      Button {
        Task { await save() }
      } label: {
        Label(saved ? L("watchSaved") : L("save"), systemImage: saved ? "checkmark.circle.fill" : "checkmark")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.glassProminent)
      .disabled(!canSave)
    }
    .navigationTitle(L("watchQuickAdd"))
    .onAppear(perform: prefill)
    .onChange(of: model.transactions) { prefill() }
    .sensoryFeedback(.success, trigger: saved)
  }

  /// Defaults to the payment method, category and tag used last.
  private func prefill() {
    guard !prefilled, let last = model.lastUsed else { return }
    leg = WalletRepository.Leg(last)
    categoryId = last.categoryId
    tagId = last.tagId
    prefilled = true
  }

  private func save() async {
    guard canSave, let leg else { return }
    saving = true
    let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let ok = await model.save(
      WalletRepository.TransactionDraft(
        accountId: leg.accountId, cardId: leg.cardId, categoryId: categoryId, tagId: tagId,
        description: n.isEmpty ? nil : n, transactedAt: .now, value: -amount))
    saving = false
    if ok {
      saved = true
      amount = 0
      note = ""
      try? await Task.sleep(for: .seconds(1.5))
      saved = false
    }
  }
}
