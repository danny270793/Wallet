import SwiftUI
import WalletCore

func L(_ key: String, _ args: Any...) -> String {
  let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
  guard !args.isEmpty else { return format }
  return String(format: format, locale: L10n.locale, arguments: args.map { "\($0)" as NSString })
}

enum L10n {
  static let locale = Locale.current
}

enum Money {
  static let income = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)

  static func color(_ v: Double) -> Color { v > 0.0049 ? income : v < -0.0049 ? .red : .primary }

  static func text(_ v: Double) -> String {
    v.formatted(.number.precision(.fractionLength(2)).locale(L10n.locale))
  }
}

/// ‹ October 2026 › — focusable buttons, so the remote can change the month.
struct TVMonthSwitcher: View {
  @Environment(TVModel.self) private var model

  var body: some View {
    HStack(spacing: 30) {
      Button(L("previousMonth"), systemImage: "chevron.left") { model.shiftMonth(-1) }
        .labelStyle(.iconOnly)
      Text(model.month.formatted(.dateTime.month(.wide).year().locale(L10n.locale)))
        .font(.title2.weight(.semibold)).monospacedDigit()
        .frame(minWidth: 420)
      Button(L("nextMonth"), systemImage: "chevron.right") { model.shiftMonth(1) }
        .labelStyle(.iconOnly)
    }
  }
}

/// A focusable card: lifts and shows the system highlight when focused,
/// which is how tvOS tells you where the remote is.
struct TVCard<Content: View>: View {
  var action: () -> Void = {}
  @ViewBuilder let content: Content

  var body: some View {
    Button(action: action) {
      content
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .buttonStyle(.card)
  }
}

/// Label above a big number, colored by sign.
struct TVStat: View {
  let label: String
  let value: Double
  var color: Color?
  var large = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.callout).foregroundStyle(.secondary)
      Text(Money.text(value))
        .font(large ? .system(size: 76, weight: .bold, design: .rounded) : .title2.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(color ?? Money.color(value))
        .lineLimit(1).minimumScaleFactor(0.5)
    }
    .accessibilityElement(children: .combine)
  }
}

extension CardType {
  var tint: Color {
    switch self {
    case .visa: .blue
    case .mastercard: .orange
    case .amex: .teal
    case .diners: .indigo
    case .discover: .pink
    case .other: .gray
    }
  }
}
