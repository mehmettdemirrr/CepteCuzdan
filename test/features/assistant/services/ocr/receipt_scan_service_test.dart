import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/parsed_expense_draft.dart';
import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePicker implements ReceiptImagePicker {
  _FakePicker({this.path, this.error});

  final String? path;
  final Object? error;

  @override
  Future<String?> pickImage(ReceiptImageSource source) async {
    if (error != null) throw error!;
    return path;
  }
}

class _FakeOcrEngine implements TextOcrEngine {
  _FakeOcrEngine({this.text = '', this.error});

  final String text;
  final Object? error;
  int callCount = 0;

  @override
  Future<String> recognizeText(String imagePath) async {
    callCount++;
    if (error != null) throw error!;
    return text;
  }
}

class _FakeStorage implements ReceiptImageStorage {
  _FakeStorage({this.savedPath = '/app/receipts/receipt_1.jpg'});

  final String savedPath;
  int copyCount = 0;
  final List<String> deletedPaths = [];

  @override
  Future<String> copyToPermanentStorage(String sourcePath) async {
    copyCount++;
    return savedPath;
  }

  @override
  Future<void> deleteReceipt(String path) async {
    deletedPaths.add(path);
  }

  @override
  Future<void> deleteAllReceipts() async {}
}

class _FakeGeminiClient implements GeminiClient {
  _FakeGeminiClient({this.response = ''});

  final String response;
  int callCount = 0;
  String? lastUserPrompt;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    callCount++;
    lastUserPrompt = userPrompt;
    return response;
  }
}

const _categories = {
  TxType.expense: ['Market', 'Ulaşım', 'Yeme-İçme', 'Diğer'],
  TxType.income: ['Maaş', 'Diğer'],
};

/// Sentetik Migros/BİM/A101 tarzı fiş metinleri (gerçek fiş görseli kullanılmaz).
const _migrosFixture = '''
MİGROS TİCARET A.Ş.
------------------------
TARİH: 08.11.2026  18:45
FİŞ NO: 0142
SÜT 1L X2          *71,00
YOĞURT 500G        *45,50
EKMEK              *12,50
------------------------
TOPKDV              *1,29
TOPLAM            *129,00
''';

const _bimFixture = '''
BİM BİRLEŞİK MAĞAZALAR A.Ş.
08/11/26 11:20
DOST SÜT            34,50
ÇAY 1KG            165,00
TOPLAM             199,50
''';

