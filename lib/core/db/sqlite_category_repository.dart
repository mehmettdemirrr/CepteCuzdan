import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/default_categories.dart';
import '../models/enums.dart';
import '../repositories/category_repository.dart';

class SqliteCategoryRepository implements CategoryRepository {
  SqliteCategoryRepository(this._db);
  final Database _db;

  @override
  Future<List<Category>> all({TxType? type}) async {
    final rows = await _db.query(
      'categories',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type.name],
      orderBy: 'id',
    );
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<Category?> findByName(String name, TxType type) async {
    final ofType = await all(type: type);
    return ofType.where((c) => c.name == name).firstOrNull ??
        ofType
            .where((c) => c.name.toLowerCase() == name.toLowerCase())
            .firstOrNull;
  }

  @override
  Future<int> add(Category c) async {
    try {
      return await _db.insert('categories', c.toMap()..remove('id'));
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateCategoryException(c.name);
      rethrow;
    }
  }

  @override
  Future<void> update(Category c) async {
    try {
      await _db.update(
        'categories',
        c.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [c.id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateCategoryException(c.name);
      rethrow;
    }
  }

  @override
  Future<void> delete(int id) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      final c = Category.fromMap(rows.single);
      if (c.isDefault) {
        throw StateError('Varsayılan kategori silinemez: ${c.name}');
      }
      final fallback = await txn.query(
        'categories',
        columns: ['id'],
        where: 'is_default = 1 AND type = ? AND name = ?',
        whereArgs: [c.type.name, fallbackCategoryName],
      );
      await txn.update(
        'transactions',
        {'category_id': fallback.single['id']},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      // Bütçe limitleri ON DELETE CASCADE ile silinir.
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }
}
