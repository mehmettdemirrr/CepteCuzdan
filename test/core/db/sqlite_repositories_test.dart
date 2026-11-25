import 'package:cepte_cuzdan/core/db/sqlite_budget_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_category_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_chat_message_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_transaction_repository.dart';

import '../repositories/repository_contract.dart';
import 'test_db.dart';

void main() {
  runRepositoryContract('SQLite', () async {
    final db = await openTestDb();
    return RepoSet(
      txs: SqliteTransactionRepository(db),
      categories: SqliteCategoryRepository(db),
      budgets: SqliteBudgetRepository(db),
      chats: SqliteChatMessageRepository(db),
      close: db.close,
    );
  });
}
