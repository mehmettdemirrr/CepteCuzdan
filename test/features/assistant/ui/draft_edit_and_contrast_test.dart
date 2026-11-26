import 'dart:math' as math;

import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/ui/app_theme.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/parsed_expense_draft.dart';
import 'package:cepte_cuzdan/features/assistant/ui/draft_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final bright = math.max(l1, l2);
  final dark = math.min(l1, l2);
  return (bright + 0.05) / (dark + 0.05);
}

void main() {
  const categoriesByType = {
    TxType.expense: ['Market', 'Ulaşım', 'Diğer'],
    TxType.income: ['Maaş', 'Diğer'],
  };

  final initialDraft = ParsedExpenseDraft(
    type: TxType.expense,
    amountTl: 120.00,
    merchant: 'BİM',
    date: DateTime(2026, 11, 26),
    categoryName: 'Market',
    source: TxSource.receipt,
    items: const [
      ParsedReceiptItem(name: 'Kefir', quantity: 1, priceTl: 22.00),
    ],
    usedDefaultDate: false,
    usedFallbackCategory: false,
  );

  testWidgets(
    'DraftEditSheet geçersiz tutarı reddeder, geçerli düzenlemeyi döner',
    (t) async {
      ParsedExpenseDraft? result;

      await pumpApp(
        t,
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showDraftEditSheet(
                  context,
                  initial: initialDraft,
                  categoriesByType: categoriesByType,
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();

      // Geçersiz tutar (0) reddedilir.
      final amountField = find.widgetWithText(TextFormField, '120,00');
      await t.enterText(amountField, '0');
      await t.ensureVisible(find.text('Taslağı güncelle'));
      await t.tap(find.text('Taslağı güncelle'));
      await t.pumpAndSettle();

      expect(find.textContaining('pozitif bir tutar'), findsOneWidget);
      expect(result, isNull);

      // Geçerli tutar ve işletme ile günceller.
      await t.enterText(find.widgetWithText(TextFormField, '0'), '145,50');
      await t.enterText(find.widgetWithText(TextFormField, 'BİM'), 'Migros');
      await t.ensureVisible(find.text('Taslağı güncelle'));
      await t.tap(find.text('Taslağı güncelle'));
      await t.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.amountTl, 145.50);
      expect(result!.merchant, 'Migros');
      expect(result!.source, TxSource.receipt);
      expect(result!.items, hasLength(1));
    },
  );

  test('Asistan tema renk çiftleri açık ve koyu temada WCAG AA (>=4.5:1) kontrast sağlar', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final s = theme.colorScheme;
      final pairs = <(String, Color, Color)>[
        ('primaryContainer', s.primaryContainer, s.onPrimaryContainer),
        ('surfaceContainerHighest', s.surfaceContainerHighest, s.onSurface),
        ('surfaceContainerHigh', s.surfaceContainerHigh, s.onSurface),
        ('errorContainer', s.errorContainer, s.onErrorContainer),
        ('tertiaryContainer', s.tertiaryContainer, s.onTertiaryContainer),
      ];

      for (final (name, bg, fg) in pairs) {
        final ratio = _contrastRatio(bg, fg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${theme.brightness.name} tema $name kontrastı yetersiz: ${ratio.toStringAsFixed(2)}',
        );
      }
    }
  });
}
