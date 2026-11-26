import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/query/budget_query_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_repositories.dart';

class _SpyGeminiClient implements GeminiClient {
  int callCount = 0;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    callCount++;
    return '{}';
  }
}

class _NoopPicker implements ReceiptImagePicker {
  @override
  Future<String?> pickImage(ReceiptImageSource source) async => null;
}

class _NoopOcr implements TextOcrEngine {
  @override
  Future<String> recognizeText(String imagePath) async => '';
}

class _NoopStorage implements ReceiptImageStorage {
  @override
  Future<String> copyToPermanentStorage(String sourcePath) async => '';
  @override
  Future<void> deleteReceipt(String path) async {}
  @override
  Future<void> deleteAllReceipts() async {}
}

void main() {
  final now = DateTime(2026, 11, 26, 14, 0);

  group('BudgetQueryService niyet ayrımı ve yerel hesaplama', () {
    late FakeRepos repos;
    late BudgetQueryService service;

    setUp(() async {
      repos = FakeRepos();
      service = BudgetQueryService(
        transactions: repos.txs,
        categories: repos.categories,
      );

      // Varsayılan kategoriler: id=1 Market, id=2 Ulaşım, id=8 Maaş (FakeRepos).
      await repos.txs.add(
        TransactionRecord(
          type: TxType.expense,
          amount: 15000, // 150 TL
          categoryId: 1, // Market
          date: DateTime(2026, 11, 26),
          merchant: 'Migros',
          source: TxSource.receipt,
          createdAt: now,
        ),
      );
      await repos.txs.add(
        TransactionRecord(
          type: TxType.expense,
          amount: 5050, // 50,50 TL
          categoryId: 1, // Market
          date: DateTime(2026, 11, 10),
          merchant: 'BİM',
          source: TxSource.voice,
          createdAt: now,
        ),
      );
      await repos.txs.add(
        TransactionRecord(
          type: TxType.expense,
          amount: 10000, // 100 TL (geçen ay)
          categoryId: 1,
          date: DateTime(2026, 10, 15),
          merchant: 'A101',
          source: TxSource.chat,
          createdAt: now,
        ),
      );
      await repos.txs.add(
        TransactionRecord(
          type: TxType.income,
          amount: 2500000, // 25.000 TL
          categoryId: 8, // Maaş
          date: DateTime(2026, 11, 1),
          merchant: 'Şirket',
          source: TxSource.manual,
          createdAt: now,
        ),
      );
    });

    test('harcama kaydı cümlelerini bütçe sorusu olarak işaretlemez', () {
      expect(
        BudgetQueryService.isBudgetQuestion('Markete 150 lira verdim'),
        isFalse,
      );
      expect(
        BudgetQueryService.isBudgetQuestion('Kahveye 120 TL harcadım'),
        isFalse,
      );
      expect(
        BudgetQueryService.isBudgetQuestion('Maaş 25000 TL geldi'),
        isFalse,
      );
    });

    test(
      'bu ay markete ne kadar harcadım sorusunu yerelde doğru hesaplar',
      () async {
        final answer = await service.tryAnswer(
          'Bu ay markete ne kadar harcadım?',
          now: now,
        );

        expect(answer, isNotNull);
        expect(answer, contains('Bu ay'));
        expect(answer, contains('Market'));
        expect(answer, contains('200,50'));
      },
    );

    test('bugün ne kadar harcadım sorusu yalnızca bugünü toplar', () async {
      final answer = await service.tryAnswer(
        'Bugün ne kadar harcadım?',
        now: now,
      );

      expect(answer, isNotNull);
      expect(answer, contains('Bugün'));
      expect(answer, contains('150,00'));
    });

    test('geçen ay toplam gider sorusu yalnızca önceki ayı toplar', () async {
      final answer = await service.tryAnswer(
        'Geçen ay toplam ne kadar harcadım?',
        now: now,
      );

      expect(answer, isNotNull);
      expect(answer, contains('Geçen ay'));
      expect(answer, contains('100,00'));
    });

    test('bu ay gelirim ne kadar sorusunu hesaplar', () async {
      final answer = await service.tryAnswer(
        'Bu ay ne kadar gelirim var?',
        now: now,
      );

      expect(answer, isNotNull);
      expect(answer, contains('25.000,00'));
    });

    test('bütçe özeti sorusunda gelir, gider ve bakiye döner', () async {
      final answer = await service.tryAnswer('Bu ay özetim nasıl?', now: now);

      expect(answer, isNotNull);
      expect(answer, contains('25.000,00'));
      expect(answer, contains('200,50'));
      expect(answer, contains('24.799,50'));
    });

    test('kayıt olmayan kategoride Türkçe doğal boş yanıt döner', () async {
      final answer = await service.tryAnswer(
        'Bu ay ulaşıma ne kadar harcadım?',
        now: now,
      );

      expect(answer, isNotNull);
      expect(answer, contains('Ulaşım'));
      expect(answer, contains('bulunmuyor'));
    });

    test(
      'AssistantController bütçe sorusunda Geminiyi çağırmaz ve taslak açmaz',
      () async {
        final gemini = _SpyGeminiClient();
        final txProvider = TransactionProvider(repos.txs);
        final catProvider = CategoryProvider(repos.categories);
        await catProvider.load();
        final draftService = ExpenseDraftService(gemini);

        final controller = AssistantController(
          chats: repos.chats,
          transactions: txProvider,
          categories: catProvider,
          draftService: draftService,
          receiptPipeline: ReceiptDraftPipeline(
            scanService: ReceiptScanService(
              picker: _NoopPicker(),
              ocrEngine: _NoopOcr(),
              storage: _NoopStorage(),
            ),
            draftService: draftService,
          ),
          budgetQueryService: service,
          now: () => now,
        );
        addTearDown(() {
          controller.dispose();
          txProvider.dispose();
          catProvider.dispose();
        });

        await controller.sendText('Bu ay markete ne kadar harcadım?');

        expect(gemini.callCount, 0);
        expect(controller.pendingDraft, isNull);
        expect(controller.messages, hasLength(2));
        expect(controller.messages.last.content, contains('200,50'));
      },
    );
  });
}
