// Erişilebilirlik: dokunma alanı (48 dp), etiketli dokunma hedefleri, metin
// kontrastı (açık ve koyu tema) ve ekran okuyucu etiketleri.
import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/format/money.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/ui/widgets/amount_text.dart';
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
}) => TransactionRecord(
  type: type,
  amount: amount,
  categoryId: category,
  date: date ?? _today,
  merchant: merchant,
  source: TxSource.manual,
  createdAt: _now,
);

Future<TestDeps> _fullData() async {
  final d = TestDeps();
  final month = monthKey(_today);
  await d.txs.add(_tx(500000, category: 8, type: TxType.income));
  await d.txs.add(_tx(47000, merchant: 'Migros'));
  await d.txs.add(_tx(24000, category: 2, merchant: 'Taksi'));
  await d.txs.add(_tx(29000, category: 3));
  await d.txs.add(
    _tx(10000, date: _today.subtract(const Duration(days: 8))),
  ); // önceki dönem
  await d.budgets.upsert(Budget(month: month, limitAmount: 150000));
  await d.budgets.upsert(
    Budget(categoryId: 1, month: month, limitAmount: 50000),
  );
  return d;
}

/// Ekran adı → (ekran, veri, açıldıktan sonra yapılacak adım).
final _screens =
    <
      String,
      (
        Widget,
        Future<TestDeps> Function(),
        Future<void> Function(WidgetTester)?,
      )
    >{
      'Ana Sayfa': (const DashboardScreen(), _fullData, null),
      'İşlemler': (const TransactionsScreen(), _fullData, null),
      'İşlem formu': (
        const TransactionFormScreen(),
        () async => TestDeps(),
        null,
      ),
      'Raporlar': (const ReportScreen(), _fullData, null),
      'Ayarlar': (const SettingsScreen(), () async => TestDeps(), null),
      'Bütçe limitleri': (const BudgetSettingsScreen(), _fullData, null),
      'Kategoriler': (
        const CategoryManagementScreen(),
        () async => TestDeps(),
        null,
      ),
      'Kategori sayfası': (
        const CategoryManagementScreen(),
        () async => TestDeps(),
        (t) async {
          await t.tap(find.text('Kategori ekle'));
          await t.pumpAndSettle();
        },
      ),
    };

Future<void> _open(
  WidgetTester t,
  String name, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final (screen, data, after) = _screens[name]!;
  await pumpApp(t, screen, deps: await data(), themeMode: themeMode);
  await t.pumpAndSettle();
  if (after != null) await after(t);
}

void main() {
  for (final name in _screens.keys) {
    testWidgets('$name: dokunma alanı ≥ 48 dp ve etiketli', (t) async {
      final h = t.ensureSemantics();
      await _open(t, name);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final label = mode == ThemeMode.light ? 'açık' : 'koyu';
      testWidgets('$name: metin kontrastı ($label tema)', (t) async {
        final h = t.ensureSemantics();
        await _open(t, name, themeMode: mode);
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }
  }

  group('spokenAmount', () {
    test('gider, gelir ve eksi tutar', () {
      expect(spokenAmount(15000, type: TxType.expense), '150,00 lira gider');
      expect(spokenAmount(500000, type: TxType.income), '5.000,00 lira gelir');
      expect(spokenAmount(-50000), 'eksi 500,00 lira');
      expect(spokenAmount(1), '0,01 lira');
    });

    testWidgets('AmountText ekran okuyucuya sözlü tutarı verir', (t) async {
      final h = t.ensureSemantics();
      await pumpApp(t, const AmountText(15000, type: TxType.expense));
      expect(find.bySemanticsLabel('150,00 lira gider'), findsOneWidget);
      h.dispose();
    });
  });

  testWidgets('pasta grafik ekran okuyucuya özetlenir', (t) async {
    final h = t.ensureSemantics();
    await pumpApp(t, const DashboardScreen(), deps: await _fullData());
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byType(PieChart), 150);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Harcama dağılımı: Market yüzde \d+, Faturalar yüzde \d+'),
      ),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('çubuk grafik ekran okuyucuya özetlenir', (t) async {
    final h = t.ensureSemantics();
    await pumpApp(t, const ReportScreen(), deps: await _fullData());
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byType(BarChart),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Bu dönem ve önceki dönem: Market .+ lira, önceki .+ lira'),
      ),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('renk seçimi ekran okuyucuda seçili durumunu söyler', (t) async {
    final h = t.ensureSemantics();
    await _open(t, 'Kategori sayfası');
    expect(
      t.getSemantics(find.bySemanticsLabel('Renk 1')),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Renk 2')),
      isSemantics(isSelected: false),
    );

    await t.tap(find.bySemanticsLabel('Renk 2'));
    await t.pumpAndSettle();
    expect(
      t.getSemantics(find.bySemanticsLabel('Renk 2')),
      isSemantics(isSelected: true),
    );
    h.dispose();
  });
}
