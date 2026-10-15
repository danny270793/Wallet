import LocalAuthentication
import SwiftUI

/// Persisted UI language. Same `UserDefaults` values as the Flutter app's keys.
enum AppLanguage: String, CaseIterable, Identifiable {
  case system, en, es
  var id: String { rawValue }
  var code: String? { self == .system ? nil : rawValue }
  var label: String {
    switch self {
    case .system: L("settingsLanguageSystem")
    case .en: L("settingsLanguageEnglish")
    case .es: L("settingsLanguageSpanish")
    }
  }
}

enum AppTheme: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
  var label: String {
    switch self {
    case .system: L("settingsThemeSystem")
    case .light: L("settingsThemeLight")
    case .dark: L("settingsThemeDark")
    }
  }
}

@MainActor @Observable
final class Preferences {
  private let defaults = UserDefaults.standard

  var language: AppLanguage {
    didSet {
      defaults.set(language.rawValue, forKey: "app_language_preference")
      L10n.apply(language)
    }
  }

  var theme: AppTheme {
    didSet { defaults.set(theme.rawValue, forKey: "app_theme_preference") }
  }

  var biometricUnlock: Bool {
    didSet { defaults.set(biometricUnlock, forKey: "app_biometric_unlock_enabled") }
  }

  init() {
    language = AppLanguage(rawValue: defaults.string(forKey: "app_language_preference") ?? "") ?? .system
    theme = AppTheme(rawValue: defaults.string(forKey: "app_theme_preference") ?? "") ?? .system
    biometricUnlock = defaults.bool(forKey: "app_biometric_unlock_enabled")
    L10n.apply(language)
  }

  /// Device has an enrolled biometric (Face ID / Touch ID).
  var biometricAvailable: Bool {
    LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
  }

  func authenticate(reason: String) async -> Bool {
    let ctx = LAContext()
    return (try? await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) ?? false
  }
}
