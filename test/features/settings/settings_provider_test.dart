import 'package:cepte_cuzdan/core/format/money.dart';
import 'package:cepte_cuzdan/features/settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('varsayılanlar: sistem teması ve ₺ simgesi', () async {
    final p = SettingsProvider(await SharedPreferences.getInstance());
    expect(p.themeMode, ThemeMode.system);
    expect(p.currencyStyle, CurrencyStyle.symbol);
  });

  test(
    'tema ve para birimi tercihi kalıcıdır ve dinleyicileri bilgilendirir',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final p = SettingsProvider(prefs);
      var notified = 0;
      p.addListener(() => notified++);
      await p.setThemeMode(ThemeMode.dark);
      await p.setCurrencyStyle(CurrencyStyle.code);
      expect(notified, 2);
      expect(prefs.getString('theme_mode'), 'dark');

      final again = SettingsProvider(prefs);
      expect(again.themeMode, ThemeMode.dark);
      expect(again.currencyStyle, CurrencyStyle.code);
    },
  );

  test('bozuk kayıtlı değer varsayılana düşer', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'mor',
      'currency_style': 'x',
    });
    final p = SettingsProvider(await SharedPreferences.getInstance());
    expect(p.themeMode, ThemeMode.system);
    expect(p.currencyStyle, CurrencyStyle.symbol);
  });
}
