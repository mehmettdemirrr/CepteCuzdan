import 'dart:async';

import 'package:cepte_cuzdan/core/db/app_database.dart';
import 'package:cepte_cuzdan/core/db/sqlite_category_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_chat_message_repository.dart';
import 'package:cepte_cuzdan/core/db/sqlite_transaction_repository.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/period_summary.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/repositories/transaction_repository.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/parsed_expense_draft.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fakes/fake_repositories.dart';

class _StubGemini implements GeminiClient {
  _StubGemini(this.response);

  String response;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async => response;
}

class _StubPicker implements ReceiptImagePicker {
  @override
  Future<String?> pickImage(ReceiptImageSource source) async => '/tmp/fis.jpg';
}

class _StubOcr implements TextOcrEngine {
  @override
  Future<String> recognizeText(String imagePath) async =>
      'MİGROS\nTOPLAM 320,00';
}

class _StubStorage implements ReceiptImageStorage {
  final List<String> deleted = [];

  @override
  Future<String> copyToPermanentStorage(String sourcePath) async =>
      '/app/receipts/r1.jpg';

  @override
  Future<void> deleteReceipt(String path) async => deleted.add(path);

  @override
  Future<void> deleteAllReceipts() async {}
}

class _FailingOrDelayedTxRepo implements TransactionRepository {
  _FailingOrDelayedTxRepo(this._inner);

  final FakeTransactionRepository _inner;
  bool shouldFail = false;
  Completer<void>? gate;

  @override
  Future<int> add(
    TransactionRecord tx, {
    List<ReceiptItem> items = const [],
  }) async {
    if (gate != null) await gate!.future;
    if (shouldFail) throw StateError('DB yazma hatası');
    return _inner.add(tx, items: items);
  }

  @override
  Future<void> delete(int id) => _inner.delete(id);

  @override
  Future<TransactionRecord?> getById(int id) => _inner.getById(id);

  @override
  Future<List<ReceiptItem>> itemsOf(int transactionId) =>
      _inner.itemsOf(transactionId);

  @override
  Future<List<TransactionRecord>> query({
    range,
    int? categoryId,
    TxType? type,
    int? limit,
  }) => _inner.query(
    range: range,
    categoryId: categoryId,
    type: type,
    limit: limit,
  );

  @override
  Future<PeriodSummary> summarize(range) => _inner.summarize(range);

  @override
  Future<void> update(TransactionRecord tx) => _inner.update(tx);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Onay kartı güvenli kayıt akışı (FakeRepos)', () {
    late FakeRepos repos;
    late _FailingOrDelayedTxRepo txRepo;
    late TransactionProvider txProvider;
    late CategoryProvider catProvider;
    late _StubGemini gemini;
    late _StubStorage storage;
    late AssistantController controller;

    Future<void> setupWithJson(String json) async {
      repos = FakeRepos();
      txRepo = _FailingOrDelayedTxRepo(repos.txs);
      txProvider = TransactionProvider(txRepo);
      catProvider = CategoryProvider(repos.categories);
      await catProvider.load();
      gemini = _StubGemini(json);
      storage = _StubStorage();
      final draftService = ExpenseDraftService(gemini);
      controller = AssistantController(
        chats: repos.chats,
        transactions: txProvider,
        categories: catProvider,
        draftService: draftService,
        receiptPipeline: ReceiptDraftPipeline(
          scanService: ReceiptScanService(
            picker: _StubPicker(),
            ocrEngine: _StubOcr(),
            storage: storage,
          ),
          draftService: draftService,
        ),
        now: () => DateTime(2026, 11, 26, 14, 0),
      );
    }

    tearDown(() {
      controller.dispose();
      txProvider.dispose();
      catProvider.dispose();
    });

    test('onay öncesi sıfır yazma; Kaydet 320,00 TL → 32000 kuruş ve linkTransaction', () async {
      await setupWithJson('''
      {
        "type": "expense",
        "amount": 320.00,
        "merchant": "Migros",
        "date": "2026-11-26",
        "category": "Market",
        "items": [
          {"name": "Süt", "quantity": 2, "price": 70.00},
          {"name": "Peynir", "quantity": 1, "price": 250.00}
        ]
      }
      ''');

      await controller.scanReceipt(ReceiptImageSource.camera);
      expect(await repos.txs.query(), isEmpty);

      final saved = await controller.confirmAndSavePendingDraft();

      expect(saved, isTrue);
      expect(controller.pendingDraft!.isSaved, isTrue);
      expect(txProvider.revision, 1);

      final allTx = await repos.txs.query();
      expect(allTx, hasLength(1));
      final tx = allTx.single;
      expect(tx.amount, 32000);
      expect(tx.merchant, 'Migros');
      expect(tx.source, TxSource.receipt);
      expect(tx.receiptPath, '/app/receipts/r1.jpg');

      final items = await repos.txs.itemsOf(tx.id!);
      expect(items, hasLength(2));
      expect(items[0].price, 7000);
      expect(items[1].price, 25000);

      final messages = await repos.chats.all();
      expect(messages.last.transactionId, tx.id);
    });

