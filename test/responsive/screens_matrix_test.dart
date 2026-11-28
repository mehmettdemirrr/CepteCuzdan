// Her ekran beş durumda (dikey, küçük, yatay, geniş, 2x yazı) taşmadan
// çalışmalı; yatayda içerik soldaki çentik payının altında kalmamalı.
import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_screen.dart';
import 'package:cepte_cuzdan/features/reports/report_screen.dart';
import 'package:cepte_cuzdan/features/settings/budget_settings_screen.dart';
import 'package:cepte_cuzdan/features/settings/settings_screen.dart';
import 'package:cepte_cuzdan/features/transactions/category_management_screen.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_form_screen.dart';
import 'package:cepte_cuzdan/features/transactions/transactions_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

TransactionRecord _tx(
  int amount, {
  int category = 1,
  TxType type = TxType.expense,
  String? merchant,
  DateTime? date,
  String? note,
}) => TransactionRecord(
  type: type,
  amount: amount,
  categoryId: category,
  date: date ?? _today,
  merchant: merchant,
  note: note,
  source: TxSource.manual,
  createdAt: _now,
);

/// Gelir, üç kategoride gider, genel bütçe ve %90'daki Market limiti.
Future<TestDeps> _fullData() async {
  final d = TestDeps();
  final month = monthKey(_today);
  await d.txs.add(_tx(4523050, category: 8, type: TxType.income));
  await d.txs.add(_tx(912345, merchant: 'Migros Ataşehir Şubesi'));
  await d.txs.add(_tx(450000, category: 2, merchant: 'İstanbulkart dolum'));
  await d.txs.add(
    _tx(
      235075,
      category: 3,
      merchant: 'Elektrik faturası',
      note: 'Kasım ayı',
      date: _today.subtract(const Duration(days: 8)),
    ),
  );
  await d.budgets.upsert(Budget(month: month, limitAmount: 2500000));
  await d.budgets.upsert(
    Budget(categoryId: 1, month: month, limitAmount: 1000000),
  );
  return d;
}

/// Çizim hatası yoksa geçer; varsa hangi widget'ın taştığını gösterir.
void _expectNoError(WidgetTester t) {
  final e = t.takeException();
  if (e == null) return;
  final detail = e is FlutterError ? e.toStringDeep() : '$e';
  fail('Çizim hatası: $detail');
}

/// Bulucu görünene kadar ilk kaydırılabilir alanı kaydırır.
Future<void> _scrollTo(WidgetTester t, Finder f) async {
  if (f.hitTestable().evaluate().isNotEmpty) return;
  await t.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  // Kenarda yarım görünüyorsa tamamen görünür yap.
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
}

/// Öğe ekranın güvenli alanının içinde (çentik / durum çubuğu payı dışında).
void _expectInSafeArea(WidgetTester t, Finder f, ScreenCase s) {
  final r = t.getRect(f.first);
  expect(r.left, greaterThanOrEqualTo(s.padding.left), reason: 'sol çentik');
  expect(r.right, lessThanOrEqualTo(s.size.width - s.padding.right));
}

