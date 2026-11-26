import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../../core/format/dates.dart';
import '../../core/models/enums.dart';
import '../../core/models/receipt_item.dart';
import '../../core/models/transaction_record.dart';
import '../../core/repositories/transaction_repository.dart';

/// İşlem yazmanın tek yolu. Manuel ekran ve Berkay'ın onay kartı kayıtları
/// buradan yazar; böylece her değişiklikte [revision] artar (Dashboard ve
/// Raporlar yenilenir) ve [onChanged] ile bütçe uyarısı kontrol edilir.
class TransactionProvider extends ChangeNotifier {
  TransactionProvider(this._repo, {this.onChanged});

  final TransactionRepository _repo;

  /// Değişen işlemin tarihiyle çağrılır (bütçe uyarı kontrolü için).
  final Future<void> Function(DateTime date)? onChanged;

  int _revision = 0;

  /// Her başarılı değişiklikte bir artar.
  int get revision => _revision;

  Future<int> add(
    TransactionRecord tx, {
    List<ReceiptItem> items = const [],
  }) async {
    final id = await _repo.add(tx, items: items);
    await _changed([tx.date]);
    return id;
  }

  Future<void> update(TransactionRecord tx) async {
    final old = tx.id == null ? null : await _repo.getById(tx.id!);
    await _repo.update(tx);
    final dates = [tx.date];
    if (old != null && monthKey(old.date) != monthKey(tx.date)) {
      dates.add(old.date);
    }
    await _changed(dates);
  }

  Future<void> delete(int id) async {
    final old = await _repo.getById(id);
    await _repo.delete(id);
    await _changed([if (old != null) old.date]);
  }

  Future<List<TransactionRecord>> query({
    DateRange? range,
    int? categoryId,
    TxType? type,
    int? limit,
  }) => _repo.query(
    range: range,
    categoryId: categoryId,
    type: type,
    limit: limit,
  );

  Future<List<ReceiptItem>> itemsOf(int transactionId) =>
      _repo.itemsOf(transactionId);

  /// Veri dışarıdan değiştiğinde (bütçe kaydı, veri sıfırlama) çağrılır.
  void markChanged() {
    _revision++;
    notifyListeners();
  }

  Future<void> _changed(List<DateTime> dates) async {
    _revision++;
    notifyListeners();
    final cb = onChanged;
    if (cb == null) return;
    // Kayıt veritabanına yazıldı; bütçe kontrolü hata verse bile işlem
    // başarılı sayılır (aksi halde kullanıcı tekrar kaydedip çift kayıt
    // oluşturur).
    for (final d in dates) {
      try {
        await cb(d);
      } catch (e) {
        debugPrint('Bütçe kontrolü başarısız: $e');
      }
    }
  }
}
