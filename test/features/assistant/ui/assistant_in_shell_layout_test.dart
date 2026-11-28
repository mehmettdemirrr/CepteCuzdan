// Asistan ekranı gerçek uygulama kabuğunda (AppShell: üst çubuk + alt
// gezinme + durum çubuğu), onay kartı ve hata bandıyla beş ekran durumunda
// taşmamalı.
import 'dart:io';

import 'package:cepte_cuzdan/app/shell.dart';
import 'package:cepte_cuzdan/core/repositories/chat_message_repository.dart';
import 'package:cepte_cuzdan/core/ui/app_theme.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/query/budget_query_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/assistant/ui/assistant_screen.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../fakes/fake_repositories.dart';

const _draftJson =
    '{"type":"expense","amount":320.0,"merchant":"Migros Ataşehir Şubesi",'
    '"date":"2026-11-26","category":"Bilinmeyen","items":['
    '{"name":"Süt","quantity":2,"price":60},{"name":"Ekmek","quantity":1,"price":20}]}';

class _Gemini implements GeminiClient {
  String response = _draftJson;
  Object? error;
  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    if (error case final e?) throw e;
    return response;
  }
}

class _Picker implements ReceiptImagePicker {
  @override
  Future<String?> pickImage(ReceiptImageSource source) async => null;
}

class _Ocr implements TextOcrEngine {
  @override
  Future<String> recognizeText(String imagePath) async => '';
}

class _Storage implements ReceiptImageStorage {
  @override
  Future<String> copyToPermanentStorage(String sourcePath) async => sourcePath;
  @override
  Future<void> deleteReceipt(String path) async {}
  @override
  Future<void> deleteAllReceipts() async {}
  @override
  Future<void> deleteOrphanReceipts(Set<String> activePaths) async {}
}

class _Env {
  final repos = FakeRepos();
  final gemini = _Gemini();
  late final txs = TransactionProvider(repos.txs);
  late final cats = CategoryProvider(repos.categories);
  late AssistantController ctrl;

  Future<void> init() async {
    await cats.load();
    final draftService = ExpenseDraftService(gemini);
    ctrl = AssistantController(
      chats: repos.chats,
      transactions: txs,
      categories: cats,
      draftService: draftService,
      receiptPipeline: ReceiptDraftPipeline(
        scanService: ReceiptScanService(
          picker: _Picker(),
          ocrEngine: _Ocr(),
          storage: _Storage(),
        ),
        draftService: draftService,
      ),
      budgetQueryService: BudgetQueryService(
        transactions: repos.txs,
        categories: repos.categories,
      ),
      now: () => DateTime(2026, 11, 26),
    );
    await ctrl.loadHistory();
  }
}

Future<void> _pumpInShell(
  WidgetTester t,
  _Env env,
  Size size,
  double textScale,
) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: const EdgeInsets.only(top: 24), // durum çubuğu
        textScaler: TextScaler.linear(textScale),
      ),
      child: MultiProvider(
        providers: [
          Provider<ChatMessageRepository>.value(value: env.repos.chats),
          ChangeNotifierProvider.value(value: env.txs),
          ChangeNotifierProvider.value(value: env.cats),
          ChangeNotifierProvider.value(value: env.ctrl),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppShell(
            pages: [
              SizedBox.expand(),
              AssistantScreen(),
              SizedBox.expand(),
              SizedBox.expand(),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pump();
  await t.tap(find.text('Asistan').last);
  await t.pumpAndSettle();
}

void main() {
  const cases = <(String, Size, double)>[
    ('dikey 360x800', Size(360, 800), 1.0),
    ('küçük 320x568', Size(320, 568), 1.0),
    ('yatay 800x360', Size(800, 360), 1.0),
    ('geniş 1280x800', Size(1280, 800), 1.0),
    ('büyük yazı 2.0x', Size(360, 800), 2.0),
    ('yatay + büyük yazı 2.0x', Size(800, 360), 2.0),
  ];

  for (final (label, size, scale) in cases) {
    testWidgets('onay kartıyla taşma yok: $label', (t) async {
      final env = _Env();
      await t.runAsync(env.init);
      await env.ctrl.sendText('Migros 320 TL');
      await _pumpInShell(t, env, size, scale);
      expect(t.takeException(), isNull);
      expect(find.text('Kaydet'), findsWidgets);
    });

    testWidgets('onay kartı + hata bandıyla taşma yok: $label', (t) async {
      final env = _Env();
      await t.runAsync(env.init);
      await env.ctrl.sendText('Migros 320 TL');
      env.gemini.response = 'bozuk yanıt';
      await env.ctrl.sendText('Kahve 90');
      await _pumpInShell(t, env, size, scale);
      expect(t.takeException(), isNull);
      expect(find.text('Manuel ekle'), findsOneWidget);
    });

    // Uzun (çok satırlı) hata mesajında da eylem düğmeleri görünür kalmalı;
    // bandın kayan kısmında giriş çubuğunun altına düşmemeli.
    testWidgets('uzun hata mesajında Manuel ekle dokunulabilir: $label', (
      t,
    ) async {
      final env = _Env();
      await t.runAsync(env.init);
      env.gemini.error = const SocketException('No internet');
      await env.ctrl.sendText('Kahve 90');
      await _pumpInShell(t, env, size, scale);
      expect(t.takeException(), isNull);
      expect(find.text('Manuel ekle').hitTestable(), findsOneWidget);
      expect(
        find.byTooltip('Hata mesajını kapat').hitTestable(),
        findsOneWidget,
      );
    });
  }
}
