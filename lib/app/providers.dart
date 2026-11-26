import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/db/app_database.dart';
import '../core/format/money.dart';
import '../core/db/sqlite_budget_repository.dart';
import '../core/db/sqlite_category_repository.dart';
import '../core/db/sqlite_chat_message_repository.dart';
import '../core/db/sqlite_transaction_repository.dart';
import '../core/repositories/budget_repository.dart';
import '../core/repositories/category_repository.dart';
import '../core/repositories/chat_message_repository.dart';
import '../core/repositories/transaction_repository.dart';
import '../features/assistant/services/gemini/expense_draft_service.dart';
import '../features/assistant/services/gemini/gemini_client.dart';
import '../features/assistant/services/ocr/ocr_service.dart';
import '../features/assistant/state/assistant_controller.dart';
import '../features/budget/alert_notifier.dart';
import '../features/budget/budget_alert_service.dart';
import '../features/budget/budget_provider.dart';
import '../features/dashboard/dashboard_provider.dart';
import '../features/reports/report_provider.dart';
import '../features/settings/data_resetter.dart';
import '../features/settings/settings_provider.dart';
import '../features/transactions/category_provider.dart';
import '../features/transactions/transaction_provider.dart';

/// Uygulamanın dış bağımlılıkları. Uygulamada SQLite ve gerçek bildirim,
/// testlerde sahteleri verilir; provider ağacı ikisinde de aynıdır.
class AppDeps {
  AppDeps({
    required this.txs,
    required this.categories,
    required this.budgets,
    required this.chats,
    required this.notifier,
    required this.prefs,
    required this.resetData,
  });

  factory AppDeps.sqlite(
    Database db,
    SharedPreferences prefs,
    AlertNotifier notifier,
  ) => AppDeps(
    txs: SqliteTransactionRepository(db),
    categories: SqliteCategoryRepository(db),
    budgets: SqliteBudgetRepository(db),
    chats: SqliteChatMessageRepository(db),
    notifier: notifier,
    prefs: prefs,
    resetData: () => AppDatabase.resetAll(db),
  );

  final TransactionRepository txs;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  final ChatMessageRepository chats;
  final AlertNotifier notifier;
  final SharedPreferences prefs;

  /// Verileri sıfırlar (bkz. [DataResetter]).
  final Future<void> Function() resetData;
}

/// Tüm repository, servis ve provider'ları [child]'ın üstüne kurar.
/// Berkay: asistan provider'larını listenin sonuna ekle.
Widget buildProviders({required AppDeps deps, required Widget child}) {
  final alerts = BudgetAlertService(
    budgets: deps.budgets,
    txs: deps.txs,
    categories: deps.categories,
    notifier: deps.notifier,
    prefs: deps.prefs,
  );
  return MultiProvider(
    providers: [
      Provider<TransactionRepository>.value(value: deps.txs),
      Provider<CategoryRepository>.value(value: deps.categories),
      Provider<BudgetRepository>.value(value: deps.budgets),
      Provider<ChatMessageRepository>.value(value: deps.chats),
      Provider<SharedPreferences>.value(value: deps.prefs),
      Provider<BudgetAlertService>.value(value: alerts),
      Provider<DataResetter>.value(
        value: DataResetter(reset: deps.resetData, prefs: deps.prefs),
      ),
      ChangeNotifierProvider(create: (_) => SettingsProvider(deps.prefs)),
      // AmountText bunu okur (çekirdek katman ayarlara bağımlı olmasın diye).
      ProxyProvider<SettingsProvider, CurrencyStyle>(
        update: (_, s, _) => s.currencyStyle,
      ),
      ChangeNotifierProvider(
        create: (_) =>
            TransactionProvider(deps.txs, onChanged: alerts.checkMonth),
      ),
      ChangeNotifierProvider(
        lazy: false, // kategoriler açılışta yüklensin
        create: (c) => CategoryProvider(
          deps.categories,
          onDeleted: c.read<TransactionProvider>().markChanged,
        )..load(),
      ),
      ChangeNotifierProvider(
        create: (c) => BudgetProvider(
          budgets: deps.budgets,
          alerts: alerts,
          events: c.read<TransactionProvider>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (c) => DashboardProvider(
          txs: deps.txs,
          budgets: deps.budgets,
          events: c.read<TransactionProvider>(),
        )..load(),
      ),
      ChangeNotifierProvider(
        create: (c) =>
            ReportProvider(txs: deps.txs, events: c.read<TransactionProvider>())
              ..load(),
      ),
      ChangeNotifierProvider(
        create: (c) {
          final draftService = ExpenseDraftService(FirebaseGeminiClient());
          final receiptPipeline = ReceiptDraftPipeline(
            scanService: ReceiptScanService(
              picker: DeviceReceiptImagePicker(),
              ocrEngine: const MlKitTextOcrEngine(),
              storage: LocalReceiptImageStorage(),
            ),
            draftService: draftService,
          );
          return AssistantController(
            chats: deps.chats,
            transactions: c.read<TransactionProvider>(),
            categories: c.read<CategoryProvider>(),
            draftService: draftService,
            receiptPipeline: receiptPipeline,
          )..loadHistory();
        },
      ),
    ],
    child: child,
  );
}
