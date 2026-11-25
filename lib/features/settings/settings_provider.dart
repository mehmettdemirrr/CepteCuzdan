import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format/money.dart';

/// Kullanıcı tercihleri: tema ve tutar görünümü. SharedPreferences'ta
/// `theme_mode` ve `currency_style` anahtarlarıyla saklanır.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs)
    : _themeMode = _byName(
        ThemeMode.values,
        _prefs.getString(themeKey),
        ThemeMode.system,
      ),
      _currencyStyle = _byName(
        CurrencyStyle.values,
        _prefs.getString(currencyKey),
        CurrencyStyle.symbol,
      );

  static const themeKey = 'theme_mode';
  static const currencyKey = currencyStylePrefKey;

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  CurrencyStyle _currencyStyle;

  ThemeMode get themeMode => _themeMode;
  CurrencyStyle get currencyStyle => _currencyStyle;

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    notifyListeners();
    await _prefs.setString(themeKey, m.name);
  }

  Future<void> setCurrencyStyle(CurrencyStyle s) async {
    _currencyStyle = s;
    notifyListeners();
    await _prefs.setString(currencyKey, s.name);
  }

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
