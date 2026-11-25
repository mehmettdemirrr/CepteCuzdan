// İncelemenin küçük bulgularının regresyon testleri.
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_provider.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_screen.dart';
import 'package:cepte_cuzdan/features/reports/report_provider.dart';
import 'package:cepte_cuzdan/features/reports/report_screen.dart';
import 'package:cepte_cuzdan/features/settings/data_resetter.dart';
import 'package:cepte_cuzdan/features/settings/settings_screen.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
