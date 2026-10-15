import SwiftUI
import WalletCore

/// Localized string for [key] from the shared String Catalog.
func L(_ key: String, _ args: Any...) -> String {
  let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
  guard !args.isEmpty else { return format }
  return String(format: format, locale: L10n.locale, arguments: args.map { "\($0)" as NSString })
}

enum L10n {
  static let locale = Locale.current
}

enum Money {
  static let income = Color(red: 0x1B / 255, green: 0x87 / 255, blue: 0x36 / 255)
  /// Brighter green for the watch's black background.
  static let incomeOnDark = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)

  static func color(_ v: Double) -> Color {
    v > 0.0049 ? incomeOnDark : v < -0.0049 ? .red : .primary
  }

  static func text(_ v: Double) -> String {
    v.formatted(.number.precision(.fractionLength(2)).locale(L10n.locale))
  }
}

/// "‹ Oct 2026 ›" row at the top of a screen.
///
/// In the content, not the toolbar: two toolbar items in the corners made the
/// watchOS navigation bar assert during layout.
struct WatchMonthSwitcher: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    HStack {
      Button(L("previousMonth"), systemImage: "chevron.left") { Task { await model.shiftMonth(-1) } }
        .labelStyle(.iconOnly)
      Spacer()
      Text(model.month.watchMonth).font(.headline).monospacedDigit()
      Spacer()
      Button(L("nextMonth"), systemImage: "chevron.right") { Task { await model.shiftMonth(1) } }
        .labelStyle(.iconOnly)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.tint)
  }
}

extension Date {
  var watchMonth: String { formatted(.dateTime.month(.abbreviated).year().locale(L10n.locale)) }
}