void main() {
  final today = DateTime(2026, 11, 26);

  group('ReceiptScanService', () {
    test(
      'kullanıcı seçimi iptal ederse cancelled döner, OCR çalışmaz',
      () async {
        final ocr = _FakeOcrEngine(text: _migrosFixture);
        final storage = _FakeStorage();
        final service = ReceiptScanService(
          picker: _FakePicker(path: null),
          ocrEngine: ocr,
          storage: storage,
        );

        final result = await service.pickAndExtractText(
          ReceiptImageSource.camera,
        );

        expect(result, isA<OcrFailure>());
        final error = (result as OcrFailure).error;
        expect(error.code, OcrErrorCode.cancelled);
        expect(ocr.callCount, 0);
        expect(storage.copyCount, 0);
      },
    );

    test('kamera izni reddedilirse permissionDenied döner', () async {
      final service = ReceiptScanService(
        picker: _FakePicker(
          error: const ReceiptPickerException(
            OcrErrorCode.permissionDenied,
            'Kamera izni verilmedi.',
          ),
        ),
        ocrEngine: _FakeOcrEngine(),
        storage: _FakeStorage(),
      );

      final result = await service.pickAndExtractText(
        ReceiptImageSource.camera,
      );

      expect(result, isA<OcrFailure>());
      expect((result as OcrFailure).error.code, OcrErrorCode.permissionDenied);
    });

    test(
      'OCR istisna fırlatırsa ocrFailed döner ve dosya kopyalanmaz',
      () async {
        final storage = _FakeStorage();
        final service = ReceiptScanService(
          picker: _FakePicker(path: '/tmp/fis.jpg'),
          ocrEngine: _FakeOcrEngine(error: Exception('ML Kit hatası')),
          storage: storage,
        );

        final result = await service.pickAndExtractText(
          ReceiptImageSource.gallery,
        );

        expect(result, isA<OcrFailure>());
        expect((result as OcrFailure).error.code, OcrErrorCode.ocrFailed);
        expect(storage.copyCount, 0);
      },
    );

    test(
      'OCR boş veya anlamsız metin döndürürse unreadableReceipt döner',
      () async {
        final storage = _FakeStorage();
        final service = ReceiptScanService(
          picker: _FakePicker(path: '/tmp/bulanik.jpg'),
          ocrEngine: _FakeOcrEngine(text: '   --- \n  '),
          storage: storage,
        );

        final result = await service.pickAndExtractText(
          ReceiptImageSource.camera,
        );

        expect(result, isA<OcrFailure>());
        expect(
          (result as OcrFailure).error.code,
          OcrErrorCode.unreadableReceipt,
        );
        expect(storage.copyCount, 0);
      },
    );

    test(
      'başarılı OCR temizlenmiş metni ve kalıcı dosya yolunu döner',
      () async {
        final storage = _FakeStorage(savedPath: '/docs/receipts/r1.jpg');
        final service = ReceiptScanService(
          picker: _FakePicker(path: '/tmp/fis.jpg'),
          ocrEngine: _FakeOcrEngine(text: _migrosFixture),
          storage: storage,
        );

        final result = await service.pickAndExtractText(
          ReceiptImageSource.camera,
        );

        expect(result, isA<OcrSuccess>());
        final success = result as OcrSuccess;
        expect(success.receiptPath, '/docs/receipts/r1.jpg');
        expect(success.cleanedText, contains('MİGROS TİCARET A.Ş.'));
        expect(success.cleanedText, isNot(contains('--------')));
        expect(storage.copyCount, 1);
      },
    );
  });

  group('ReceiptDraftPipeline (OCR → Gemini taslağı)', () {
    test('OCR boşsa Gemini HİÇ çağrılmaz', () async {
      final gemini = _FakeGeminiClient(response: '{}');
      final pipeline = ReceiptDraftPipeline(
        scanService: ReceiptScanService(
          picker: _FakePicker(path: '/tmp/fis.jpg'),
          ocrEngine: _FakeOcrEngine(text: '  '),
          storage: _FakeStorage(),
        ),
        draftService: ExpenseDraftService(gemini),
      );

      final result = await pipeline.scanReceiptToDraft(
        source: ReceiptImageSource.camera,
        today: today,
        categoriesByType: _categories,
      );

      expect(result, isA<ReceiptDraftOcrFailure>());
      expect(gemini.callCount, 0);
    });

    test('sentetik Migros fişi temizlenip Gemini hattından receipt taslağına dönüşür', () async {
      final gemini = _FakeGeminiClient(
        response: '''
        {
          "type": "expense",
          "amount": "129,00",
          "merchant": "Migros",
          "date": "2026-11-08",
          "category": "Market",
          "items": [
            {"name": "Süt 1L", "quantity": 2, "price": 71.00},
            {"name": "Yoğurt 500G", "quantity": 1, "price": 45.50},
            {"name": "Ekmek", "quantity": 1, "price": 12.50}
          ]
        }
        ''',
      );
      final pipeline = ReceiptDraftPipeline(
        scanService: ReceiptScanService(
          picker: _FakePicker(path: '/tmp/migros.jpg'),
          ocrEngine: _FakeOcrEngine(text: _migrosFixture),
          storage: _FakeStorage(savedPath: '/docs/receipts/migros.jpg'),
        ),
        draftService: ExpenseDraftService(gemini),
      );

      final result = await pipeline.scanReceiptToDraft(
        source: ReceiptImageSource.camera,
        today: today,
        categoriesByType: _categories,
      );

      expect(result, isA<ReceiptDraftSuccess>());
      final success = result as ReceiptDraftSuccess;
      expect(success.receiptPath, '/docs/receipts/migros.jpg');
      expect(success.draft.source, TxSource.receipt);
      expect(success.draft.type, TxType.expense);
      expect(success.draft.amountTl, 129.0);
      expect(success.draft.merchant, 'Migros');
      expect(success.draft.categoryName, 'Market');
      expect(success.draft.date, DateTime(2026, 11, 8));
      expect(success.draft.items, hasLength(3));
      expect(gemini.callCount, 1);
      expect(gemini.lastUserPrompt, contains('TOPLAM *129,00'));
    });

    test(
      'sentetik BİM fişinde AI hata verirse kopyalanan fiş dosyası temizlenir',
      () async {
        final storage = _FakeStorage(savedPath: '/docs/receipts/bim.jpg');
        final gemini = _FakeGeminiClient(response: 'bozuk json');
        final pipeline = ReceiptDraftPipeline(
          scanService: ReceiptScanService(
            picker: _FakePicker(path: '/tmp/bim.jpg'),
            ocrEngine: _FakeOcrEngine(text: _bimFixture),
            storage: storage,
          ),
          draftService: ExpenseDraftService(gemini),
        );

        final result = await pipeline.scanReceiptToDraft(
          source: ReceiptImageSource.gallery,
          today: today,
          categoriesByType: _categories,
        );

        expect(result, isA<ReceiptDraftAiFailure>());
        expect(
          (result as ReceiptDraftAiFailure).error.code,
          ExpenseDraftErrorCode.invalidJson,
        );
        expect(storage.deletedPaths, ['/docs/receipts/bim.jpg']);
      },
    );
  });
}
