import 'package:sqflite/sqflite.dart';

import '../models/budget.dart';
import '../repositories/budget_repository.dart';

class SqliteBudgetRepository implements BudgetRepository {
  SqliteBudgetRepository(this._db);
  final Database _db;

  @override
  Future<List<Budget>> forMonth(String month) async {
    final rows = await _db.query(
      'budgets',
      where: 'month = ?',
      whereArgs: [month],
      orderBy: 'id',
    );
    return rows.map(Budget.fromMap).toList();
  }

  @override
  Future<void> upsert(Budget b) {
    // SQLite UNIQUE kısıtı NULL'ları farklı saydığı için genel bütçe
    // (category_id NULL) tekilliği burada sağlanır.
    return _db.transaction((txn) async {
      final existing = await txn.query(
        'budgets',
        columns: ['id'],
        where: b.categoryId == null
            ? 'category_id IS NULL AND month = ?'
            : 'category_id = ? AND month = ?',
        whereArgs: [if (b.categoryId != null) b.categoryId, b.month],
      );
      if (existing.isEmpty) {
        await txn.insert('budgets', b.toMap()..remove('id'));
      } else {
        await txn.update(
          'budgets',
          {'limit_amount': b.limitAmount},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    });
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
