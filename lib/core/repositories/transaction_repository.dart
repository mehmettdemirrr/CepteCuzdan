import '../format/dates.dart';
import '../models/enums.dart';
import '../models/period_summary.dart';
import '../models/receipt_item.dart';
import '../models/transaction_record.dart';

/// Gelir/gider kayıtları. Ekranlar bunu doğrudan değil,
/// `TransactionProvider` üzerinden kullanır.
abstract class TransactionRepository {
  /// İşlemi ve varsa fiş kalemlerini tek DB transaction'ında kaydeder,
  /// yeni işlemin id'sini döner. Kalemlerin `transactionId`'si yok sayılır.
  Future<int> add(TransactionRecord tx, {List<ReceiptItem> items = const []});

  Future<void> update(TransactionRecord tx);

  /// İşlemi siler; fiş kalemleri de silinir, bağlı sohbet mesajının
  /// `transactionId`'si null olur.
  Future<void> delete(int id);

  Future<TransactionRecord?> getById(int id);

  /// Filtrelere uyan işlemler; en yeni tarih önce (eşitlikte en son eklenen).
  /// `range` iki ucu da dahil eder.
  Future<List<TransactionRecord>> query({
    DateRange? range,
    int? categoryId,
    TxType? type,
    int? limit,
  });

  Future<List<ReceiptItem>> itemsOf(int transactionId);

  /// Aralıktaki gelir/gider toplamları ve kategori kırılımı (tek sorgu).
  Future<PeriodSummary> summarize(DateRange range);
}
