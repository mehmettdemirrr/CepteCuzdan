import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/budget/budget_alert_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_alert_notifier.dart';
import '../../fakes/fake_repositories.dart';

void main() {
  late FakeRepos r;
  late FakeAlertNotifier notifier;
  late BudgetAlertService service;
  final day = DateTime(2026, 11, 20);

  Future<int> spend(int amount, {int category = 1}) => r.txs.add(
    TransactionRecord(
      type: TxType.expense,
      amount: amount,
      categoryId: category,
      date: day,
      source: TxSource.manual,
      createdAt: day,
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    r = FakeRepos();
    notifier = FakeAlertNotifier();
    service = BudgetAlertService(
      budgets: r.budgets,
      txs: r.txs,
      categories: r.categories,
      notifier: notifier,
      prefs: await SharedPreferences.getInstance(),
    );
    // Market (id 1) için 1.000 TL limit
    await r.budgets.upsert(
      const Budget(categoryId: 1, month: '2026-11', limitAmount: 100000),
    );
  });

  test('limit yoksa ya da eşik altındaysa bildirim yok', () async {
    await spend(79000);
    await spend(50000, category: 2); // Ulaşım: limiti yok
    await service.checkMonth(day);
    expect(notifier.shown, isEmpty);
  });

  test(
    '%80 geçilince bir kez uyarır, sonraki harcamalarda tekrar etmez',
    () async {
      await spend(85000);
      await service.checkMonth(day);
      expect(notifier.shown, hasLength(1));
      expect(notifier.shown.single.title, 'Bütçe uyarısı');
      expect(
        notifier.shown.single.body,
        "Market limitinin %80'ine ulaştın: ₺850,00 / ₺1.000,00",
      );

      await spend(1000);
      await service.checkMonth(day);
      expect(notifier.shown, hasLength(1));
    },
  );

  test('limit aşılınca ayrıca aşım bildirimi gelir', () async {
    await spend(85000);
    await service.checkMonth(day);
    await spend(16000);
    await service.checkMonth(day);
    expect(notifier.shown, hasLength(2));
    expect(notifier.shown.last.title, 'Bütçe aşıldı');
    expect(notifier.shown.last.body, 'Market limitini ₺10,00 aştın');
  });

  test(
    'tek harcamayla doğrudan aşılırsa yalnızca aşım bildirimi gelir',
    () async {
      await spend(120000);
      await service.checkMonth(day);
      expect(notifier.shown.map((n) => n.title), ['Bütçe aşıldı']);
      await service.checkMonth(day);
      expect(notifier.shown, hasLength(1));
    },
  );

  test('eşiğin altına düşüp tekrar geçince yeniden uyarır', () async {
    final id = await spend(85000);
    await service.checkMonth(day);
    await r.txs.delete(id);
    await service.checkMonth(day);
    await spend(90000);
    await service.checkMonth(day);
    expect(notifier.shown.map((n) => n.title), [
      'Bütçe uyarısı',
      'Bütçe uyarısı',
    ]);
  });

  test('genel bütçe "Aylık bütçe" adıyla bildirilir', () async {
    await r.budgets.upsert(const Budget(month: '2026-11', limitAmount: 200000));
    await spend(170000, category: 2);
    await service.checkMonth(day);
    expect(
      notifier.shown.single.body,
      "Aylık bütçe limitinin %80'ine ulaştın: ₺1.700,00 / ₺2.000,00",
    );
  });

  test('farklı ayın kontrolü bu ayın bildirim kaydını etkilemez', () async {
    await spend(85000);
    await service.checkMonth(day);
    await service.checkMonth(DateTime(2026, 12, 5));
    await service.checkMonth(day);
    expect(notifier.shown, hasLength(1));
  });
}
