// PR #2 ikinci tur incelemesinin küçük bulguları.
import 'dart:async';

import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/draft_validator.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/parsed_expense_draft.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/query/budget_query_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/speech/speech_service.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fakes/fake_repositories.dart';

const _categories = <TxType, List<String>>{
  TxType.expense: ['Market', 'Ulaşım', 'Diğer'],
  TxType.income: ['Maaş', 'Diğer'],
};

String _json(String date) =>
    '{"type":"expense","amount":320,"merchant":"Migros","date":"$date",'
    '"category":"Market","items":[]}';

class _NoGemini implements GeminiClient {
  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async => throw UnimplementedError();
}

class _NoPicker implements ReceiptImagePicker {
  @override
  Future<String?> pickImage(ReceiptImageSource source) async => null;
}

class _NoOcr implements TextOcrEngine {
  @override
  Future<String> recognizeText(String imagePath) async => '';
}

class _NoStorage implements ReceiptImageStorage {
  @override
  Future<String> copyToPermanentStorage(String sourcePath) async => sourcePath;
  @override
  Future<void> deleteReceipt(String path) async {}
  @override
  Future<void> deleteAllReceipts() async {}
  @override
  Future<void> deleteOrphanReceipts(Set<String> activePaths) async {}
}

/// Başlatması [gate] tamamlanana kadar süren ses servisi.
class _SlowStartSpeech implements SpeechService {
  final gate = Completer<void>();
  int startCalls = 0;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechError?> startListening({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(SpeechError error) onError,
  }) async {
    startCalls++;
    await gate.future;
    _listening = true;
    return null;
  }

  @override
  Future<void> stopListening() async => _listening = false;

  @override
  Future<void> cancelListening() async => _listening = false;
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('bütçe sorusunda dönem kelimeleri tam kelime olarak eşleşir', () {
    final now = DateTime(2026, 11, 26, 14);
    Future<String?> ask(String q) {
      final r = FakeRepos();
      return BudgetQueryService(
        transactions: r.txs,
        categories: r.categories,
      ).tryAnswer(q, now: now);
    }

    test('"dünya" kelimesi "dün" sayılmaz', () async {
      final a = await ask('Bu ay dünya kupası için ne kadar harcadım?');
      expect(a, isNotNull);
      expect(a!, isNot(startsWith('Dün')));
      expect(a, startsWith('Bu ay'));
    });

    test('"dün" ve ekli hâli hâlâ tanınır', () async {
      expect(await ask('Dün ne kadar harcadım?'), startsWith('Dün'));
      expect(await ask('Dünkü harcamam ne kadar?'), startsWith('Dün'));
    });

    test('"bu gün" boşluklu yazılınca da bugün sayılır', () async {
      expect(await ask('Bu gün ne kadar harcadım?'), startsWith('Bugün'));
    });
  });

  group('okunan tarih makul aralıkta değilse bugün kullanılır', () {
    final today = DateTime(2026, 11, 26, 15);
    ParsedExpenseDraft parse(String date) {
      final r = parseAndValidateDraft(
        rawResponse: _json(date),
        today: today,
        categoriesByType: _categories,
        source: TxSource.receipt,
      );
      return (r as ExpenseDraftSuccess).draft;
    }

    test('gelecek yıl (OCR hatası) → bugün + uyarı', () {
      final d = parse('2062-05-01');
      expect(d.date, DateTime(2026, 11, 26));
      expect(d.usedDefaultDate, isTrue);
    });

    test('5 yıldan eski → bugün + uyarı', () {
      final d = parse('2019-03-01');
      expect(d.date, DateTime(2026, 11, 26));
      expect(d.usedDefaultDate, isTrue);
    });

    test('yakın geçmiş ve yarın kabul edilir', () {
      expect(parse('2024-02-01').date, DateTime(2024, 2, 1));
      expect(parse('2024-02-01').usedDefaultDate, isFalse);
      expect(parse('2026-11-27').date, DateTime(2026, 11, 27));
    });
  });

  test('mikrofona çift dokunma tek dinleme başlatır', () async {
    final repos = FakeRepos();
    final txs = TransactionProvider(repos.txs);
    final cats = CategoryProvider(repos.categories);
    await cats.load();
    final speech = _SlowStartSpeech();
    final draftService = ExpenseDraftService(_NoGemini());
    final c = AssistantController(
      chats: repos.chats,
      transactions: txs,
      categories: cats,
      draftService: draftService,
      receiptPipeline: ReceiptDraftPipeline(
        scanService: ReceiptScanService(
          picker: _NoPicker(),
          ocrEngine: _NoOcr(),
          storage: _NoStorage(),
        ),
        draftService: draftService,
      ),
      speechService: speech,
    );

    final first = c.toggleVoiceInput();
    final second = c
        .toggleVoiceInput(); // izin/başlatma sürerken ikinci dokunma
    speech.gate.complete();
    await Future.wait([first, second]);

    expect(speech.startCalls, 1);
    expect(c.isListening, isTrue);
    c.dispose();
  });
}
