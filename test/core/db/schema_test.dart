import 'dart:io';

import 'package:cepte_cuzdan/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_db.dart';

void main() {
  late Database db;
  setUp(() async => db = await openTestDb());
  tearDown(() => db.close());

  test('açılışta 5 tablo ve 2 indeks oluşur', () async {
    final rows = await db.rawQuery(
      "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
    );
    final tables = {
      for (final r in rows)
        if (r['type'] == 'table') r['name'],
    };
    final indexes = {
      for (final r in rows)
        if (r['type'] == 'index') r['name'],
    };
    expect(
      tables,
      containsAll([
        'categories',
        'transactions',
        'receipt_items',
        'budgets',
        'chat_messages',
      ]),
    );
    expect(
      indexes,
      containsAll(['idx_transactions_date', 'idx_transactions_category']),
    );
  });

  test('foreign key kısıtı açık', () async {
    final fk = await db.rawQuery('PRAGMA foreign_keys');
    expect(fk.single.values.single, 1);
    expect(
      () => db.insert('transactions', {
        'type': 'expense',
        'amount': 100,
        'category_id': 999,
        'date': '2026-11-25',
        'source': 'manual',
        'created_at': '2026-11-25T12:00:00.000',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('tutar 0 veya negatif olamaz, source listede olmalı', () async {
    Map<String, Object?> row(int amount, String source) => {
      'type': 'expense',
      'amount': amount,
      'category_id': 1,
      'date': '2026-11-25',
      'source': source,
      'created_at': '2026-11-25T12:00:00.000',
    };
    expect(
      () => db.insert('transactions', row(0, 'manual')),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => db.insert('transactions', row(100, 'email')),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'aynı ay için ikinci genel bütçe ya da kategori limiti eklenemez',
    () async {
      await db.insert('budgets', {'month': '2026-11', 'limit_amount': 100});
      expect(
        () => db.insert('budgets', {'month': '2026-11', 'limit_amount': 200}),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('budgets', {
        'category_id': 1,
        'month': '2026-11',
        'limit_amount': 100,
      });
      expect(
        () => db.insert('budgets', {
          'category_id': 1,
          'month': '2026-11',
          'limit_amount': 5,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('budgets', {
        'category_id': 1,
        'month': '2026-12',
        'limit_amount': 100,
      });
    },
  );

  test(
    'sürüm 1 veritabanı açılınca bütçe indeksi eklenir, veriler korunur',
    () async {
      final dir = await Directory.systemTemp.createTemp('cepte_');
      final path = '${dir.path}/v1.db';
      final v1 = await databaseFactoryFfi.openDatabase(path);
      await v1.execute('DROP INDEX IF EXISTS idx_budgets_month_category');
      await AppDatabase.createSchemaV1ForTest(v1);
      await v1.insert('budgets', {'month': '2026-11', 'limit_amount': 100});
      await v1.setVersion(1);
      await v1.close();

      final upgraded = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        singleInstance: false,
      );
      final idx = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'idx_budgets_month_category'",
      );
      expect(idx, hasLength(1));
      expect(await upgraded.query('budgets'), hasLength(1));
      expect(await upgraded.getVersion(), AppDatabase.version);
      await upgraded.close();
      await dir.delete(recursive: true);
    },
  );

  test('varsayılan kategoriler tek kez eklenir', () async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM categories WHERE is_default = 1',
    );
    expect(rows.single['n'], 9);
  });
}
