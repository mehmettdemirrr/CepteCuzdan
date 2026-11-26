import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/period_summary.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/repositories/transaction_repository.dart';

/// Her çağrıda hata veren repository (yükleme hatası senaryoları için).
class FailingTransactionRepository implements TransactionRepository {
  Never _fail() => throw StateError('veritabanı okunamadı');

  @override
  Future<int> add(
    TransactionRecord tx, {
    List<ReceiptItem> items = const [],
  }) async => _fail();

  @override
  Future<void> update(TransactionRecord tx) async => _fail();

  @override
  Future<void> delete(int id) async => _fail();

  @override
  Future<TransactionRecord?> getById(int id) async => _fail();

  @override
  Future<List<TransactionRecord>> query({
    DateRange? range,
    int? categoryId,
    TxType? type,
    int? limit,
  }) async => _fail();

  @override
  Future<List<ReceiptItem>> itemsOf(int transactionId) async => _fail();

  @override
  Future<PeriodSummary> summarize(DateRange range) async => _fail();
}
