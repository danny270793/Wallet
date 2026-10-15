import SwiftUI
import WalletCore

/// Item in a searchable picker.
struct PickItem: Identifiable, Hashable {
  let id: String
  let name: String
  var badge: CardType?
  var isCard = false
}

/// Searchable list sheet used for payment method, category and tag fields.
///
/// Rows swipe to edit or delete, and "+" creates a new item, so the
/// picker doubles as a quick manager (same as the Flutter pickers).
struct SearchablePicker: View {
  let title: String
  let sections: [(title: String?, items: [PickItem])]
  let selected: String?
  var emptyMessage = ""
  var onAdd: (() -> Void)?
  var onEdit: ((PickItem) -> Void)?
  var onDelete: ((PickItem) async -> Void)?
  /// Confirmation text for deleting an item.
  var deleteMessage: (PickItem) -> String = { L("confirmDeleteCategory", $0.name) }
  let onPick: (PickItem) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var pendingDelete: PickItem?

  var body: some View {
    NavigationStack {
      List {
        let filtered = sections.map { s in
          (s.title, s.items.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) })
        }
        if sections.allSatisfy({ $0.items.isEmpty }) {
          ContentUnavailableView(emptyMessage, systemImage: "tray").listRowBackground(Color.clear)
        } else if filtered.allSatisfy({ $0.1.isEmpty }) {
          ContentUnavailableView.search(text: query).listRowBackground(Color.clear)
        }
        ForEach(Array(filtered.enumerated()), id: \.offset) { _, section in
          if !section.1.isEmpty {
            Section(section.0 ?? "") {
              ForEach(section.1) { item in
                Button {
                  onPick(item)
                  dismiss()
                } label: {
                  HStack {
                    if item.isCard { CardBadge(type: item.badge, size: 26) }
                    Text(item.name).foregroundStyle(.primary)
                    Spacer()
                    if item.id == selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
                  }
                }
                .swipeActions(edge: .trailing) {
                  if onDelete != nil {
                    Button(L("delete"), systemImage: "trash", role: .destructive) { pendingDelete = item }
                  }
                  if let onEdit {
                    Button(L("edit"), systemImage: "pencil") { onEdit(item) }.tint(.blue)
                  }
                }
                .confirmationDialog(
                  L("delete"), isPresented: Binding(get: { pendingDelete?.id == item.id }, set: { if !$0 { pendingDelete = nil } }),
                  titleVisibility: .visible
                ) {
                  Button(L("delete"), role: .destructive) { Task { await onDelete?(item) } }
                } message: {
                  Text(deleteMessage(item))
                }
              }
            }
          }
        }
      }
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L("transferAccountSearch"))
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(role: .close) { dismiss() } }
        if let onAdd {
          ToolbarItem(placement: .primaryAction) { Button(L("addMenu"), systemImage: "plus", action: onAdd) }
        }
      }
    }
  }
}

/// Form row that shows a picked value and opens a picker on tap.
struct PickerField: View {
  let label: String
  let value: String?
  var badge: CardType?
  var loading = false
  var invalid = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(label).foregroundStyle(invalid ? .red : .primary)
        Spacer()
        if loading {
          ProgressView()
        } else {
          if let badge { CardBadge(type: badge, size: 22) }
          Text(value ?? L("none")).foregroundStyle(value == nil ? .tertiary : .secondary).lineLimit(1)
          Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.tertiary)
        }
      }
    }
    .disabled(loading)
  }
}

/// Day-of-month (1–30) menu, as cards and loans store it.
struct DayOfMonthPicker: View {
  let label: String
  @Binding var day: Int?

  var body: some View {
    Picker(label, selection: $day) {
      if day == nil { Text("—").tag(Int?.none) }
      ForEach(1...30, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
    }
  }
}

/// Decimal text field with the same filtering as the Flutter input formatter.
struct AmountField: View {
  let label: String
  @Binding var text: String
  var allowNegative = true
  var error: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      LabeledContent(label) {
        HStack(spacing: 6) {
          if allowNegative {
            Button {
              text = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
            } label: {
              Image(systemName: "plus.forwardslash.minus")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("±")
          }
          TextField("0.00", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .onChange(of: text) { _, v in
              let f = AmountInput.filter(v, allowNegative: allowNegative)
              if f != v { text = f }
            }
        }
      }
      if let error { Text(error).font(.caption).foregroundStyle(.red) }
    }
  }
}

/// Integer text field.
struct IntField: View {
  let label: String
  @Binding var text: String
  var disabled = false

  var body: some View {
    LabeledContent(label) {
      TextField("0", text: $text)
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
        .disabled(disabled)
        .onChange(of: text) { _, v in
          let f = AmountInput.digits(v)
          if f != v { text = f }
        }
    }
  }
}
