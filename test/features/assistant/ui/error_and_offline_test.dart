import 'dart:async';
import 'dart:io';

import 'package:cepte_cuzdan/app/shell.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/repositories/chat_message_repository.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/query/budget_query_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/speech/speech_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/assistant/ui/assistant_screen.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../helpers/pump_app.dart';

class _ThrowingGemini implements GeminiClient {
  _ThrowingGemini(this.error);

  Object error;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async => throw error;
}

class _ErrorPicker implements ReceiptImagePicker {
  _ErrorPicker({this.error});

  Object? error;

  @override
  Future<String?> pickImage(ReceiptImageSource source) async {
    if (error != null) throw error!;
    return null;
  }
}

class _FixedOcr implements TextOcrEngine {
  _FixedOcr(this.text);

  final String text;

  @override
  Future<String> recognizeText(String imagePath) async => text;
}

class _NoopStorage implements ReceiptImageStorage {
  @override
  Future<String> copyToPermanentStorage(String sourcePath) async => '';
  @override
  Future<void> deleteReceipt(String path) async {}
  @override
  Future<void> deleteAllReceipts() async {}

  @override
  Future<void> deleteOrphanReceipts(Set<String> activePaths) async {}
}

class _FailingSpeech implements SpeechService {
  _FailingSpeech(this.error);

  SpeechError error;

  @override
  bool get isListening => false;

  @override
  Future<SpeechError?> startListening({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(SpeechError error) onError,
  }) async => error;

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancelListening() async {}
}

Widget _wrapInShell({
  required _ThrowingGemini gemini,
  required _ErrorPicker picker,
  required _FixedOcr ocr,
  required _FailingSpeech speech,
  required TestDeps deps,
}) {
  return Builder(
    builder: (context) {
      final draftService = ExpenseDraftService(gemini);
      return ChangeNotifierProvider<AssistantController>(
        create: (_) => AssistantController(
          chats: context.read<ChatMessageRepository>(),
          transactions: context.read<TransactionProvider>(),
          categories: context.read<CategoryProvider>(),
          draftService: draftService,
          receiptPipeline: ReceiptDraftPipeline(
            scanService: ReceiptScanService(
              picker: picker,
              ocrEngine: ocr,
              storage: _NoopStorage(),
            ),
            draftService: draftService,
          ),
          speechService: speech,
          budgetQueryService: BudgetQueryService(
            transactions: deps.txs,
            categories: deps.categories,
          ),
          now: () => DateTime(2026, 11, 26),
        )..loadHistory(),
        child: const AppShell(
          pages: [
            ColoredBox(
              key: Key('home-tab'),
              color: Colors.white,
              child: SizedBox.expand(),
            ),
            AssistantScreen(),
            ColoredBox(
              key: Key('transactions-tab'),
              color: Colors.white,
              child: SizedBox.expand(),
            ),
            ColoredBox(
              key: Key('reports-tab'),
              color: Colors.white,
              child: SizedBox.expand(),
            ),
          ],
        ),
      );
    },
  );
}

