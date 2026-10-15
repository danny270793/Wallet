import Foundation
import WalletCore

/// Looks up strings in the app's String Catalog (keys come from the Flutter
/// `.arb` files), honoring the in-app language override.
enum L10n {
  /// Bundle of the chosen language; `.main` follows the device.
  nonisolated(unsafe) static var bundle: Bundle = .main
  nonisolated(unsafe) static var locale: Locale = .current

  static func apply(_ language: AppLanguage) {
    if let code = language.code, let path = Bundle.main.path(forResource: code, ofType: "lproj"),
      let b = Bundle(path: path)
    {
      bundle = b
      locale = Locale(identifier: code)
    } else {
      bundle = .main
      locale = .current
    }
  }
}

/// Localized string for [key]; `args` fill `%1$@`, `%2$@`… in order.
func L(_ key: String, _ args: Any...) -> String {
  let format = L10n.bundle.localizedString(forKey: key, value: key, table: nil)
  guard !args.isEmpty else { return format }
  return String(format: format, locale: L10n.locale, arguments: args.map { "\($0)" as NSString })
}

/// SwiftUI also has a `Transaction`; in this app the name means a ledger row.
typealias Transaction = WalletCore.Transaction
typealias Category = WalletCore.Category
