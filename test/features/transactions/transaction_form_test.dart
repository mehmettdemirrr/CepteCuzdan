import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Formu bir düğmeden açar; böylece kaydedince geri dönüş test edilebilir.
Future<TestDeps> openForm(
  WidgetTester t, {
  TransactionRecord? initial,
  TestDeps? deps,
}) async {
  final d = deps ?? TestDeps();
  await pumpApp(
    t,
    Builder(
      builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(
          MaterialPageRoute<void>(
            builder: (_) => TransactionFormScreen(initial: initial),
          ),
        ),
        child: const Text('aç'),
      ),
    ),
    deps: d,
  );
  await t.tap(find.text('aç'));
  await t.pumpAndSettle();
  return d;
}

Future<void> pickCategory(WidgetTester t, String name) async {
  await t.tap(find.byKey(const Key('category-field')));
  await t.pumpAndSettle();
  await t.tap(find.text(name).last);
  await t.pumpAndSettle();
}

Future<void> save(WidgetTester t) async {
  await t.ensureVisible(find.text('Kaydet'));
  await t.tap(find.text('Kaydet'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('boş tutarla kaydetme hata gösterir', (t) async {
    final d = await openForm(t);
    await save(t);
    expect(find.text('Tutar giriniz'), findsOneWidget);
    expect(find.text('Kategori seçiniz'), findsOneWidget);
    expect(d.txs.records, isEmpty);
  });

  testWidgets('0 tutar reddedilir', (t) async {
    final d = await openForm(t);
    await t.enterText(find.byKey(const Key('amount-field')), '0');
    await save(t);
    expect(find.text('Geçerli bir tutar giriniz'), findsOneWidget);
    expect(d.txs.records, isEmpty);
  });

  testWidgets('geçerli form kuruş cinsinden manual kayıt ekler ve geri döner', (
    t,
  ) async {
    final d = await openForm(t);
    await t.enterText(find.byKey(const Key('amount-field')), '150,50');
    await pickCategory(t, 'Ulaşım');
    await t.enterText(find.byKey(const Key('merchant-field')), 'Taksi');
    await save(t);

    final tx = d.txs.records.single;
    expect(tx.amount, 15050);
    expect(tx.source, TxSource.manual);
    expect(tx.type, TxType.expense);
    expect(
      tx.categoryId,
      (await d.categories.findByName('Ulaşım', TxType.expense))!.id,
    );
    expect(tx.merchant, 'Taksi');
    expect(tx.note, isNull);
    final now = DateTime.now();
    expect(tx.date, DateTime(now.year, now.month, now.day));

    expect(find.text('aç'), findsOneWidget, reason: 'form kapanmalı');
    expect(find.text('İşlem kaydedildi'), findsOneWidget);
  });

  testWidgets('tip değişince kategori listesi değişir ve seçim sıfırlanır', (
    t,
  ) async {
    await openForm(t);
    await pickCategory(t, 'Market');
    await t.tap(find.text('Gelir'));
    await t.pumpAndSettle();
    expect(find.text('Market'), findsNothing);

    await t.tap(find.byKey(const Key('category-field')));
    await t.pumpAndSettle();
    expect(find.text('Maaş'), findsWidgets);
    expect(find.text('Market'), findsNothing);
  });

  testWidgets('tip değişince eski kategoriyle kayıt yapılmaz', (t) async {
    final d = await openForm(t);
    await t.enterText(find.byKey(const Key('amount-field')), '100');
    await pickCategory(t, 'Market');
    await t.tap(find.text('Gelir'));
    await t.pumpAndSettle();
    await save(t);
    expect(find.text('Kategori seçiniz'), findsOneWidget);
    expect(d.txs.records, isEmpty);
  });

  testWidgets(
    'düzenleme mevcut değerleri doldurur, kaynağı korur ve günceller',
    (t) async {
      final d = TestDeps();
      final id = await d.txs.add(
        TransactionRecord(
          type: TxType.expense,
          amount: 32000,
          categoryId: 1,
          date: DateTime(2026, 11, 8),
          merchant: 'Migros',
          note: 'haftalık',
          source: TxSource.receipt,
          receiptPath: '/fis.jpg',
          createdAt: DateTime(2026, 11, 8, 14),
        ),
      );
      final initial = (await d.txs.getById(id))!;
      await openForm(t, initial: initial, deps: d);

      expect(find.text('İşlemi düzenle'), findsOneWidget);
      expect(find.text('320,00'), findsOneWidget);
      expect(find.text('Migros'), findsOneWidget);

      await t.enterText(find.byKey(const Key('amount-field')), '350');
      await t.enterText(find.byKey(const Key('note-field')), '');
      await save(t);

      final u = (await d.txs.getById(id))!;
      expect(u.amount, 35000);
      expect(u.note, isNull, reason: 'boşaltılan açıklama silinmeli');
      expect(u.source, TxSource.receipt);
      expect(u.receiptPath, '/fis.jpg');
      expect(u.createdAt, DateTime(2026, 11, 8, 14));
      expect(u.date, DateTime(2026, 11, 8));
      expect(d.txs.records, hasLength(1));
    },
  );
}
