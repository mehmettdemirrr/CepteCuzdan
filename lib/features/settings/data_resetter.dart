/// Tüm işlemleri, bütçeleri, sohbet geçmişini ve kullanıcı kategorilerini
/// siler; varsayılan kategoriler ve ayarlar kalır. Uygulamada SQLite'ı,
/// testlerde sahte depoyu temizler.
class DataResetter {
  const DataResetter(this._reset);

  final Future<void> Function() _reset;

  Future<void> call() => _reset();
}
