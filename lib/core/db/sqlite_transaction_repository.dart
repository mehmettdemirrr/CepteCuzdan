import 'package:sqflite/sqflite.dart';

import '../format/dates.dart';
import '../models/enums.dart';
import '../models/period_summary.dart';
import '../models/receipt_item.dart';
import '../models/transaction_record.dart';
import '../repositories/transaction_repository.dart';

class SqliteTransactionRepository implements TransactionRepository {
  SqliteTransactionRepository(this._db);
  final Database _db;

  @override
  Future<int> add(TransactionRecord tx, {List<ReceiptItem> items = const []}) {
    return _db.transaction((txn) async {
      final cat = await txn.query(
        'categories',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [tx.categoryId],
      );
      if (cat.isEmpty) {
        throw ArgumentError.value(tx.categoryId, 'categoryId', 'kategori yok');
      }
      final id = await txn.insert('transactions', tx.toMap()..remove('id'));
      for (final item in items) {
        await txn.insert(
          'receipt_items',
          (item.toMap()..remove('id'))..['transaction_id'] = id,
        );
      }
      return id;
    });
  }

  @override
  Future<void> update(TransactionRecord tx) async {
    await _db.update(
      'transactions',
      tx.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<TransactionRecord?> getById(int id) async {
    final rows = await _db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : TransactionRecord.fromMap(rows.single);
  }

  @override
  Future<List<TransactionRecord>> query({
    DateRange? range,
    int? categoryId,
    TxType? type,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (range != null) {
      where.add('date BETWEEN ? AND ?');
      args.addAll([toDbDate(range.start), toDbDate(range.end)]);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type.name);
    }
    final rows = await _db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(TransactionRecord.fromMap).toList();
  }

  @override
  Future<List<ReceiptItem>> itemsOf(int transactionId) async {
    final rows = await _db.query(
      'receipt_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id',
    );
    return rows.map(ReceiptItem.fromMap).toList();
  }

  @override
  Future<PeriodSummary> summarize(DateRange range) async {
    final rows = await _db.rawQuery(
      'SELECT type, category_id, SUM(amount) AS total FROM transactions '
      'WHERE date BETWEEN ? AND ? GROUP BY type, category_id',
      [toDbDate(range.start), toDbDate(range.end)],
    );
    var income = 0, expense = 0;
    final byIncome = <int, int>{}, byExpense = <int, int>{};
    for (final r in rows) {
      final total = r['total'] as int;
      final categoryId = r['category_id'] as int;
      if (r['type'] == TxType.income.name) {
        income += total;
        byIncome[categoryId] = total;
      } else {
        expense += total;
        byExpense[categoryId] = total;
      }
    }
    return PeriodSummary(
      incomeTotal: income,
      expenseTotal: expense,
      expenseByCategory: byExpense,
      incomeByCategory: byIncome,
    );
  }
}
