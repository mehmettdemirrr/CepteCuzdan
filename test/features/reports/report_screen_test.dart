import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/reports/report_screen.dart';
import 'package:cepte_cuzdan/features/settings/settings_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final today = DateTime.now();
final thisWeek = weekOf(today);
final lastWeekDay = thisWeek.start.subtract(const Duration(days: 3));

TransactionRecord tx(
  int amount,
  DateTime date, {
  int category = 1,
  String? merchant,
}) => TransactionRecord(
  type: TxType.expense,
  amount: amount,
  categoryId: category,
  date: date,
  merchant: merchant,
  source: TxSource.manual,
  createdAt: date,
);

void main() {
  testWidgets('Ayarlar düğmesi Ayarlar ekranını açar', (t) async {
    await pumpApp(t, const ReportScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Ayarlar'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('boş dönemde boş durum gösterir, grafik çizmez', (t) async {
    await pumpApp(t, const ReportScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    expect(find.text('Bu dönemde harcama yok'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('kategori dökümünde değişim rozetleri gösterir', (t) async {
    final d = TestDeps();
    await d.txs.add(
      tx(12000, thisWeek.start, merchant: 'Migros'),
    ); // Market bu hafta
    await d.txs.add(tx(10000, lastWeekDay)); // Market geçen hafta
    await d.txs.add(tx(5000, thisWeek.start, category: 2)); // Ulaşım yeni
    await pumpApp(t, const ReportScreen(), deps: d);
    await t.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('▲ %20'), findsOneWidget);
    expect(find.text('Yeni'), findsOneWidget);
    expect(find.text('₺170,00'), findsWidgets); // toplam gider
    await t.scrollUntilVisible(find.text('Migros'), 200);
    expect(find.text('Migros'), findsOneWidget);
  });

  testWidgets(
    'Aylık seçilince ay etiketi gösterilir, ok ile önceki aya geçilir',
    (t) async {
      await pumpApp(t, const ReportScreen(), deps: TestDeps());
      await t.pumpAndSettle();
      await t.tap(find.text('Aylık'));
      await t.pumpAndSettle();
      expect(find.text(rangeLabelForTest(monthOf(today))), findsOneWidget);

      await t.tap(find.byKey(const Key('report-prev')));
      await t.pumpAndSettle();
      final prev = monthOf(DateTime(today.year, today.month - 1, 1));
      expect(find.text(rangeLabelForTest(prev)), findsOneWidget);
    },
  );
}

/// Ay etiketi: "Kasım 2026".
String rangeLabelForTest(DateRange r) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${months[r.start.month - 1]} ${r.start.year}';
}
