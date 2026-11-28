// Fiş görseli yaşam döngüsü ve sıfırlama yarışları (PR #2 ikinci tur inceleme).
import 'dart:async';

import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_repositories.dart';

const _draftJson = '''
{"type":"expense","amount":320.00,"merchant":"Migros","date":"2026-11-26",
 "category":"Market","items":[]}
''';

/// Yanıtı [gate] tamamlanana kadar bekleten Gemini.
class _GatedGemini implements GeminiClient {
  Completer<void> gate = Completer<void>();

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    await gate.future;
    return _draftJson;
  }
}

class _Picker implements ReceiptImagePicker {
  @override
  Future<String?> pickImage(ReceiptImageSource source) async => '/tmp/fis.jpg';
}

class _Ocr implements TextOcrEngine {
  @override
  Future<String> recognizeText(String imagePath) async =>
      'MİGROS\nTOPLAM 320,00';
}

/// Gerçek depoyu taklit eder: dosyaları bir kümede tutar.
class _Storage implements ReceiptImageStorage {
  final Set<String> files = {};
  int _n = 0;

  @override
  Future<String> copyToPermanentStorage(String sourcePath) async {
    final path = '/app/receipts/r${++_n}.jpg';
    files.add(path);
    return path;
  }

  @override
  Future<void> deleteReceipt(String path) async => files.remove(path);

  @override
  Future<void> deleteAllReceipts() async => files.clear();

  @override
  Future<void> deleteOrphanReceipts(Set<String> activePaths) async =>
      files.removeWhere((f) => !activePaths.contains(f));
}

void main() {
  late FakeRepos repos;
  late TransactionProvider txs;
  late CategoryProvider cats;
  late _GatedGemini gemini;
  late _Storage storage;
  late ValueNotifier<int> resets;
  late AssistantController controller;

  setUp(() async {
    repos = FakeRepos();
    txs = TransactionProvider(repos.txs);
    cats = CategoryProvider(repos.categories);
    await cats.load();
    gemini = _GatedGemini();
    storage = _Storage();
    resets = ValueNotifier(0);
    final draftService = ExpenseDraftService(gemini);
    controller = AssistantController(
      chats: repos.chats,
      transactions: txs,
      categories: cats,
      draftService: draftService,
      receiptPipeline: ReceiptDraftPipeline(
        scanService: ReceiptScanService(
          picker: _Picker(),
          ocrEngine: _Ocr(),
          storage: storage,
        ),
        draftService: draftService,
      ),
      dataResets: resets,
      now: () => DateTime(2026, 11, 26, 14),
    );
    await pumpEventQueue();
  });

  tearDown(() {
    controller.dispose();
    txs.dispose();
    cats.dispose();
  });

  Future<void> addManualExpense() => txs.add(
    TransactionRecord(
      type: TxType.expense,
      amount: 1000,
      categoryId: 2,
      date: DateTime(2026, 11, 26),
      source: TxSource.manual,
      createdAt: DateTime(2026, 11, 26),
    ),
  );

  test('fiş taranırken başka bir kayıt eklenirse görsel silinmez, kayıt dosyayı gösterir', () async {
    final scan = controller.scanReceipt(ReceiptImageSource.gallery);
    await pumpEventQueue();
    expect(storage.files, hasLength(1), reason: 'görsel önce kopyalanır');

    await addManualExpense(); // İşlemler sekmesinden
    await pumpEventQueue();

    gemini.gate.complete();
    await scan;
    expect(await controller.confirmAndSavePendingDraft(), isTrue);
    final receiptTx = (await repos.txs.query())
        .where((t) => t.source == TxSource.receipt)
        .single;

    expect(storage.files, contains(receiptTx.receiptPath));
  });

  test('boştayken, işlemi silinen fişin görseli temizlenir', () async {
    storage.files.add('/app/receipts/eski.jpg');
    final id = await txs.add(
      TransactionRecord(
        type: TxType.expense,
        amount: 5000,
        categoryId: 1,
        date: DateTime(2026, 11, 20),
        source: TxSource.receipt,
        receiptPath: '/app/receipts/eski.jpg',
        createdAt: DateTime(2026, 11, 20),
      ),
    );
    await pumpEventQueue();
    expect(storage.files, contains('/app/receipts/eski.jpg'));

    await txs.delete(id);
    await pumpEventQueue();

    expect(storage.files, isNot(contains('/app/receipts/eski.jpg')));
  });

  test(
    'yazı isteği sürerken veri sıfırlanırsa taslak ve mesajlar geri gelmez',
    () async {
      final send = controller.sendText('Migros 320 TL');
      await pumpEventQueue();

      await repos.chats.clear(); // DataResetter verileri sildi
      resets.value++;
      await pumpEventQueue();

      gemini.gate.complete();
      await send;
      await pumpEventQueue();

      expect(controller.pendingDraft, isNull);
      expect(await repos.chats.all(), isEmpty);
      expect(controller.messages, isEmpty);
      expect(controller.isBusy, isFalse);
    },
  );

  test('fiş taranırken veri sıfırlanırsa taslak oluşmaz ve kopyalanan görsel silinir', () async {
    final scan = controller.scanReceipt(ReceiptImageSource.camera);
    await pumpEventQueue();
    expect(storage.files, hasLength(1));

    await repos.chats.clear();
    resets.value++;
    await pumpEventQueue();

    gemini.gate.complete();
    await scan;
    await pumpEventQueue();

    expect(controller.pendingDraft, isNull);
    expect(storage.files, isEmpty);
    expect(await repos.chats.all(), isEmpty);
  });
}
