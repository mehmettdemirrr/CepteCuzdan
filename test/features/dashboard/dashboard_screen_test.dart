import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_screen.dart';
import 'package:cepte_cuzdan/features/settings/budget_settings_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final now = DateTime.now();

TransactionRecord tx(
  int amount, {
  int category = 1,
  TxType type = TxType.expense,
  String? merchant,
}) => TransactionRecord(
  type: type,
  amount: amount,
  categoryId: category,
  date: now,
  merchant: merchant,
  source: TxSource.manual,
  createdAt: now,
);

void main() {
  testWidgets('bütçe yoksa Bütçe belirle düğmesi limit ekranını açar', (
    t,
  ) async {
    await pumpApp(t, const DashboardScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    await t.tap(find.text('Bütçe belirle'));
    await t.pumpAndSettle();
    expect(find.byType(BudgetSettingsScreen), findsOneWidget);
  });

  testWidgets('boş veride çökmez ve boş durumları gösterir', (t) async {
    await pumpApp(t, const DashboardScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    expect(find.text('Bu ay henüz harcama yok'), findsOneWidget);
    expect(find.text('Bütçe tanımlanmadı'), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
    expect(find.text('Henüz işlem yok'), findsOneWidget);
  });

  testWidgets('kartlar ayın toplamlarını ve kalan bütçeyi gösterir', (t) async {
    final d = TestDeps();
    await d.txs.add(tx(500000, category: 8, type: TxType.income));
    await d.txs.add(tx(32000, merchant: 'Migros'));
    await d.txs.add(tx(30000, category: 2, merchant: 'Taksi'));
    await d.budgets.upsert(Budget(month: monthKey(now), limitAmount: 100000));
    await pumpApp(t, const DashboardScreen(), deps: d);
    await t.pumpAndSettle();

    expect(find.text('₺5.000,00'), findsOneWidget); // gelir
    expect(find.text('₺620,00'), findsWidgets); // gider (kart + pasta toplamı)
    expect(find.text('₺380,00'), findsOneWidget); // kalan
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Gelirinin %12 kadarını harcadın'), findsOneWidget);
    // Durum çubuğu payıyla son işlemler ilk ekranın altında kalır.
    await t.scrollUntilVisible(find.text('Migros'), 200);
    expect(find.text('Migros'), findsOneWidget);
  });

  testWidgets('bütçe aşılınca kalan eksi gösterilir', (t) async {
    final d = TestDeps();
    await d.txs.add(tx(150000));
    await d.budgets.upsert(Budget(month: monthKey(now), limitAmount: 100000));
    await pumpApp(t, const DashboardScreen(), deps: d);
    await t.pumpAndSettle();
    expect(find.text('-₺500,00'), findsOneWidget);
  });

  testWidgets('limitine yaklaşan ve aşan kategoriler için rozet gösterir', (
    t,
  ) async {
    final d = TestDeps();
    await d.txs.add(tx(9000)); // Market
    await d.txs.add(tx(12000, category: 2)); // Ulaşım
    await d.txs.add(tx(1000, category: 3)); // Faturalar
    final month = monthKey(now);
    await d.budgets.upsert(
      Budget(categoryId: 1, month: month, limitAmount: 10000),
    );
    await d.budgets.upsert(
      Budget(categoryId: 2, month: month, limitAmount: 10000),
    );
    await d.budgets.upsert(
      Budget(categoryId: 3, month: month, limitAmount: 10000),
    );
    await pumpApp(t, const DashboardScreen(), deps: d);
    await t.pumpAndSettle();

    expect(find.text('Market %90'), findsOneWidget);
    expect(find.text('Ulaşım aşıldı'), findsOneWidget);
    expect(find.textContaining('Faturalar %'), findsNothing);
  });
}
