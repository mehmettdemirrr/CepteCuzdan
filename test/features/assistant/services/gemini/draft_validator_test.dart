import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/draft_validator.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/parsed_expense_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 26, 15, 30);
  final expectedToday = DateTime(2026, 11, 26);
  const categories = <TxType, List<String>>{
    TxType.expense: [
      'Market',
      'Ulaşım',
      'Faturalar',
      'Yeme-İçme',
      'Eğlence',
      'Sağlık',
      'Diğer',
    ],
    TxType.income: ['Maaş', 'Diğer'],
  };

  group('parseAndValidateDraft', () {
    test('geçerli JSON yanıtını TL cinsinden doğru ayrıştırır', () {
      const raw = '''
{
  "type": "expense",
  "amount": 320.50,
  "merchant": "Migros",
  "date": "2026-11-20",
  "category": "Market",
  "items": [
    {"name": "Süt", "quantity": 2, "price": 90.0},
    {"name": "Ekmek", "quantity": 1, "price": 15.5}
  ]
}
''';

      final result = parseAndValidateDraft(
        rawResponse: raw,
        today: today,
        categoriesByType: categories,
        source: TxSource.receipt,
      );

      expect(result, isA<ExpenseDraftSuccess>());
      final draft = (result as ExpenseDraftSuccess).draft;
      expect(draft.type, TxType.expense);
      expect(draft.amountTl, 320.50);
      expect(draft.merchant, 'Migros');
      expect(draft.date, DateTime(2026, 11, 20));
      expect(draft.categoryName, 'Market');
      expect(draft.source, TxSource.receipt);
      expect(draft.usedDefaultDate, isFalse);
      expect(draft.usedFallbackCategory, isFalse);
      expect(draft.items, const [
        ParsedReceiptItem(name: 'Süt', quantity: 2.0, priceTl: 90.0),
        ParsedReceiptItem(name: 'Ekmek', quantity: 1.0, priceTl: 15.5),
      ]);
    });

    test('markdown kod çiti içindeki JSON yanıtını tolere eder', () {
      const raw = '''
```json
{
  "type": "expense",
  "amount": 150,
  "merchant": "Taksi",
  "date": "2026-11-26",
  "category": "Ulaşım",
  "items": []
}
```
''';

      final result = parseAndValidateDraft(
        rawResponse: raw,
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );

      expect(result, isA<ExpenseDraftSuccess>());
      final draft = (result as ExpenseDraftSuccess).draft;
      expect(draft.amountTl, 150.0);
      expect(draft.categoryName, 'Ulaşım');
      expect(draft.merchant, 'Taksi');
    });

    test('dilsiz markdown kod çitini (``` ... ```) tolere eder', () {
      const raw = '''
```
{"type": "income", "amount": 45000, "category": "Maaş", "date": "2026-11-01"}
```
''';

      final result = parseAndValidateDraft(
        rawResponse: raw,
        today: today,
        categoriesByType: categories,
        source: TxSource.voice,
      );

      expect(result, isA<ExpenseDraftSuccess>());
      final draft = (result as ExpenseDraftSuccess).draft;
      expect(draft.type, TxType.income);
      expect(draft.amountTl, 45000.0);
      expect(draft.categoryName, 'Maaş');
    });

    test('geçersiz JSON veya JSON nesnesi olmayan yanıtı reddeder', () {
      for (final bad in ['', 'bu json değil', '[1, 2, 3]', '{"type":']) {
        final result = parseAndValidateDraft(
          rawResponse: bad,
          today: today,
          categoriesByType: categories,
          source: TxSource.chat,
        );

        expect(result, isA<ExpenseDraftFailure>(), reason: 'girdi: $bad');
        expect(
          (result as ExpenseDraftFailure).error.code,
          ExpenseDraftErrorCode.invalidJson,
        );
      }
    });

    test('eksik zorunlu alanlarda (type veya amount) hata döner', () {
      const missingType = '{"amount": 100, "category": "Market"}';
      const missingAmount = '{"type": "expense", "category": "Market"}';
      const nullAmount = '{"type": "expense", "amount": null}';

      for (final raw in [missingType, missingAmount, nullAmount]) {
        final result = parseAndValidateDraft(
          rawResponse: raw,
          today: today,
          categoriesByType: categories,
          source: TxSource.chat,
        );

        expect(result, isA<ExpenseDraftFailure>(), reason: 'girdi: $raw');
        expect(
          (result as ExpenseDraftFailure).error.code,
          ExpenseDraftErrorCode.missingField,
        );
      }
    });

    test('geçersiz type değerini reddeder', () {
      const raw = '{"type": "transfer", "amount": 100}';
      final result = parseAndValidateDraft(
        rawResponse: raw,
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );

      expect(result, isA<ExpenseDraftFailure>());
      expect(
        (result as ExpenseDraftFailure).error.code,
        ExpenseDraftErrorCode.invalidType,
      );
    });

    test('metin olarak gelen Türkçe ve standart tutarları çözümler', () {
      final cases = <String, double>{
        '"320,00"': 320.0,
        '"1.234,50"': 1234.5,
        '"320.50"': 320.5,
        '"150"': 150.0,
        '"1.000"': 1000.0,
      };

      for (final entry in cases.entries) {
        final raw =
            '{"type": "expense", "amount": ${entry.key}, "category": "Market"}';
        final result = parseAndValidateDraft(
          rawResponse: raw,
          today: today,
          categoriesByType: categories,
          source: TxSource.receipt,
        );

        expect(result, isA<ExpenseDraftSuccess>(), reason: entry.key);
        final draft = (result as ExpenseDraftSuccess).draft;
        expect(draft.amountTl, closeTo(entry.value, 0.0001));
      }
    });

    test('sıfır, negatif, NaN, sonsuz veya metin çöpü tutarları reddeder', () {
      const badAmounts = [
        '0',
        '-50',
        '-0.01',
        '"0,00"',
        '"-10,50"',
        '"abc"',
        '"NaN"',
        '"Infinity"',
        '""',
        'true',
      ];

      for (final amountJson in badAmounts) {
        final raw = '{"type": "expense", "amount": $amountJson}';
        final result = parseAndValidateDraft(
          rawResponse: raw,
          today: today,
          categoriesByType: categories,
          source: TxSource.chat,
        );

        expect(result, isA<ExpenseDraftFailure>(), reason: amountJson);
        expect(
          (result as ExpenseDraftFailure).error.code,
          ExpenseDraftErrorCode.invalidAmount,
        );
      }

      for (final badNum in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final result = validateDraftMap(
          map: {'type': 'expense', 'amount': badNum},
          today: today,
          categoriesByType: categories,
          source: TxSource.chat,
        );

        expect(result, isA<ExpenseDraftFailure>(), reason: '$badNum');
        expect(
          (result as ExpenseDraftFailure).error.code,
          ExpenseDraftErrorCode.invalidAmount,
        );
      }
    });

    test(
      'bozuk veya eksik tarihte bugünü kullanır ve usedDefaultDate=true',
      () {
        const badDates = [
          '{"type": "expense", "amount": 50, "date": "2026-02-30"}',
          '{"type": "expense", "amount": 50, "date": "26.11.2026"}',
          '{"type": "expense", "amount": 50, "date": "dün"}',
          '{"type": "expense", "amount": 50, "date": null}',
          '{"type": "expense", "amount": 50}',
        ];

        for (final raw in badDates) {
          final result = parseAndValidateDraft(
            rawResponse: raw,
            today: today,
            categoriesByType: categories,
            source: TxSource.chat,
          );

          expect(result, isA<ExpenseDraftSuccess>(), reason: raw);
          final draft = (result as ExpenseDraftSuccess).draft;
          expect(draft.date, expectedToday);
          expect(draft.usedDefaultDate, isTrue);
        }
      },
    );

    test('bilinmeyen kategoride aynı türdeki Diğer kategorisine düşer', () {
      const raw = '''
{"type": "expense", "amount": 75, "category": "Kripto", "date": "2026-11-26"}
''';

      final result = parseAndValidateDraft(
        rawResponse: raw,
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );

      expect(result, isA<ExpenseDraftSuccess>());
      final draft = (result as ExpenseDraftSuccess).draft;
      expect(draft.categoryName, 'Diğer');
      expect(draft.usedFallbackCategory, isTrue);
    });

    test(
      'Türkçe büyük/küçük harf farkında foldTr ile kategoriyi eşleştirir',
      () {
        const cases = [
          ('expense', 'SAĞLIK', 'Sağlık'),
          ('expense', 'ULAŞIM', 'Ulaşım'),
          ('expense', 'yeme-içme', 'Yeme-İçme'),
          ('income', 'MAAŞ', 'Maaş'),
        ];

        for (final (typeStr, rawCat, expectedCat) in cases) {
          final raw =
              '{"type": "$typeStr", "amount": 100, "category": "$rawCat"}';
          final result = parseAndValidateDraft(
            rawResponse: raw,
            today: today,
            categoriesByType: categories,
            source: TxSource.chat,
          );

          expect(result, isA<ExpenseDraftSuccess>(), reason: rawCat);
          final draft = (result as ExpenseDraftSuccess).draft;
          expect(draft.categoryName, expectedCat);
          expect(draft.usedFallbackCategory, isFalse);
        }
      },
    );

    test('tür uyumsuz kategoriyi reddedip aynı türdeki Diğer\'e düşürür', () {
      // Gelir işleminde gider kategorisi "Market" gelirse "Diğer" olmalı.
      const incomeWithExpenseCat = '''
{"type": "income", "amount": 500, "category": "Market", "date": "2026-11-26"}
''';
      final incomeRes = parseAndValidateDraft(
        rawResponse: incomeWithExpenseCat,
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );
      expect(incomeRes, isA<ExpenseDraftSuccess>());
      final incomeDraft = (incomeRes as ExpenseDraftSuccess).draft;
      expect(incomeDraft.type, TxType.income);
      expect(incomeDraft.categoryName, 'Diğer');
      expect(incomeDraft.usedFallbackCategory, isTrue);

      // Gider işleminde gelir kategorisi "Maaş" gelirse "Diğer" olmalı.
      const expenseWithIncomeCat = '''
{"type": "expense", "amount": 500, "category": "Maaş", "date": "2026-11-26"}
''';
      final expenseRes = parseAndValidateDraft(
        rawResponse: expenseWithIncomeCat,
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );
      expect(expenseRes, isA<ExpenseDraftSuccess>());
      final expenseDraft = (expenseRes as ExpenseDraftSuccess).draft;
      expect(expenseDraft.type, TxType.expense);
      expect(expenseDraft.categoryName, 'Diğer');
      expect(expenseDraft.usedFallbackCategory, isTrue);
    });

    test(
      'items listesini ayrıştırır, varsayılan miktar atar ve bozukları eler',
      () {
        const raw = '''
{
  "type": "expense",
  "amount": 145.5,
  "category": "Market",
  "date": "2026-11-26",
  "items": [
    {"name": "Peynir", "quantity": 1.5, "price": "120,50"},
    {"name": "Su", "price": 25},
    {"name": "", "quantity": 1, "price": 10},
    {"name": "Bozuk Fiyat", "quantity": 1, "price": -5},
    "geçersiz öğe"
  ]
}
''';

        final result = parseAndValidateDraft(
          rawResponse: raw,
          today: today,
          categoriesByType: categories,
          source: TxSource.receipt,
        );

        expect(result, isA<ExpenseDraftSuccess>());
        final draft = (result as ExpenseDraftSuccess).draft;
        expect(draft.items, const [
          ParsedReceiptItem(name: 'Peynir', quantity: 1.5, priceTl: 120.5),
          ParsedReceiptItem(name: 'Su', quantity: 1.0, priceTl: 25.0),
        ]);
      },
    );
  });
}
