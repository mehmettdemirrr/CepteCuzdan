// Berkay'ın PR #2 ikinci turunda Mehmet tarafı için bıraktığı notlar.
import 'dart:io';

import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/period_summary.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/repositories/budget_repository.dart';
import 'package:cepte_cuzdan/core/repositories/transaction_repository.dart';
import 'package:cepte_cuzdan/features/reports/report_screen.dart';
import 'package:cepte_cuzdan/features/settings/budget_settings_screen.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_form_screen.dart';
import 'package:cepte_cuzdan/features/transactions/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_repositories.dart';
import 'helpers/pump_app.dart';

/// Sahte repository'ye yönlendirir; [failReads] / [failWrites] açıkken hata verir.
class _FlakyTxs implements TransactionRepository {
  _FlakyTxs(this.inner);
  final FakeTransactionRepository inner;
  bool failReads = false;
  bool failWrites = false;

  Future<T> _read<T>(Future<T> Function() f) =>
      failReads ? Future.error(StateError('okunamadı')) : f();
  Future<T> _write<T>(Future<T> Function() f) =>
      failWrites ? Future.error(StateError('yazılamadı')) : f();

  @override
  Future<int> add(TransactionRecord tx, {List<ReceiptItem> items = const []}) =>
      _write(() => inner.add(tx, items: items));
  @override
  Future<void> update(TransactionRecord tx) => _write(() => inner.update(tx));
  @override
  Future<void> delete(int id) => _write(() => inner.delete(id));
  @override
  Future<TransactionRecord?> getById(int id) => _read(() => inner.getById(id));
  @override
  Future<List<TransactionRecord>> query({
    DateRange? range,
    int? categoryId,
    TxType? type,
    int? limit,
  }) => _read(
    () => inner.query(
      range: range,
      categoryId: categoryId,
      type: type,
      limit: limit,
    ),
  );
  @override
  Future<List<ReceiptItem>> itemsOf(int transactionId) =>
      _read(() => inner.itemsOf(transactionId));
  @override
  Future<PeriodSummary> summarize(DateRange range) =>
      _read(() => inner.summarize(range));
}

class _FailingBudgets implements BudgetRepository {
  @override
  Future<List<Budget>> forMonth(String month) async => [];
  @override
  Future<void> upsert(Budget b) async => throw StateError('yazılamadı');
  @override
  Future<void> delete(int id) async => throw StateError('yazılamadı');
}

TransactionRecord _tx(DateTime date, {String merchant = 'Migros'}) =>
    TransactionRecord(
      type: TxType.expense,
      amount: 12000,
      categoryId: 1,
      date: date,
      merchant: merchant,
      source: TxSource.manual,
      createdAt: date,
    );

void main() {
  test('Android yedeklemesi kapalı (kişisel bütçe ve fiş verisi)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
  });

  group('tarih seçici', () {
    testWidgets('eski tarihli kayıt açılınca tarih seçici çökmez', (t) async {
      final d = TestDeps();
      final old = DateTime(2015, 3, 1);
      final id = await d.txs.add(_tx(old));
      await pumpApp(
        t,
        TransactionFormScreen(initial: _tx(old).copyWith(id: id)),
        deps: d,
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('date-field')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('yeni kayıtta en erken 5 yıl önce, en geç 1 yıl sonra', (
      t,
    ) async {
      await pumpApp(t, const TransactionFormScreen(), deps: TestDeps());
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('date-field')));
      await t.pumpAndSettle();
      final picker = t.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      final now = DateTime.now();
      expect(picker.firstDate, DateTime(now.year - 5, now.month, now.day));
      expect(picker.lastDate, DateTime(now.year + 1, now.month, now.day));
    });

    testWidgets('raporda uzak geçmiş döneme gidilince özel aralık açılır', (
      t,
    ) async {
      await pumpApp(t, const ReportScreen(), deps: TestDeps());
      await t.pumpAndSettle();
      await t.tap(find.text('Aylık'));
      await t.pumpAndSettle();
      for (var i = 0; i < 12 * 7; i++) {
        await t.tap(find.byKey(const Key('report-prev')));
        await t.pump();
      }
      await t.pumpAndSettle();
      await t.tap(find.text('Özel'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });
  });

  testWidgets('işlem kaydı başarısızsa form açık kalır ve hata söylenir', (
    t,
  ) async {
    final inner = FakeRepos().txs;
    final flaky = _FlakyTxs(inner)..failWrites = true;
    await pumpApp(
      t,
      const TransactionFormScreen(),
      deps: TestDeps(txsOverride: flaky),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('amount-field')), '150');
    await t.tap(find.byKey(const Key('category-field')));
    await t.pumpAndSettle();
    await t.tap(find.text('Market').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Kaydet'));
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.text('İşlem kaydedilemedi'), findsOneWidget);
    expect(find.byType(TransactionFormScreen), findsOneWidget);
    expect(find.text('150'), findsOneWidget); // girilen değer kaybolmaz
    // Kaydet tekrar kullanılabilir.
    final button = t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Kaydet'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('bütçe kaydı başarısızsa hata söylenir', (t) async {
    await pumpApp(
      t,
      const BudgetSettingsScreen(),
      deps: TestDeps(budgetsOverride: _FailingBudgets()),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('budget-overall')), '5000');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Bütçe kaydedilemedi'), findsOneWidget);
    expect(find.text('Bütçe kaydedildi'), findsNothing);
  });

  group('İşlemler listesi', () {
    testWidgets('yüklenemezse hata ve Tekrar dene gösterir', (t) async {
      final inner = FakeRepos().txs;
      await inner.add(_tx(DateTime.now()));
      final flaky = _FlakyTxs(inner)..failReads = true;
      await pumpApp(
        t,
        const TransactionsScreen(),
        deps: TestDeps(txsOverride: flaky),
      );
      await t.pumpAndSettle();
      expect(find.text('İşlemler yüklenemedi'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      flaky.failReads = false;
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.text('Migros'), findsOneWidget);
    });

    testWidgets('kaydırarak silme başarısızsa satır geri gelir', (t) async {
      final inner = FakeRepos().txs;
      await inner.add(_tx(DateTime.now()));
      final flaky = _FlakyTxs(inner)..failWrites = true;
      await pumpApp(
        t,
        const TransactionsScreen(),
        deps: TestDeps(txsOverride: flaky),
      );
      await t.pumpAndSettle();
      await t.drag(find.text('Migros'), const Offset(-500, 0));
      await t.pumpAndSettle();
      await t.tap(find.text('Sil'));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('İşlem silinemedi'), findsOneWidget);
      expect(find.text('Migros'), findsOneWidget);
      expect(await inner.query(), hasLength(1));
    });
  });
}
