import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/db/sqlite_budget_repository.dart';
import '../core/db/sqlite_category_repository.dart';
import '../core/db/sqlite_chat_message_repository.dart';
import '../core/db/sqlite_transaction_repository.dart';
import '../core/repositories/budget_repository.dart';
import '../core/repositories/category_repository.dart';
import '../core/repositories/chat_message_repository.dart';
import '../core/repositories/transaction_repository.dart';
import '../features/transactions/category_provider.dart';
import '../features/transactions/transaction_provider.dart';

/// Uygulamanın dış bağımlılıkları. Uygulamada SQLite, testlerde sahte
/// repository'ler verilir; provider ağacı ikisinde de aynıdır.
class AppDeps {
  AppDeps({
    required this.txs,
    required this.categories,
    required this.budgets,
    required this.chats,
    required this.prefs,
  });

  factory AppDeps.sqlite(Database db, SharedPreferences prefs) => AppDeps(
    txs: SqliteTransactionRepository(db),
    categories: SqliteCategoryRepository(db),
    budgets: SqliteBudgetRepository(db),
    chats: SqliteChatMessageRepository(db),
    prefs: prefs,
  );

  final TransactionRepository txs;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  final ChatMessageRepository chats;
  final SharedPreferences prefs;
}

/// Tüm repository ve provider'ları [child]'ın üstüne kurar.
/// Berkay: asistan provider'larını listenin sonuna ekle.
Widget buildProviders({required AppDeps deps, required Widget child}) {
  return MultiProvider(
    providers: [
      Provider<TransactionRepository>.value(value: deps.txs),
      Provider<CategoryRepository>.value(value: deps.categories),
      Provider<BudgetRepository>.value(value: deps.budgets),
      Provider<ChatMessageRepository>.value(value: deps.chats),
      Provider<SharedPreferences>.value(value: deps.prefs),
      ChangeNotifierProvider(create: (_) => TransactionProvider(deps.txs)),
      ChangeNotifierProvider(
        lazy: false, // kategoriler açılışta yüklensin
        create: (_) => CategoryProvider(deps.categories)..load(),
      ),
    ],
    child: child,
  );
}