    test('19,99 TL → 1999 kuruş hassas dönüşüm', () async {
      await setupWithJson('''
      {
        "type": "expense",
        "amount": 19.99,
        "merchant": "Fırın",
        "date": "2026-11-26",
        "category": "Yeme-İçme",
        "items": []
      }
      ''');

      await controller.sendText('Fırından 19,99 TL ekmek aldım');
      final saved = await controller.confirmAndSavePendingDraft();

      expect(saved, isTrue);
      final tx = (await repos.txs.query()).single;
      expect(tx.amount, 1999);
      expect(tx.source, TxSource.chat);
    });

    test('İptal sıfır kayıt oluşturur ve fiş görselini siler', () async {
      await setupWithJson('''
      {
        "type": "expense",
        "amount": 100.0,
        "merchant": "BİM",
        "date": "2026-11-26",
        "category": "Market",
        "items": []
      }
      ''');

      await controller.scanReceipt(ReceiptImageSource.gallery);
      await controller.clearPendingDraft();

      expect(controller.pendingDraft, isNull);
      expect(await repos.txs.query(), isEmpty);
      expect(storage.deleted, ['/app/receipts/r1.jpg']);
    });

    test('Düzenle güncel değerleri veritabanına yazar', () async {
      await setupWithJson('''
      {
        "type": "expense",
        "amount": 100.0,
        "merchant": "Eski",
        "date": "2026-11-26",
        "category": "Market",
        "items": []
      }
      ''');

      await controller.sendText('Eski 100 TL');
      controller.updatePendingDraft(
        ParsedExpenseDraft(
          type: TxType.expense,
          amountTl: 245.50,
          merchant: 'Güncel Market',
          date: DateTime(2026, 11, 20),
          categoryName: 'Ulaşım',
          source: TxSource.chat,
          usedDefaultDate: false,
          usedFallbackCategory: false,
          items: const [
            ParsedReceiptItem(name: 'Bilet', quantity: 1, priceTl: 245.50),
          ],
        ),
      );

      final saved = await controller.confirmAndSavePendingDraft();
      expect(saved, isTrue);

      final tx = (await repos.txs.query()).single;
      expect(tx.amount, 24550);
      expect(tx.merchant, 'Güncel Market');
      expect(tx.date, DateTime(2026, 11, 20));
      final items = await repos.txs.itemsOf(tx.id!);
      expect(items.single.name, 'Bilet');
      expect(items.single.price, 24550);
    });

    test(
      'eski taslak için açılan Düzenle yeni taslak gelince yeni taslağı ezmez',
      () async {
        await setupWithJson('''
      {
        "type": "expense",
        "amount": 100.0,
        "merchant": "İlk",
        "date": "2026-11-26",
        "category": "Market",
        "items": []
      }
      ''');

        await controller.sendText('İlk 100 TL');
        final firstDraftId = controller.pendingDraft!.draftId;

        gemini.response = '''
      {
        "type": "expense",
        "amount": 250.0,
        "merchant": "Yeni",
        "date": "2026-11-26",
        "category": "Ulaşım",
        "items": []
      }
      ''';
        await controller.sendText('Yeni 250 TL');
        expect(controller.pendingDraft!.draft.merchant, 'Yeni');

        // Eski taslağa ait düzenleme sonucu geç gelirse yeni taslağı ezmemeli.
        controller.updatePendingDraft(
          ParsedExpenseDraft(
            type: TxType.expense,
            amountTl: 999.0,
            merchant: 'Eski Düzenleme',
            date: DateTime(2026, 11, 26),
            categoryName: 'Market',
            source: TxSource.chat,
            items: const [],
            usedDefaultDate: false,
            usedFallbackCategory: false,
          ),
          expectedDraftId: firstDraftId,
        );

        expect(controller.pendingDraft!.draft.amountTl, 250.0);
        expect(controller.pendingDraft!.draft.merchant, 'Yeni');
      },
    );

