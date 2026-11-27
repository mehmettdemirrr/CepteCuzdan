import 'dart:async';

import 'package:cepte_cuzdan/core/models/chat_message.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_repositories.dart';

class _ControlledGeminiClient implements GeminiClient {
  _ControlledGeminiClient({this.response});

  String? response;
  Completer<String>? completer;
  int callCount = 0;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    callCount++;
    if (completer != null) return completer!.future;
    return response ?? '';
  }
}

class _FakePicker implements ReceiptImagePicker {
  _FakePicker({this.path});

  String? path;

  @override
  Future<String?> pickImage(ReceiptImageSource source) async {
    return path;
  }
}

class _FakeOcr implements TextOcrEngine {
  _FakeOcr({this.text = ''});

  String text;

  @override
  Future<String> recognizeText(String imagePath) async => text;
}

class _FakeStorage implements ReceiptImageStorage {
  int deleteAllCount = 0;
  final List<String> deletedPaths = [];

  @override
  Future<String> copyToPermanentStorage(String sourcePath) async =>
      '/app/receipts/saved.jpg';

  @override
  Future<void> deleteReceipt(String path) async => deletedPaths.add(path);

  @override
  Future<void> deleteAllReceipts() async => deleteAllCount++;

  @override
  Future<void> deleteOrphanReceipts(Set<String> activePaths) async {}
}

const _validJson = '''
{
  "type": "expense",
  "amount": 150.0,
  "merchant": "Taksi",
  "date": "2026-11-26",
  "category": "Ulaşım",
  "items": []
}
''';

void main() {
  late FakeRepos repos;
  late TransactionProvider txProvider;
  late CategoryProvider catProvider;
  late _ControlledGeminiClient gemini;
  late _FakePicker picker;
  late _FakeOcr ocr;
  late _FakeStorage storage;
  late ValueNotifier<int> dataResets;
  late AssistantController controller;

  setUp(() async {
    repos = FakeRepos();
    txProvider = TransactionProvider(repos.txs);
    catProvider = CategoryProvider(repos.categories);
    await catProvider.load();
    gemini = _ControlledGeminiClient(response: _validJson);
    picker = _FakePicker(path: '/tmp/fis.jpg');
    ocr = _FakeOcr(text: 'MİGROS\nTOPLAM 150,00');
    storage = _FakeStorage();
    dataResets = ValueNotifier<int>(0);

    final draftService = ExpenseDraftService(gemini);
    controller = AssistantController(
      chats: repos.chats,
      transactions: txProvider,
      categories: catProvider,
      draftService: draftService,
      receiptPipeline: ReceiptDraftPipeline(
        scanService: ReceiptScanService(
          picker: picker,
          ocrEngine: ocr,
          storage: storage,
        ),
        draftService: draftService,
      ),
      dataResets: dataResets,
      now: () => DateTime(2026, 11, 26, 12, 0),
    );
  });

  tearDown(() {
    controller.dispose();
    dataResets.dispose();
    txProvider.dispose();
    catProvider.dispose();
  });

  test(
    'açılışta sohbet geçmişini ChatMessageRepository üzerinden yükler',
    () async {
      await repos.chats.add(
        ChatMessage(
          role: ChatRole.user,
          content: 'Kahveye 80 TL verdim',
          createdAt: DateTime(2026, 11, 25),
        ),
      );

      await controller.loadHistory();

      expect(controller.messages, hasLength(1));
      expect(controller.messages.first.content, 'Kahveye 80 TL verdim');
    },
  );

  test('boş mesaj gönderilmez ve Gemini çağrılmaz', () async {
    await controller.sendText('   \n  ');

    expect(gemini.callCount, 0);
    expect(controller.messages, isEmpty);
    expect(controller.pendingDraft, isNull);
  });

  test(
    'geçerli metin gönderildiğinde geçmişe yazar ve bellek içi taslak üretir',
    () async {
      await controller.sendText('Taksiye 150 lira verdim');

      expect(gemini.callCount, 1);
      expect(controller.messages, hasLength(2));
      expect(controller.messages[0].role, ChatRole.user);
      expect(controller.messages[0].content, 'Taksiye 150 lira verdim');
      expect(controller.messages[1].role, ChatRole.assistant);
      expect(controller.pendingDraft, isNotNull);
      expect(controller.pendingDraft!.draft.amountTl, 150.0);
      expect(controller.pendingDraft!.draft.categoryName, 'Ulaşım');
      // Onaysız kayıt yapılmaz!
      expect(await repos.txs.query(), isEmpty);
    },
  );

  test(
    'istek sürerken ikinci gönderim engellenir (tek istek kilidi)',
    () async {
      final completer = Completer<String>();
      gemini.completer = completer;

      final first = controller.sendText('Taksiye 150 lira verdim');
      expect(controller.isBusy, isTrue);

      await controller.sendText('İkinci mesaj');
      await Future<void>.delayed(Duration.zero);
      expect(gemini.callCount, 1);

      completer.complete(_validJson);
      await first;
      expect(controller.isBusy, isFalse);
    },
  );

  test(
    'hata durumunda Türkçe hata gösterir ve retryLast tekrar dener',
    () async {
      gemini.response = 'bozuk json';

      await controller.sendText('Taksiye 150 lira verdim');
      expect(controller.errorMessage, isNotNull);
      expect(controller.pendingDraft, isNull);

      gemini.response = _validJson;
      await controller.retryLast();

      expect(controller.errorMessage, isNull);
      expect(controller.pendingDraft, isNotNull);
      expect(gemini.callCount, 2);
    },
  );

  test('fiş seçimi iptal edilirse hata bannerı açılmaz', () async {
    picker.path = null;

    await controller.scanReceipt(ReceiptImageSource.camera);

    expect(controller.errorMessage, isNull);
    expect(controller.pendingDraft, isNull);
    expect(gemini.callCount, 0);
  });

  test(
    'başarılı fiş taraması receiptPath ile bellek içi taslak üretir',
    () async {
      await controller.scanReceipt(ReceiptImageSource.gallery);

      expect(controller.errorMessage, isNull);
      expect(controller.pendingDraft, isNotNull);
      expect(controller.pendingDraft!.receiptPath, '/app/receipts/saved.jpg');
      expect(controller.pendingDraft!.draft.source, TxSource.receipt);
      expect(await repos.txs.query(), isEmpty);
    },
  );

  test('DataResetter.resets sinyali gelince geçmiş, bekleyen taslak ve fiş dosyaları temizlenir', () async {
    await controller.scanReceipt(ReceiptImageSource.camera);
    expect(controller.messages, isNotEmpty);
    expect(controller.pendingDraft, isNotNull);

    // Normal işlem değişikliği fiş dosyalarını silmez.
    txProvider.markChanged();
    await Future<void>.delayed(Duration.zero);
    expect(storage.deleteAllCount, 0);

    // Veri sıfırlama sinyali her şeyi temizler.
    await repos.reset();
    dataResets.value++;
    await Future<void>.delayed(Duration.zero);

    expect(controller.messages, isEmpty);
    expect(controller.pendingDraft, isNull);
    expect(storage.deleteAllCount, 1);
  });
}
