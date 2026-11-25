// İncelemenin küçük bulgularının regresyon testleri.
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_provider.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_screen.dart';
import 'package:cepte_cuzdan/features/reports/report_provider.dart';
import 'package:cepte_cuzdan/features/reports/report_screen.dart';
import 'package:cepte_cuzdan/features/settings/budget_settings_screen.dart';
import 'package:cepte_cuzdan/features/settings/data_resetter.dart';
import 'package:cepte_cuzdan/features/settings/settings_screen.dart';
import 'package:cepte_cuzdan/features/transactions/category_management_screen.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/failing_transaction_repository.dart';
import 'fakes/fake_repositories.dart';
import 'helpers/pump_app.dart';

final now = DateTime.now();

TransactionRecord tx(int amount, {String? merchant}) => TransactionRecord(
  type: TxType.expense,
  amount: amount,
  categoryId: 1,
  date: now,
  merchant: merchant,
  source: TxSource.manual,
  createdAt: now,
);

void main() {
  group('DataResetter', () {
    test(
      'verileri siler, uyarı kayıtlarını temizler, ayarları korur',
      () async {
        SharedPreferences.setMockInitialValues({
          'alert_2026-11_1_warning': true,
          'alert_2026-11_all_exceeded': true,
          'theme_mode': 'dark',
        });
        final prefs = await SharedPreferences.getInstance();
        var resetCalled = false;
        await DataResetter(
          reset: () async => resetCalled = true,
          prefs: prefs,
        )();
        expect(resetCalled, isTrue);
        expect(prefs.getKeys(), {'theme_mode'});
      },
    );

    test('sıfırlama hata verirse uyarı kayıtları silinmez', () async {
      SharedPreferences.setMockInitialValues({'alert_2026-11_1_warning': true});
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        DataResetter(reset: () async => throw StateError('x'), prefs: prefs)(),
        throwsStateError,
      );
      expect(prefs.containsKey('alert_2026-11_1_warning'), isTrue);
    });
  });

  testWidgets('sıfırlama başarısız olursa kullanıcıya söylenir', (t) async {
    final d = TestDeps(resetData: () async => throw StateError('disk dolu'));
    await d.txs.add(tx(5000));
    await pumpApp(t, const SettingsScreen(), deps: d);
    await t.scrollUntilVisible(find.text('Verileri sıfırla'), 100);
    await t.tap(find.text('Verileri sıfırla'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sıfırla'));
    await t.pumpAndSettle();
    expect(find.text('Veriler sıfırlanamadı'), findsOneWidget);
    expect(find.text('Veriler sıfırlandı'), findsNothing);
  });

  group('yükleme hataları', () {
    test('Dashboard yükleme hatasında hata durumuna geçer', () async {
      final p = DashboardProvider(
        txs: FailingTransactionRepository(),
        budgets: FakeRepos().budgets,
        events: TransactionProvider(FakeRepos().txs),
      );
      await p.load();
      expect(p.data, isNull);
      expect(p.error, isNotNull);
      expect(p.loading, isFalse);
    });

    test('Rapor yükleme hatasında hata durumuna geçer', () async {
      final p = ReportProvider(
        txs: FailingTransactionRepository(),
        events: TransactionProvider(FakeRepos().txs),
      );
      await p.load();
      expect(p.data, isNull);
      expect(p.error, isNotNull);
    });

    testWidgets('Dashboard hata mesajı ve Tekrar dene gösterir', (t) async {
      await pumpApp(
        t,
        const DashboardScreen(),
        deps: TestDeps(txsOverride: FailingTransactionRepository()),
      );
      await t.pumpAndSettle();
      expect(find.text('Veriler yüklenemedi'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('Raporlar hata mesajı gösterir', (t) async {
      await pumpApp(
        t,
        const ReportScreen(),
        deps: TestDeps(txsOverride: FailingTransactionRepository()),
      );
      await t.pumpAndSettle();
      expect(find.text('Veriler yüklenemedi'), findsOneWidget);
    });
  });

  testWidgets('uygulamaya geri dönülünce Dashboard yeniden yüklenir', (
    t,
  ) async {
    final d = TestDeps();
    await pumpApp(t, const DashboardScreen(), deps: d);
    await t.pumpAndSettle();
    // Olay yayınlamadan doğrudan veri ekle (ör. arka planda ay değişti).
    await d.txs.add(tx(4200, merchant: 'Simit'));
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    await t.pumpAndSettle();
    expect(find.text('Simit'), findsOneWidget);
  });

  testWidgets(
    'kategori sayfasında Kaydet\'e iki kez basmak tek kategori ekler',
    (t) async {
      final d = TestDeps();
      await pumpApp(t, const CategoryManagementScreen(), deps: d);
      await t.pumpAndSettle();
      await t.tap(find.text('Kategori ekle'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('category-name-field')), 'Kahve');
      await t.tap(find.text('Kaydet'));
      await t.tap(find.text('Kaydet'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(
        (await d.categories.all()).where((c) => c.name == 'Kahve'),
        hasLength(1),
      );
      expect(find.text('Bu adda kategori var'), findsNothing);
    },
  );

  testWidgets(
    'bütçe ekranında ay değiştirince kaydedilmemiş değişiklik sorulur',
    (t) async {
      await pumpApp(t, const BudgetSettingsScreen(), deps: TestDeps());
      await t.pumpAndSettle();
      final title = find.text(DateFormat('MMMM y', 'tr_TR').format(now));
      expect(title, findsOneWidget);
      await t.enterText(find.byKey(const Key('budget-overall')), '5000');
      await t.tap(find.byTooltip('Sonraki ay'));
      await t.pumpAndSettle();
      expect(
        find.text('Kaydedilmemiş değişiklikler silinsin mi?'),
        findsOneWidget,
      );
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(title, findsOneWidget);
      expect(find.text('5000'), findsOneWidget);

      await t.tap(find.byTooltip('Sonraki ay'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sil ve geç'));
      await t.pumpAndSettle();
      expect(title, findsNothing);
      expect(find.text('5000'), findsNothing);
    },
  );

  testWidgets('değişiklik yokken ay değiştirmek sormaz', (t) async {
    await pumpApp(t, const BudgetSettingsScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Önceki ay'));
    await t.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler silinsin mi?'), findsNothing);
  });

  testWidgets('rapor kategori dökümünün altında toplam satırı var', (t) async {
    final d = TestDeps();
    await d.txs.add(tx(12000));
    await d.txs.add(
      TransactionRecord(
        type: TxType.expense,
        amount: 5000,
        categoryId: 2,
        date: now,
        source: TxSource.manual,
        createdAt: now,
      ),
    );
    await pumpApp(t, const ReportScreen(), deps: d);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('breakdown-total')), 200);
    final row = find.byKey(const Key('breakdown-total'));
    expect(
      find.descendant(of: row, matching: find.text('Toplam')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('₺170,00')),
      findsOneWidget,
    );
  });
}
