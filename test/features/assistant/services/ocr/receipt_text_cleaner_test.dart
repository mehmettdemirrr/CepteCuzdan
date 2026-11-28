import 'package:cepte_cuzdan/features/assistant/services/ocr/receipt_text_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cleanReceiptText', () {
    test('fazla boşlukları, boş satırları ve ayırıcı çizgileri temizler', () {
      const raw = '''
      
      MİGROS   TİCARET  A.Ş.
      ------------------------
      TARİH : 08.11.2026   14:32
      ========================
      SÜT 1L          35,50
      EKMEK           12,50
      ************************
      TOPLAM         *48,00
      
      ''';

      final cleaned = cleanReceiptText(raw);

      expect(
        cleaned,
        'MİGROS TİCARET A.Ş.\n'
        'TARİH : 08.11.2026 14:32\n'
        'SÜT 1L 35,50\n'
        'EKMEK 12,50\n'
        'TOPLAM *48,00',
      );
    });

    test('ardışık yinelenen satırları tekilleştirir', () {
      const raw =
          'BİM BİRLEŞİK MAĞAZALAR\nBİM BİRLEŞİK MAĞAZALAR\nTOPLAM 120,00';
      expect(cleanReceiptText(raw), 'BİM BİRLEŞİK MAĞAZALAR\nTOPLAM 120,00');
    });
  });

  group('isMeaningfulReceiptText', () {
    test('boş, çok kısa veya yalnızca noktalama içeren metinleri reddeder', () {
      expect(isMeaningfulReceiptText(''), isFalse);
      expect(isMeaningfulReceiptText('   \n  '), isFalse);
      expect(isMeaningfulReceiptText('abc'), isFalse);
      expect(isMeaningfulReceiptText('-------- === ***'), isFalse);
    });

    test('okunaklı fiş metnini kabul eder', () {
      expect(isMeaningfulReceiptText('BİM\nTOPLAM 85,50'), isTrue);
    });
  });
}
