import 'package:cepte_cuzdan/core/db/app_database.dart';
import 'package:cepte_cuzdan/core/db/sqlite_budget_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_category_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_chat_message_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_transaction_repository.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/category.dart';
import 'package:cepte_cuzdan/core/models/chat_message.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_db.dart';

void main() {
  late Database db;
  setUp(() async => db = await openTestDb());
  tearDown(() => db.close());

  test('resetAll işlemleri, bütçeleri, sohbeti ve kullanıcı kategorilerini siler; varsayılanları korur', () async {
    final txs = SqliteTransactionRepository(db);
    final cats = SqliteCategoryRepository(db);
    final kahve = await cats.add(
      const Category(
        name: 'Kahve',
        type: TxType.expense,
        color: 0,
        icon: 'local_cafe',
      ),
    );
    await txs.add(
      TransactionRecord(
        type: TxType.expense,
        amount: 5000,
        categoryId: kahve,
        date: DateTime(2026, 11, 25),
        source: TxSource.receipt,
        createdAt: DateTime(2026, 11, 25),
      ),
      items: const [ReceiptItem(name: 'Latte', price: 5000)],
    );
    await SqliteBudgetRepository(db)
        .upsert(const Budget(month: '2026-11', limitAmount: 100));
    await SqliteChatMessageRepository(db).add(
      ChatMessage(
        role: ChatRole.user,
        content: 'merhaba',
        createdAt: DateTime(2026),
      ),
    );

    await AppDatabase.resetAll(db);

    for (final table in [
      'transactions',
      'receipt_items',
      'budgets',
      'chat_messages',
    ]) {
      final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
      expect(rows.single['n'], 0, reason: table);
    }
    final all = await cats.all();
    expect(all, hasLength(9));
    expect(all.every((c) => c.isDefault), isTrue);
  });
}