void main() {
  testWidgets(
    'çevrimdışı (SocketException) hatasında Türkçe mesaj ve Manuel ekle sekme yönlendirmesi çalışır',
    (t) async {
      final deps = TestDeps();
      final gemini = _ThrowingGemini(const SocketException('No internet'));

      await pumpApp(
        t,
        _wrapInShell(
          gemini: gemini,
          picker: _ErrorPicker(),
          ocr: _FixedOcr(''),
          speech: _FailingSpeech(
            const SpeechError(
              code: SpeechErrorCode.serviceUnavailable,
              userMessage: 'Servis yok.',
            ),
          ),
          deps: deps,
        ),
        deps: deps,
      );
      await t.pumpAndSettle();

      // Asistan sekmesine geç.
      await t.tap(find.text('Asistan'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'Markete 100 TL verdim');
      await t.pump();
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();

      expect(find.textContaining('İnternet bağlantısı'), findsOneWidget);
      expect(find.text('Manuel ekle'), findsOneWidget);

      await t.tap(find.text('Manuel ekle'));
      await t.pumpAndSettle();

      expect(
        find.byKey(const Key('transactions-tab')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'kota aşımı ve zaman aşımı hataları Türkçe mesaj ve Manuel ekle gösterir',
    (t) async {
      final deps = TestDeps();
      final gemini = _ThrowingGemini(QuotaExceeded('quota'));

      await pumpApp(
        t,
        _wrapInShell(
          gemini: gemini,
          picker: _ErrorPicker(),
          ocr: _FixedOcr(''),
          speech: _FailingSpeech(
            const SpeechError(
              code: SpeechErrorCode.permissionDenied,
              userMessage: 'Mikrofon izni verilmedi.',
            ),
          ),
          deps: deps,
        ),
        deps: deps,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Asistan'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'Kahve 80 TL');
      await t.pump();
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();

      expect(find.textContaining('kota'), findsOneWidget);
      expect(find.text('Manuel ekle'), findsOneWidget);

      gemini.error = TimeoutException('timeout');
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();

      expect(find.textContaining('zaman aşımı'), findsOneWidget);
    },
  );

  testWidgets('çevrimdışıyken bütçe soruları yerelde hatasız yanıtlanır', (
    t,
  ) async {
    final deps = TestDeps();
    await deps.txs.add(
      TransactionRecord(
        type: TxType.expense,
        amount: 25000,
        categoryId: 1, // Market
        date: DateTime(2026, 11, 26),
        merchant: 'BİM',
        source: TxSource.manual,
        createdAt: DateTime(2026, 11, 26),
      ),
    );

    await pumpApp(
      t,
      _wrapInShell(
        gemini: _ThrowingGemini(const SocketException('Offline')),
        picker: _ErrorPicker(),
        ocr: _FixedOcr(''),
        speech: _FailingSpeech(
          const SpeechError(
            code: SpeechErrorCode.serviceUnavailable,
            userMessage: 'Servis yok.',
          ),
        ),
        deps: deps,
      ),
      deps: deps,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Asistan'));
    await t.pumpAndSettle();

    await t.enterText(
      find.byType(TextField),
      'Bu ay markete ne kadar harcadım?',
    );
    await t.pump();
    await t.tap(find.byTooltip('Gönder'));
    await t.pumpAndSettle();

    expect(find.textContaining('250,00'), findsOneWidget);
    expect(find.text('Manuel ekle'), findsNothing);
  });

  testWidgets(
    'mikrofon izni reddi ve kamera izni reddi Türkçe mesaj + Manuel ekle gösterir',
    (t) async {
      final deps = TestDeps();
      await pumpApp(
        t,
        _wrapInShell(
          gemini: _ThrowingGemini(const SocketException('Offline')),
          picker: _ErrorPicker(
            error: const ReceiptPickerException(
              OcrErrorCode.permissionDenied,
              'Kamera izni verilmedi.',
            ),
          ),
          ocr: _FixedOcr(''),
          speech: _FailingSpeech(
            const SpeechError(
              code: SpeechErrorCode.permissionDenied,
              userMessage: 'Mikrofon izni verilmedi.',
            ),
          ),
          deps: deps,
        ),
        deps: deps,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Asistan'));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('Sesli komut'));
      await t.pumpAndSettle();
      expect(find.textContaining('Mikrofon izni'), findsOneWidget);
      expect(find.text('Manuel ekle'), findsOneWidget);

      await t.tap(find.byTooltip('Fiş fotoğrafı ekle'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kamera ile çek'));
      await t.pumpAndSettle();
      expect(find.textContaining('Kamera izni'), findsOneWidget);
      expect(find.text('Manuel ekle'), findsOneWidget);
    },
  );
}
