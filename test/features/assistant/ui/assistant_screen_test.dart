import 'package:cepte_cuzdan/app/providers.dart';
import 'package:cepte_cuzdan/core/models/chat_message.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/repositories/chat_message_repository.dart';
import 'package:cepte_cuzdan/core/ui/app_theme.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
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

import '../../../helpers/pump_app.dart';

class _StubGeminiClient implements GeminiClient {
  _StubGeminiClient({this.response = _okJson});

  String response;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async => response;
}

class _StubPicker implements ReceiptImagePicker {
  @override
  Future<String?> pickImage(ReceiptImageSource source) async => null;
}

class _StubOcr implements TextOcrEngine {
  @override
  Future<String> recognizeText(String imagePath) async => '';
}

class _StubStorage implements ReceiptImageStorage {
  @override
  Future<String> copyToPermanentStorage(String sourcePath) async =>
      '/app/receipts/f.jpg';

  @override
  Future<void> deleteReceipt(String path) async {}

  @override
  Future<void> deleteAllReceipts() async {}
}

const _okJson = '''
{
  "type": "expense",
  "amount": 150.0,
  "merchant": "Taksi",
  "date": "2026-11-26",
  "category": "Ulaşım",
  "items": []
}
''';

Widget _withFakeAssistantController(_StubGeminiClient gemini, Widget child) {
  return Builder(
    builder: (context) {
      final draftService = ExpenseDraftService(gemini);
      return ChangeNotifierProvider<AssistantController>(
        create: (_) => AssistantController(
          chats: context.read(),
          transactions: context.read<TransactionProvider>(),
          categories: context.read<CategoryProvider>(),
          draftService: draftService,
          receiptPipeline: ReceiptDraftPipeline(
            scanService: ReceiptScanService(
              picker: _StubPicker(),
              ocrEngine: _StubOcr(),
              storage: _StubStorage(),
            ),
            draftService: draftService,
          ),
          now: () => DateTime(2026, 11, 26),
        )..loadHistory(),
        child: child,
      );
    },
  );
}

void main() {
  testWidgets(
    'mesaj gönderilir, geçmişte görünür ve rol Semantics ile okunur',
    (t) async {
      final deps = TestDeps();
      final gemini = _StubGeminiClient();

      await pumpApp(
        t,
        _withFakeAssistantController(gemini, const AssistantScreen()),
        deps: deps,
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'Taksiye 150 lira verdim');
      await t.pump();
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();

      expect(find.text('Taksiye 150 lira verdim'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Sen: Taksiye 150 lira verdim')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'^Asistan: ')), findsOneWidget);
    },
  );

  testWidgets(
    'hata durumunda Türkçe mesaj, Tekrar dene ve Manuel ekle görünür',
    (t) async {
      final deps = TestDeps();
      final gemini = _StubGeminiClient(response: 'bozuk json');

      await pumpApp(
        t,
        _withFakeAssistantController(gemini, const AssistantScreen()),
        deps: deps,
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'Kahve 90 TL');
      await t.pump();
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();

      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('Manuel ekle'), findsOneWidget);
    },
  );

  testWidgets(
    'ikon düğmelerinde tooltip, >=48dp dokunma alanı ve mikrofon yakında',
    (t) async {
      final deps = TestDeps();
      await pumpApp(
        t,
        _withFakeAssistantController(
          _StubGeminiClient(),
          const AssistantScreen(),
        ),
        deps: deps,
      );
      await t.pumpAndSettle();

      final cameraBtn = find.byTooltip('Fiş fotoğrafı ekle');
      final micBtn = find.byTooltip('Sesli komut (yakında)');
      final sendBtn = find.byTooltip('Gönder');

      expect(cameraBtn, findsOneWidget);
      expect(micBtn, findsOneWidget);
      expect(sendBtn, findsOneWidget);

      for (final finder in [cameraBtn, micBtn, sendBtn]) {
        final size = t.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }

      // Mikrofon henüz kapalı.
      final micIconButton = find.ancestor(
        of: micBtn,
        matching: find.byType(IconButton),
      );
      final micWidget = t.widget<IconButton>(micIconButton);
      expect(micWidget.onPressed, isNull);

      // Kamera düğmesi alt sayfayı açar.
      await t.tap(cameraBtn);
      await t.pumpAndSettle();
      expect(find.text('Kamera ile çek'), findsOneWidget);
      expect(find.text('Galeriden seç'), findsOneWidget);
    },
  );

  group('5 ekran durumu ve koyu tema taşma kontrolü', () {
    final cases = <(String, Size, double, Brightness)>[
      ('dikey 360x800', const Size(360, 800), 1.0, Brightness.light),
      ('küçük 320x568', const Size(320, 568), 1.0, Brightness.light),
      ('yatay 800x360', const Size(800, 360), 1.0, Brightness.light),
      ('geniş 1280x800', const Size(1280, 800), 1.0, Brightness.dark),
      ('büyük yazı 2.0x', const Size(360, 800), 2.0, Brightness.light),
    ];

    for (final (label, logicalSize, textScale, brightness) in cases) {
      testWidgets('taşma yok: $label', (t) async {
        final deps = TestDeps();
        await deps.chats.add(
          ChatMessage(
            role: ChatRole.user,
            content: 'Migros 320 TL',
            createdAt: DateTime(2026, 11, 26),
          ),
        );
        await deps.chats.add(
          ChatMessage(
            role: ChatRole.assistant,
            content: 'Taslak hazır: ₺320,00 · Market (Gider)',
            createdAt: DateTime(2026, 11, 26),
          ),
        );

        t.view.physicalSize = logicalSize * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);

        await initializeDateFormatting('tr_TR');
        Intl.defaultLocale = 'tr_TR';

        final appDeps = await deps.build();
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: logicalSize,
              padding: logicalSize.width > logicalSize.height
                  ? const EdgeInsets.only(left: 48, right: 24)
                  : EdgeInsets.zero,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark()
                  : AppTheme.light(),
              locale: const Locale('tr', 'TR'),
              supportedLocales: const [Locale('tr', 'TR')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: _buildWithDeps(appDeps, _StubGeminiClient()),
            ),
          ),
        );
        await t.pumpAndSettle();

        expect(t.takeException(), isNull);
        expect(find.text('Migros 320 TL'), findsOneWidget);

        // Onay kartı açıkken de 5 ekran durumunda (özellikle 800x360 yatay ve 320x568 küçük)
        // taşma olmamalı ve giriş alanı ekranda kalmalıdır.
        await t.enterText(find.byType(TextField), 'Taksi 150 TL');
        await t.pump();
        await t.tap(find.byTooltip('Gönder'));
        await t.pumpAndSettle();

        expect(t.takeException(), isNull);
        expect(find.text('Kaydet'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });
    }
  });
}

Widget _buildWithDeps(AppDeps appDeps, _StubGeminiClient gemini) {
  return MultiProvider(
    providers: [
      Provider<ChatMessageRepository>.value(value: appDeps.chats),
      ChangeNotifierProvider(create: (_) => TransactionProvider(appDeps.txs)),
      ChangeNotifierProvider(
        lazy: false,
        create: (_) => CategoryProvider(appDeps.categories)..load(),
      ),
    ],
    child: _withFakeAssistantController(gemini, const AssistantScreen()),
  );
}
