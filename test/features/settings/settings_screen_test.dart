import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/ui/widgets/amount_text.dart';
import 'package:cepte_cuzdan/features/settings/budget_settings_screen.dart';
import 'package:cepte_cuzdan/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

final now = DateTime.now();
String get thisMonth => '${now.year}-${now.month.toString().padLeft(2, '0')}';

TransactionRecord tx(int amount) => TransactionRecord(
  type: TxType.expense,
  amount: amount,
  categoryId: 1,
  date: now,
  source: TxSource.manual,
  createdAt: now,
);

void main() {
  group('Ayarlar', () {
    testWidgets('Koyu tema seçimi kaydedilir', (t) async {
      await pumpApp(t, const SettingsScreen(), deps: TestDeps());
      await t.tap(find.text('Koyu'));
      await t.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    testWidgets('para birimi görünümü tutarlara yansır', (t) async {
      await pumpApp(t, const SettingsScreen(), deps: TestDeps());
      await t.tap(find.text('1.234,50 TL'));
      await t.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('currency_style'), 'code');
    });

    testWidgets('Vazgeç denince veriler silinmez', (t) async {
      final d = TestDeps();
      await d.txs.add(tx(5000));
      await pumpApp(t, const SettingsScreen(), deps: d);
      await t.scrollUntilVisible(find.text('Verileri sıfırla'), 100);
      await t.tap(find.text('Verileri sıfırla'));
      await t.pumpAndSettle();
      expect(find.textContaining('geri alınamaz'), findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(d.txs.records, hasLength(1));
    });

    testWidgets('Sıfırla onaylanınca veriler ve uyarı kayıtları silinir', (
      t,
    ) async {
      final d = TestDeps(
        initialPrefs: {'alert_2026-11_1_warning': true, 'theme_mode': 'dark'},
      );
      await d.txs.add(tx(5000));
      await d.budgets.upsert(Budget(month: thisMonth, limitAmount: 100000));
      await pumpApp(t, const SettingsScreen(), deps: d);
      await t.scrollUntilVisible(find.text('Verileri sıfırla'), 100);
      await t.tap(find.text('Verileri sıfırla'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sıfırla'));
      await t.pumpAndSettle();

      expect(d.txs.records, isEmpty);
      expect(await d.budgets.forMonth(thisMonth), isEmpty);
      expect(await d.categories.all(), hasLength(9));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('alert_2026-11_1_warning'), isFalse);
      expect(prefs.getString('theme_mode'), 'dark', reason: 'ayarlar korunur');
      expect(find.text('Veriler sıfırlandı'), findsOneWidget);
    });
  });

  group('Bütçe limitleri', () {
    testWidgets('genel bütçe ve kategori limiti kaydedilir', (t) async {
      final d = TestDeps();
      await pumpApp(t, const BudgetSettingsScreen(), deps: d);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('budget-overall')), '5.000');
      await t.enterText(find.byKey(const Key('budget-cat-1')), '1000');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();

      final list = await d.budgets.forMonth(thisMonth);
      expect(list, hasLength(2));
      expect(list.firstWhere((b) => b.isOverall).limitAmount, 500000);
      expect(list.firstWhere((b) => b.categoryId == 1).limitAmount, 100000);
      expect(find.text('Bütçe kaydedildi'), findsOneWidget);
    });

    testWidgets('mevcut limit alana yazılır, alan boşaltılınca silinir', (
      t,
    ) async {
      final d = TestDeps();
      await d.budgets.upsert(
        Budget(categoryId: 1, month: thisMonth, limitAmount: 75000),
      );
      await pumpApp(t, const BudgetSettingsScreen(), deps: d);
      await t.pumpAndSettle();
      expect(find.text('750,00'), findsOneWidget);

      await t.enterText(find.byKey(const Key('budget-cat-1')), '');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(await d.budgets.forMonth(thisMonth), isEmpty);
    });

    testWidgets('geçersiz tutar kaydedilmez', (t) async {
      final d = TestDeps();
      await pumpApp(t, const BudgetSettingsScreen(), deps: d);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('budget-overall')), 'abc');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(find.text('Geçerli bir tutar giriniz'), findsOneWidget);
      expect(await d.budgets.forMonth(thisMonth), isEmpty);
    });

    testWidgets('kaydedilen limit aşılmışsa bildirim gelir', (t) async {
      final d = TestDeps();
      await d.txs.add(tx(90000));
      await pumpApp(t, const BudgetSettingsScreen(), deps: d);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('budget-cat-1')), '500');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(d.notifier.shown.single.title, 'Bütçe aşıldı');
    });
  });

  testWidgets('AmountText kayıtlı para birimi görünümünü kullanır', (t) async {
    await pumpApp(
      t,
      const AmountText(123450),
      deps: TestDeps(initialPrefs: {'currency_style': 'code'}),
    );
    expect(find.text('1.234,50 TL'), findsOneWidget);
  });
}
