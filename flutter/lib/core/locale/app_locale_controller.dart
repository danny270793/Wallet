import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted UI language: follow device, or fixed English / Spanish.
enum AppLanguagePreference {
  system,
  en,
  es;

  static AppLanguagePreference fromStorage(String? raw) {
    switch (raw) {
      case 'en':
        return AppLanguagePreference.en;
      case 'es':
        return AppLanguagePreference.es;
      default:
        return AppLanguagePreference.system;
    }
  }

  String get storageValue => switch (this) {
    AppLanguagePreference.system => 'system',
    AppLanguagePreference.en => 'en',
    AppLanguagePreference.es => 'es',
  };

  /// `null` means use the device locale (resolved via [localeResolutionCallback]).
  Locale? get materialLocale => switch (this) {
    AppLanguagePreference.system => null,
    AppLanguagePreference.en => const Locale('en'),
    AppLanguagePreference.es => const Locale('es'),
  };
}

class AppLocaleController extends ChangeNotifier {
  AppLocaleController();

  static const _prefKey = 'app_language_preference';

  AppLanguagePreference _preference = AppLanguagePreference.system;

  AppLanguagePreference get preference => _preference;

  Locale? get materialAppLocale => _preference.materialLocale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _preference = AppLanguagePreference.fromStorage(prefs.getString(_prefKey));
    notifyListeners();
  }

  Future<void> setPreference(AppLanguagePreference value) async {
    if (_preference == value) return;
    _preference = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value.storageValue);
  }
}