    test('eski taslak için açılan Düzenle yeni taslak gelince yeni taslağı ezmez', () async {
      await setupWithJson('''
      {
        "type": "expense",
        "amount": 100.0,
        "merchant": "İlk",
        "date": "2026-11-26",
        "category": "Market",
        "items": []
      }
      ''');

      await controller.sendText('İlk 100 TL');
      final firstDraftId = controller.pendingDraft!.draftId;

      gemini.response = '''
      {
        "type": "expense",
        "amount": 250.0,
        "merchant": "Yeni",
        "date": "2026-11-26",
        "category": "Ulaşım",
        "items": []
      }
      ''';
      await controller.sendText('Yeni 250 TL');
      expect(controller.pendingDraft!.draft.merchant, 'Yeni');

      // Eski taslağa ait düzenleme sonucu geç gelirse yeni taslağı ezmemeli.
      controller.updatePendingDraft(
        ParsedExpenseDraft(
          type: TxType.expense,
          amountTl: 999.0,
          merchant: 'Eski Düzenleme',
          date: DateTime(2026, 11, 26),
          categoryName: 'Market',
          source: TxSource.chat,
          items: const [],
          usedDefaultDate: false,
          usedFallbackCategory: false,
        ),
        expectedDraftId: firstDraftId,
      );

      expect(controller.pendingDraft!.draft.amountTl, 250.0);
      expect(controller.pendingDraft!.draft.merchant, 'Yeni');
    });

    test('çift tıklama koruması aynı taslağı iki kez kaydetmez', () async {
      await setupWithJson('''
      {
        "type": "expense",
        "amount": 50.0,
        "merchant": "Kafe",
        "date": "2026-11-26",
        "category": "Yeme-İçme",
        "items": []
      }
      ''');

      await controller.sendText('Kafe 50 TL');
      final gate = Completer<void>();
      txRepo.gate = gate;

      final first = controller.confirmAndSavePendingDraft();
      final second = await controller.confirmAndSavePendingDraft();
      expect(second, isFalse);

      gate.complete();
      expect(await first, isTrue);

      // Kayıt sonrası tekrar basılsa da ikinci kayıt oluşmaz.
      final third = await controller.confirmAndSavePendingDraft();
      expect(third, isFalse);
      expect(await repos.txs.query(), hasLength(1));
    });

    test('kayıt hatasında kart kapanmaz, hata gösterir ve tekrar deneyince kaydeder', () async {
      await setupWithJson('''
      {
        "type": "expense",
        "amount": 75.0,
        "merchant": "Eczane",
        "date": "2026-11-26",
        "category": "Sağlık",
        "items": []
      }
      ''');

      await controller.sendText('Eczane 75 TL');
      txRepo.shouldFail = true;

      final firstTry = await controller.confirmAndSavePendingDraft();
      expect(firstTry, isFalse);
      expect(controller.pendingDraft, isNotNull);
      expect(controller.pendingDraft!.isSaved, isFalse);
      expect(controller.saveErrorMessage, isNotNull);

      txRepo.shouldFail = false;
      final retry = await controller.confirmAndSavePendingDraft();
      expect(retry, isTrue);
      expect(controller.pendingDraft!.isSaved, isTrue);
      expect(controller.saveErrorMessage, isNull);
      expect(await repos.txs.query(), hasLength(1));
    });
  });

  test('in-memory SQLite entegrasyon: onaylı taslak işlem, kalem ve mesaj bağlantısını yazar', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      singleInstance: false,
    );
    addTearDown(db.close);

    final txRepo = SqliteTransactionRepository(db);
    final catRepo = SqliteCategoryRepository(db);
    final chatRepo = SqliteChatMessageRepository(db);
    final txProvider = TransactionProvider(txRepo);
    final catProvider = CategoryProvider(catRepo);
    await catProvider.load();

    final gemini = _StubGemini('''
    {
      "type": "expense",
      "amount": 320.00,
      "merchant": "ŞOK Market",
      "date": "2026-11-26",
      "category": "Market",
      "items": [
        {"name": "Çay", "quantity": 1, "price": 170.00},
        {"name": "Şeker", "quantity": 2, "price": 150.00}
      ]
    }
    ''');
    final draftService = ExpenseDraftService(gemini);
    final controller = AssistantController(
      chats: chatRepo,
      transactions: txProvider,
      categories: catProvider,
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
    );
    addTearDown(() {
      controller.dispose();
      txProvider.dispose();
      catProvider.dispose();
    });

    await controller.scanReceipt(ReceiptImageSource.gallery);
    expect(await txRepo.query(), isEmpty);

    final ok = await controller.confirmAndSavePendingDraft();
    expect(ok, isTrue);

    final savedTx = (await txRepo.query()).single;
    expect(savedTx.amount, 32000);
    expect(savedTx.merchant, 'ŞOK Market');
    expect(savedTx.source, TxSource.receipt);

    final savedItems = await txRepo.itemsOf(savedTx.id!);
    expect(savedItems, hasLength(2));
    expect(savedItems[0].price, 17000);
    expect(savedItems[1].price, 15000);

    final msgs = await chatRepo.all();
    expect(msgs.last.transactionId, savedTx.id);
  });
}
