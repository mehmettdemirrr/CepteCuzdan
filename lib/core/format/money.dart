import 'package:intl/intl.dart';

import '../models/enums.dart';

/// Tutarın ekranda nasıl yazılacağı: `₺1.234,50` ya da `1.234,50 TL`.
enum CurrencyStyle { symbol, code }

/// Tutar görünümü tercihinin SharedPreferences anahtarı.
const currencyStylePrefKey = 'currency_style';

/// Kayıtlı tercihi okur; yoksa ya da bozuksa `symbol`.
CurrencyStyle currencyStyleFromName(String? name) {
  for (final s in CurrencyStyle.values) {
    if (s.name == name) return s;
  }
  return CurrencyStyle.symbol;
}

final _number = NumberFormat('#,##0.00', 'tr_TR');

/// Kuruş cinsinden tutarı Türkçe biçimde yazar.
String formatKurus(int kurus, {CurrencyStyle style = CurrencyStyle.symbol}) {
  final sign = kurus < 0 ? '-' : '';
  final body = _number.format(kurus.abs() / 100);
  return switch (style) {
    CurrencyStyle.symbol => '$sign₺$body',
    CurrencyStyle.code => '$sign$body TL',
  };
}

/// Form alanına yazmak için ₺ işaretsiz biçim: `1.234,50`.
/// [parseTlToKurus] ile geri okunabilir.
String formatKurusInput(int kurus) => _number.format(kurus / 100);

final _digits = RegExp(r'^\d+$');
final _grouped = RegExp(r'^\d{1,3}(\.\d{3})+$');
final _dotDecimal = RegExp(r'^(\d+)\.(\d{1,2})$');
final _fraction = RegExp(r'^\d{1,2}$');

/// Kullanıcının yazdığı TL tutarını kuruşa çevirir. Geçersizse ya da
/// sıfır/negatifse `null` döner.
///
/// Kurallar: `,` her zaman ondalıktır. Yalnızca `.` varsa ve ardından 1–2
/// hane geliyorsa `.` ondalık sayılır (Android sayısal klavyesi bazen sadece
/// nokta gösterir); aksi halde `.` binlik ayırıcıdır.
int? parseTlToKurus(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;

  String intPart;
  var frac = '';
  final commaCount = ','.allMatches(s).length;
  if (commaCount > 1) return null;
  if (commaCount == 1) {
    final parts = s.split(',');
    intPart = parts[0];
    frac = parts[1];
    if (!_fraction.hasMatch(frac)) return null;
  } else {
    final m = _dotDecimal.firstMatch(s);
    if (m != null) {
      intPart = m[1]!;
      frac = m[2]!;
    } else {
      intPart = s;
    }
  }

  if (_grouped.hasMatch(intPart)) {
    intPart = intPart.replaceAll('.', '');
  } else if (!_digits.hasMatch(intPart)) {
    return null;
  }

  // 12 haneden uzun tutarlar (999 milyar TL üstü) int taşmasına yol açar.
  if (intPart.length > 12) return null;
  final whole = int.tryParse(intPart);
  if (whole == null) return null;
  final kurus = whole * 100 + int.parse(frac.padRight(2, '0'));
  return kurus > 0 ? kurus : null;
}

/// Ondalıklı TL değerini (ör. Gemini'nin `320.00`'ı) kuruşa çevirir.
int tlToKurus(num tl) => (tl * 100).round();

/// Ekran okuyucunun söyleyeceği tutar: `150,00 lira gider`,
/// `5.000,00 lira gelir`, `eksi 500,00 lira`. "₺" ve "-" işaretleri TalkBack'te
/// anlaşılır okunmadığı için kelimeyle yazılır.
String spokenAmount(int kurus, {TxType? type}) {
  final body = '${_number.format(kurus.abs() / 100)} lira';
  return switch (type) {
    TxType.expense => '$body gider',
    TxType.income => '$body gelir',
    null => kurus < 0 ? 'eksi $body' : body,
  };
}
