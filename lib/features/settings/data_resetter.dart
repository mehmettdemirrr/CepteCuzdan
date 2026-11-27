import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../budget/budget_alert_service.dart';

/// Tüm işlemleri, bütçeleri, sohbet geçmişini ve kullanıcı kategorilerini
/// siler; varsayılan kategoriler ve ayarlar (tema, tutar görünümü) kalır.
/// Veriler silindikten sonra bütçe uyarı kayıtları da temizlenir, böylece bu
/// ayın uyarıları yeniden gelebilir. Uygulamada SQLite'ı, testlerde sahte
/// depoyu temizler.
///
/// Sıfırlama başarıyla bittiğinde [resets] bir artar. Kendi verisini (ör.
/// fiş görselleri, bekleyen asistan taslağı) temizlemesi gereken modüller
/// bunu dinler; `TransactionProvider.revision` her kayıtta değiştiği için
/// sıfırlamayı anlamak için kullanılmamalıdır.
class DataResetter {
  DataResetter({required this.reset, required this.prefs});

  /// Veritabanını (ya da testte sahte depoyu) temizler.
  final Future<void> Function() reset;
  final SharedPreferences prefs;

  final ValueNotifier<int> _resets = ValueNotifier(0);

  /// Başarılı sıfırlama sayısı. Dinleyiciler çağrıldığında veriler ve bütçe
  /// uyarı kayıtları zaten silinmiştir.
  ValueListenable<int> get resets => _resets;

  /// Veri silme başarısız olursa hata fırlatır, uyarı kayıtlarına dokunmaz
  /// ve [resets] değişmez.
  Future<void> call() async {
    await reset();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(BudgetAlertService.keyPrefix)) {
        await prefs.remove(key);
      }
    }
    _resets.value++;
  }
}