void main() {
  testScreens('Ana Sayfa dolu veriyle taşmaz', (t, s) async {
    await pumpApp(
      t,
      const DashboardScreen(),
      deps: await _fullData(),
      screen: s,
    );
    await t.pumpAndSettle();
    _expectNoError(t);
    for (final text in ['Kalan Bütçe', 'Harcama dağılımı', 'Son işlemler']) {
      await _scrollTo(t, find.text(text));
      expect(find.text(text), findsOneWidget);
    }
    _expectInSafeArea(t, find.byType(Card), s);
    _expectNoError(t);
  });

  testScreens('İşlemler listesi taşmaz', (t, s) async {
    await pumpApp(
      t,
      const TransactionsScreen(),
      deps: await _fullData(),
      screen: s,
    );
    await t.pumpAndSettle();
    _expectNoError(t);
    expect(find.text('Migros Ataşehir Şubesi'), findsOneWidget);
    _expectInSafeArea(t, find.byType(ListTile), s);
    expect(find.text('İşlem ekle'), findsOneWidget);
  });

  testScreens('İşlem formu taşmaz ve Kaydet erişilebilir', (t, s) async {
    await pumpApp(
      t,
      const TransactionFormScreen(),
      deps: TestDeps(),
      screen: s,
    );
    await t.pumpAndSettle();
    _expectNoError(t);
    _expectInSafeArea(t, find.byKey(const Key('amount-field')), s);
    await _scrollTo(t, find.text('Kaydet'));
    expect(find.text('Kaydet').hitTestable(), findsOneWidget);
  });

  testScreens('İşlem formu klavye açıkken de Kaydet erişilebilir', (
    t,
    s,
  ) async {
    await pumpApp(
      t,
      const TransactionFormScreen(),
      deps: TestDeps(),
      screen: s,
    );
    // Klavye ekranın yarısını kaplar.
    t.view.viewInsets = FakeViewPadding(
      bottom: s.size.height * 0.5 * t.view.devicePixelRatio,
    );
    await t.pumpAndSettle();
    _expectNoError(t);
    await _scrollTo(t, find.text('Kaydet'));
    expect(find.text('Kaydet').hitTestable(), findsOneWidget);
  });

  testScreens('Raporlar dolu veriyle taşmaz', (t, s) async {
    await pumpApp(t, const ReportScreen(), deps: await _fullData(), screen: s);
    await t.pumpAndSettle();
    _expectNoError(t);
    await _scrollTo(t, find.byType(BarChart));
    expect(find.byType(BarChart), findsOneWidget);
    await _scrollTo(t, find.byKey(const Key('breakdown-total')));
    _expectInSafeArea(t, find.byKey(const Key('breakdown-total')), s);
    await _scrollTo(t, find.text('Döküm'));
    _expectNoError(t);
  });

  testScreens('Ayarlar taşmaz', (t, s) async {
    await pumpApp(t, const SettingsScreen(), deps: TestDeps(), screen: s);
    await t.pumpAndSettle();
    _expectNoError(t);
    _expectInSafeArea(t, find.text('Tema'), s);
    await _scrollTo(t, find.text('Verileri sıfırla'));
    _expectNoError(t);
  });

  testScreens('Bütçe limitleri taşmaz', (t, s) async {
    await pumpApp(
      t,
      const BudgetSettingsScreen(),
      deps: await _fullData(),
      screen: s,
    );
    await t.pumpAndSettle();
    _expectNoError(t);
    _expectInSafeArea(t, find.byKey(const Key('budget-overall')), s);
    await _scrollTo(t, find.byKey(const Key('budget-cat-7')));
    _expectNoError(t);
  });

  testScreens('Kategori yönetimi ve kategori sayfası taşmaz', (t, s) async {
    await pumpApp(
      t,
      const CategoryManagementScreen(),
      deps: TestDeps(),
      screen: s,
    );
    await t.pumpAndSettle();
    _expectNoError(t);
    _expectInSafeArea(t, find.byType(ListTile), s);

    await t.tap(find.text('Kategori ekle'));
    await t.pumpAndSettle();
    _expectNoError(t);
    _expectInSafeArea(t, find.byKey(const Key('category-name-field')), s);
    await t.scrollUntilVisible(
      find.text('Kaydet'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Kaydet').hitTestable(), findsOneWidget);
    _expectNoError(t);
  });

  testWidgets('geniş ekranda Ana Sayfa iki sütun', (t) async {
    await pumpApp(
      t,
      const DashboardScreen(),
      deps: await _fullData(),
      screen: ScreenCase.tablet,
    );
    await t.pumpAndSettle();
    final remaining = t.getRect(find.text('Kalan Bütçe'));
    final pie = t.getRect(find.text('Harcama dağılımı'));
    expect(pie.left, greaterThan(remaining.right));
    expect(t.getRect(find.byType(PieChart)).top, lessThan(400));
  });

  testWidgets('geniş ekranda Raporlarda grafik ve döküm yan yana', (t) async {
    await pumpApp(
      t,
      const ReportScreen(),
      deps: await _fullData(),
      screen: ScreenCase.tablet,
    );
    await t.pumpAndSettle();
    final chart = t.getRect(find.byType(BarChart));
    final total = t.getRect(find.byKey(const Key('breakdown-total')));
    expect(total.left, greaterThan(chart.right));
  });

  testWidgets('yatayda grafik yükseklikleri sınırlı', (t) async {
    final d = await _fullData();
    await pumpApp(
      t,
      const DashboardScreen(),
      deps: d,
      screen: ScreenCase.landscape,
    );
    await t.pumpAndSettle();
    await _scrollTo(t, find.byType(PieChart));
    expect(t.getSize(find.byType(PieChart)).height, lessThanOrEqualTo(144));

    await pumpApp(
      t,
      const ReportScreen(),
      deps: d,
      screen: ScreenCase.landscape,
    );
    await t.pumpAndSettle();
    await _scrollTo(t, find.byType(BarChart));
    expect(t.getSize(find.byType(BarChart)).height, lessThanOrEqualTo(144));
  });
}
