// Branch incelemesinde bulunan hataların regresyon testleri.
import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/category.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_screen.dart';
import 'package:cepte_cuzdan/features/reports/report_provider.dart';
import 'package:cepte_cuzdan/features/reports/report_screen.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_repositories.dart';
import 'helpers/pump_app.dart';

final now = DateTime.now();

TransactionRecord tx(int amount, int category) => TransactionRecord(
  type: TxType.expense,
  amount: amount,
  categoryId: category,
  date: now,
  source: TxSource.manual,
  createdAt: now,
);

Future<int> addKitap(TestDeps d) => d.categories.add(
  const Category(name: 'Kitap', type: TxType.expense, color: 0, icon: 'school'),
);

void main() {
  testWidgets(
    'kategori silinince işlemler listesi işlemi Diğer altında gösterir',
    (t) async {
      final d = TestDeps();
      final kitap = await addKitap(d);
      await d.txs.add(tx(10000, kitap));
      await pumpApp(t, const TransactionsScreen(), deps: d);
      await t.pumpAndSettle();
      expect(find.text('Kitap'), findsOneWidget);

      await t
          .element(find.byType(TransactionsScreen))
          .read<CategoryProvider>()
          .delete(kitap);
      await t.pumpAndSettle();

      expect(find.text('Kategori yok'), findsNothing);
      expect(find.text('Diğer'), findsOneWidget);
    },
  );

  testWidgets(
    'rapor filtresindeki kategori silinince ekran çökmez, filtre temizlenir',
    (t) async {
      final d = TestDeps();
      final kitap = await addKitap(d);
      await d.txs.add(tx(10000, kitap));
      await pumpApp(t, const ReportScreen(), deps: d);
      await t.pumpAndSettle();
      final ctx = t.element(find.byType(ReportScreen));
      await ctx.read<ReportProvider>().setCategory(kitap);
      await t.pumpAndSettle();

      await ctx.read<CategoryProvider>().delete(kitap);
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(ctx.read<ReportProvider>().categoryId, isNull);
      expect(find.text('Tüm kategoriler'), findsOneWidget);
      expect(find.text('Bu dönemde harcama yok'), findsNothing);
    },
  );

  testWidgets('Kalan Bütçe kartı tutar görünümü ayarına uyar', (t) async {
    final d = TestDeps(initialPrefs: {'currency_style': 'code'});
    await d.txs.add(tx(62000, 1));
    await d.budgets.upsert(Budget(month: monthKey(now), limitAmount: 100000));
    await pumpApp(t, const DashboardScreen(), deps: d);
    await t.pumpAndSettle();
    expect(find.text('380,00 TL'), findsOneWidget);
    expect(find.text('620,00 TL / 1.000,00 TL'), findsOneWidget);
    expect(find.textContaining('₺'), findsNothing);
  });

  testWidgets(
    'özel aralık seçiliyken aralık etiketine dokununca tarih seçici açılır',
    (t) async {
      await pumpApp(t, const ReportScreen(), deps: TestDeps());
      await t.pumpAndSettle();
      final ctx = t.element(find.byType(ReportScreen));
      await ctx.read<ReportProvider>().setCustomRange(
        DateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 14)),
      );
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('report-range')));
      await t.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    },
  );

  testWidgets('boş dönemde toplam kartında "Yeni" yazmaz', (t) async {
    await pumpApp(t, const ReportScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    expect(find.text('Yeni'), findsNothing);
  });

  test(
    'bütçe kontrolü hata verse de kaydedilen işlem başarılı döner',
    () async {
      final r = FakeRepos();
      final p = TransactionProvider(
        r.txs,
        onChanged: (_) async => throw StateError('bildirim hatası'),
      );
      final id = await p.add(tx(5000, 1));
      expect(await r.txs.getById(id), isNotNull);
      expect(p.revision, 1);
      await p.delete(id);
      expect(p.revision, 2);
    },
  );
}
