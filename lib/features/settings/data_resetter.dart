import 'package:shared_preferences/shared_preferences.dart';

import '../budget/budget_alert_service.dart';

/// Tüm işlemleri, bütçeleri, sohbet geçmişini ve kullanıcı kategorilerini
/// siler; varsayılan kategoriler ve ayarlar (tema, tutar görünümü) kalır.
/// Veriler silindikten sonra bütçe uyarı kayıtları da temizlenir, böylece bu
/// ayın uyarıları yeniden gelebilir. Uygulamada SQLite'ı, testlerde sahte
/// depoyu temizler.
class DataResetter {
  const DataResetter({required this.reset, required this.prefs});

  /// Veritabanını (ya da testte sahte depoyu) temizler.
  final Future<void> Function() reset;
  final SharedPreferences prefs;

  /// Veri silme başarısız olursa hata fırlatır ve uyarı kayıtlarına dokunmaz.
  Future<void> call() async {
    await reset();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(BudgetAlertService.keyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
