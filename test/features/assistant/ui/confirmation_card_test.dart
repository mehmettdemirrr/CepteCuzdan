import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/ui/app_theme.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/parsed_expense_draft.dart';
import 'package:cepte_cuzdan/features/assistant/state/assistant_controller.dart';
import 'package:cepte_cuzdan/features/assistant/ui/confirmation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../helpers/pump_app.dart';

PendingDraft _samplePending({
  bool usedDefaultDate = false,
  bool usedDefaultCategory = false,
  bool isSaved = false,
}) {
  return PendingDraft(
    draftId: 'draft-1',
    isSaved: isSaved,
    draft: ParsedExpenseDraft(
      type: TxType.expense,
      amountTl: 320.00,
      merchant: 'Migros',
      date: DateTime(2026, 11, 26),
      categoryName: 'Market',
      source: TxSource.receipt,
      usedDefaultDate: usedDefaultDate,
      usedFallbackCategory: usedDefaultCategory,
      items: const [
        ParsedReceiptItem(name: 'Süt 1L', quantity: 2, priceTl: 70.0),
        ParsedReceiptItem(name: 'Peynir', quantity: 1, priceTl: 250.0),
      ],
    ),
  );
}

void main() {
  testWidgets(
    'ConfirmationCard alanları, kalemleri, uyarıları ve >=48dp düğmeleri gösterir',
    (t) async {
      var saveTapped = 0;
      var editTapped = 0;
      var cancelTapped = 0;

      await pumpApp(
        t,
        ConfirmationCard(
          pending: _samplePending(
            usedDefaultDate: true,
            usedDefaultCategory: true,
          ),
          isSaving: false,
          onSave: () => saveTapped++,
          onEdit: () => editTapped++,
          onCancel: () => cancelTapped++,
        ),
      );
      await t.pumpAndSettle();

      expect(find.textContaining('320,00'), findsOneWidget);
      expect(find.text('Migros'), findsOneWidget);
      expect(find.text('Market'), findsOneWidget);
      expect(find.textContaining('Süt 1L'), findsOneWidget);
      expect(find.textContaining('Tarih okunamadı'), findsOneWidget);
      expect(find.textContaining('Diğer seçildi'), findsOneWidget);

      for (final label in ['Kaydet', 'Düzenle', 'İptal']) {
        final btn = find.widgetWithText(FilledButton, label);
        final target = btn.evaluate().isNotEmpty
            ? btn
            : find.widgetWithText(OutlinedButton, label).evaluate().isNotEmpty
            ? find.widgetWithText(OutlinedButton, label)
            : find.widgetWithText(TextButton, label);
        expect(target, findsOneWidget);
        final size = t.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }

      await t.ensureVisible(find.text('Kaydet'));
      await t.tap(find.text('Kaydet'));
      await t.ensureVisible(find.text('Düzenle'));
      await t.tap(find.text('Düzenle'));
      await t.ensureVisible(find.text('İptal'));
      await t.tap(find.text('İptal'));
      expect(saveTapped, 1);
      expect(editTapped, 1);
      expect(cancelTapped, 1);
    },
  );

  testWidgets(
    'Kaydedildi durumunda Kaydet gizlenir ve Kaydedildi etiketi görünür',
    (t) async {
      await pumpApp(
        t,
        ConfirmationCard(
          pending: _samplePending(isSaved: true),
          isSaving: false,
          onSave: () {},
          onEdit: () {},
          onCancel: () {},
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Kaydedildi'), findsOneWidget);
      expect(find.text('Kaydet'), findsNothing);
    },
  );

  testWidgets('yatay 800x360 ve 2.0x büyük yazıda taşma yok', (t) async {
    await initializeDateFormatting('tr_TR');
    Intl.defaultLocale = 'tr_TR';

    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 360),
          textScaler: TextScaler.linear(2.0),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ConfirmationCard(
              pending: _samplePending(usedDefaultDate: true),
              isSaving: false,
              saveErrorMessage: 'Kayıt hatası oluştu.',
              onSave: () {},
              onEdit: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.text('Kayıt hatası oluştu.'), findsOneWidget);
  });
}
