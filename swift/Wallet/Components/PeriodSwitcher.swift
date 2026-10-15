import SwiftUI
import WalletCore

/// Toolbar month control: ‹ month › on one glass capsule; tap the title to jump.
struct MonthSwitcher: View {
  @Binding var month: Date
  @State private var picking = false

  var body: some View {
    HStack(spacing: 2) {
      Button(L("previousMonth"), systemImage: "chevron.left") { shift(-1) }
        .labelStyle(.iconOnly)
      Button {
        picking = true
      } label: {
        Text(Dates.monthYear(month))
          .font(.headline)
          .contentTransition(.numericText())
          .lineLimit(1)
          .frame(minWidth: 128)
      }
      .accessibilityHint(L("transactionsPickMonth"))
      Button(L("nextMonth"), systemImage: "chevron.right") { shift(1) }
        .labelStyle(.iconOnly)
    }
    .sheet(isPresented: $picking) {
      MonthYearPicker(month: $month)
        .presentationDetents([.height(360)])
    }
  }

  private func shift(_ n: Int) {
    withAnimation(.snappy) { month = WalletCalendar.monthStart(month, offset: n) }
  }
}

/// Grid of months for a year, with year paging.
struct MonthYearPicker: View {
  @Binding var month: Date
  @Environment(\.dismiss) private var dismiss
  @State private var year: Int

  init(month: Binding<Date>) {
    _month = month
    _year = State(initialValue: WalletCalendar.year(month.wrappedValue))
  }

  private var symbols: [String] {
    var c = Calendar(identifier: .gregorian)
    c.locale = L10n.locale
    return c.shortStandaloneMonthSymbols
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        HStack {
          Button(L("transactionsPickPreviousYear"), systemImage: "chevron.left") { year -= 1 }
            .labelStyle(.iconOnly)
          Spacer()
          Text(String(year)).font(.title3.bold()).monospacedDigit()
          Spacer()
          Button(L("transactionsPickNextYear"), systemImage: "chevron.right") { year += 1 }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.glass)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
          ForEach(1...12, id: \.self) { m in
            let selected = WalletCalendar.year(month) == year && WalletCalendar.month(month) == m
            Button {
              month = WalletCalendar.date(year, m)
              dismiss()
            } label: {
              Text(symbols[m - 1].capitalized).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(selected ? AnyPrimitiveButtonStyle(.glassProminent) : AnyPrimitiveButtonStyle(.glass))
          }
        }
      }
      .padding()
      .navigationTitle(L("transactionsPickMonth"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("today")) {
            month = WalletCalendar.startOfMonth(.now)
            dismiss()
          }
        }
        ToolbarItem(placement: .topBarTrailing) { Button(role: .close) { dismiss() } }
      }
    }
  }
}

/// Toolbar year control for the yearly view.
struct YearSwitcher: View {
  @Binding var year: Int

  var body: some View {
    HStack(spacing: 2) {
      Button(L("previousYear"), systemImage: "chevron.left") { withAnimation(.snappy) { year -= 1 } }
        .labelStyle(.iconOnly)
      Text(String(year))
        .font(.headline).monospacedDigit()
        .contentTransition(.numericText())
        .frame(minWidth: 64)
      Button(L("nextYear"), systemImage: "chevron.right") { withAnimation(.snappy) { year += 1 } }
        .labelStyle(.iconOnly)
    }
  }
}

/// Type-erased button style so selected/unselected glass styles can switch.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
  private let make: (Configuration) -> AnyView
  init<S: PrimitiveButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
  func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
