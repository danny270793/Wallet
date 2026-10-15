import SwiftUI
import WalletCore

/// Positive amounts read as income (green), negative as outcome (red).
enum Money {
  static let income = Color(red: 0x1B / 255, green: 0x87 / 255, blue: 0x36 / 255)
  static let endsNextMonth = Color(red: 0xB4 / 255, green: 0x53 / 255, blue: 0x09 / 255)

  static func color(_ v: Double, neutral: Color = .primary) -> Color {
    v > 0.0049 ? income : v < -0.0049 ? .red : neutral
  }

  static func text(_ v: Double) -> String {
    v.formatted(.number.precision(.fractionLength(2)).locale(L10n.locale))
  }
}

/// Signed amount with its income/outcome color and tabular digits.
struct AmountText: View {
  let value: Double
  var font: Font = .body.weight(.semibold)
  var neutral: Color = .primary
  var colored = true

  var body: some View {
    Text(Money.text(value))
      .font(font)
      .monospacedDigit()
      .foregroundStyle(colored ? Money.color(value, neutral: neutral) : neutral)
  }
}

enum Dates {
  static func monthYear(_ d: Date) -> String {
    d.formatted(.dateTime.month(.wide).year().locale(L10n.locale))
  }

  static func dayHeader(_ d: Date) -> String {
    let sameYear = WalletCalendar.year(d) == WalletCalendar.year(.now)
    return sameYear
      ? d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(L10n.locale))
      : d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year().locale(L10n.locale))
  }

  static func time(_ d: Date) -> String { d.formatted(.dateTime.hour().minute().locale(L10n.locale)) }
  static func short(_ d: Date) -> String { d.formatted(date: .numeric, time: .omitted) }
}

extension CardType {
  var label: String { self == .other ? L("cardTypeOther") : rawValue.capitalized }
  var symbol: String {
    switch self {
    case .visa, .mastercard, .discover: "creditcard.fill"
    case .amex: "creditcard.and.123"
    case .diners: "creditcard.circle.fill"
    case .other: "creditcard"
    }
  }
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

/// Small rounded-square brand badge for a card.
struct CardBadge: View {
  let type: CardType?
  var size: CGFloat = 30

  var body: some View {
    let t = type ?? .other
    Image(systemName: t.symbol)
      .font(.system(size: size * 0.5, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(t.tint.gradient, in: .rect(cornerRadius: size * 0.28))
      .accessibilityLabel(t.label)
  }
}

/// Colored SF Symbol tile used as a row icon.
struct IconTile: View {
  let symbol: String
  let color: Color
  var size: CGFloat = 30

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: size * 0.48, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(color.gradient, in: .rect(cornerRadius: size * 0.28))
  }
}
