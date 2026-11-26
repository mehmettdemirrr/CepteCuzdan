import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/speech/speech_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_repositories.dart';

class _StubGemini implements GeminiClient {
  _StubGemini(this.response);

  final String response;
  int callCount = 0;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    callCount++;
    return response;
  }
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
  Future<String> copyToPermanentStorage(String sourcePath) async => '';
  @override
  Future<void> deleteReceipt(String path) async {}
  @override
  Future<void> deleteAllReceipts() async {}
}

class _FakeSpeechService implements SpeechService {
  SpeechError? startError;
  bool _listening = false;
  void Function(String)? _onPartial;
  void Function(String)? _onFinal;
  void Function(SpeechError)? _onError;
  int stopCount = 0;
  int cancelCount = 0;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechError?> startListening({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(SpeechError error) onError,
  }) async {
    if (startError != null) return startError;
    _listening = true;
    _onPartial = onPartial;
    _onFinal = onFinal;
    _onError = onError;
    return null;
  }

  void emitPartial(String text) => _onPartial?.call(text);

  void emitFinal(String text) {
    _listening = false;
    _onFinal?.call(text);
  }

  void emitError(SpeechError error) {
    _listening = false;
    _onError?.call(error);
  }

  @override
  Future<void> stopListening() async {
    stopCount++;
    _listening = false;
  }

  @override
  Future<void> cancelListening() async {
    cancelCount++;
    _listening = false;
  }
}

const _voiceDraftJson = '''
{
  "type": "expense",
  "amount": 95.0,
  "merchant": "Kafe",
  "date": "2026-11-26",
  "category": "Yeme-İçme",
  "items": []
}
''';

void main() {
  late FakeRepos repos;
  late TransactionProvider txProvider;
  late CategoryProvider catProvider;
  late _StubGemini gemini;
  late _FakeSpeechService speech;
  late AssistantController controller;

  setUp(() async {
    repos = FakeRepos();
    txProvider = TransactionProvider(repos.txs);
    catProvider = CategoryProvider(repos.categories);
    await catProvider.load();
    gemini = _StubGemini(_voiceDraftJson);
    speech = _FakeSpeechService();
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
          storage: _StubStorage(),
        ),
        draftService: draftService,
      ),
      speechService: speech,
      now: () => DateTime(2026, 11, 26, 15, 0),
    );
  });

  tearDown(() {
    controller.dispose();
    txProvider.dispose();
    catProvider.dispose();
  });

  test(
    'mikrofon izni reddedilirse Türkçe hata döner ve Gemini çağrılmaz',
    () async {
      speech.startError = const SpeechError(
        code: SpeechErrorCode.permissionDenied,
        userMessage: 'Mikrofon izni verilmedi.',
      );

      await controller.toggleVoiceInput();

      expect(controller.isListening, isFalse);
      expect(controller.errorMessage, contains('Mikrofon izni'));
      expect(gemini.callCount, 0);
    },
  );

  test('kısmi sonuç canlı gösterilir, son sonuç aynı Gemini hattından source=voice taslağı üretir', () async {
    await controller.toggleVoiceInput();
    expect(controller.isListening, isTrue);

    speech.emitPartial('Kahveye 95');
    expect(controller.partialSpeechText, 'Kahveye 95');

    speech.emitFinal('Kahveye 95 lira verdim');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isListening, isFalse);
    expect(controller.partialSpeechText, isEmpty);
    expect(gemini.callCount, 1);
    expect(controller.pendingDraft, isNotNull);
    expect(controller.pendingDraft!.draft.source, TxSource.voice);
    expect(controller.pendingDraft!.draft.amountTl, 95.0);
    // Onaysız kayıt yapılmaz!
    expect(await repos.txs.query(), isEmpty);
  });

  test(
    'boş veya zaman aşımı ses hatasında Türkçe hata gösterir, Gemini çağrılmaz',
    () async {
      await controller.toggleVoiceInput();
      speech.emitError(
        const SpeechError(
          code: SpeechErrorCode.timeout,
          userMessage: 'Ses algılanamadı (zaman aşımı).',
        ),
      );

      expect(controller.isListening, isFalse);
      expect(controller.errorMessage, contains('zaman aşımı'));
      expect(gemini.callCount, 0);
    },
  );

  test(
    'dinleme iptal edildiğinde kısmi metin temizlenir ve Gemini çağrılmaz',
    () async {
      await controller.toggleVoiceInput();
      speech.emitPartial('Deneme');

      await controller.cancelVoiceInput();

      expect(controller.isListening, isFalse);
      expect(controller.partialSpeechText, isEmpty);
      expect(speech.cancelCount, 1);
      expect(gemini.callCount, 0);
    },
  );
}
