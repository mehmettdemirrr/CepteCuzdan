import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/default_categories.dart';

/// Uygulamanın tek SQLite veritabanı. Şema raporun "Veritabanı Tasarımı"
/// bölümündeki beş tablodur; tutarlar kuruş cinsinden INTEGER.
class AppDatabase {
  AppDatabase._();

  static const fileName = 'ceptecuzdan.db';
  static const version = 1;

  /// [factory] verilmezse sqflite'ın platform fabrikası kullanılır. Testler
  /// `databaseFactoryFfi` ve `inMemoryDatabasePath` geçer.
  static Future<Database> open({
    DatabaseFactory? factory,
    String path = fileName,
    bool singleInstance = true,
  }) async {
    final f = factory ?? databaseFactory;
    final fullPath = path == inMemoryDatabasePath || p.isAbsolute(path)
        ? path
        : p.join(await f.getDatabasesPath(), path);
    return f.openDatabase(
      fullPath,
      options: OpenDatabaseOptions(
        version: version,
        singleInstance: singleInstance,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
      ),
    );
  }

  /// İşlemleri, fiş kalemlerini, bütçeleri, sohbet geçmişini ve kullanıcının
  /// eklediği kategorileri siler. Varsayılan kategoriler kalır.
  static Future<void> resetAll(Database db) {
    return db.transaction((txn) async {
      await txn.delete('chat_messages');
      await txn.delete('receipt_items');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('categories', where: 'is_default = 0');
    });
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    for (final sql in _schema) {
      batch.execute(sql);
    }
    for (final c in defaultCategories) {
      batch.insert('categories', c.toMap());
    }
    await batch.commit(noResult: true);
  }

  static const _schema = [
    '''
CREATE TABLE categories(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('income','expense')),
  color INTEGER NOT NULL,
  icon TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  UNIQUE(name, type)
)''',
    '''
CREATE TABLE transactions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK(type IN ('income','expense')),
  amount INTEGER NOT NULL CHECK(amount > 0),
  category_id INTEGER NOT NULL REFERENCES categories(id),
  date TEXT NOT NULL,
  merchant TEXT,
  note TEXT,
  source TEXT NOT NULL CHECK(source IN ('manual','receipt','voice','chat')),
  receipt_path TEXT,
  created_at TEXT NOT NULL
)''',
    'CREATE INDEX idx_transactions_date ON transactions(date)',
    'CREATE INDEX idx_transactions_category ON transactions(category_id)',
    '''
CREATE TABLE receipt_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  quantity REAL NOT NULL DEFAULT 1,
  price INTEGER NOT NULL
)''',
    '''
CREATE TABLE budgets(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
  month TEXT NOT NULL,
  limit_amount INTEGER NOT NULL CHECK(limit_amount > 0)
)''',
    '''
CREATE TABLE chat_messages(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  role TEXT NOT NULL CHECK(role IN ('user','assistant')),
  content TEXT NOT NULL,
  transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL
)''',
  ];
}
