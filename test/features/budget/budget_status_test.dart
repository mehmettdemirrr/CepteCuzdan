import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/budget/budget_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repositories.dart';

void main() {
  test('levelFor eşikleri: %80 uyarı, limitin üstü aşım', () {
    expect(levelFor(spent: 0, limit: 10000), BudgetLevel.ok);
    expect(levelFor(spent: 7999, limit: 10000), BudgetLevel.ok);
    expect(levelFor(spent: 8000, limit: 10000), BudgetLevel.warning);
    expect(levelFor(spent: 10000, limit: 10000), BudgetLevel.warning);
    expect(levelFor(spent: 10001, limit: 10000), BudgetLevel.exceeded);
  });

  test('BudgetLine kalan, oran ve seviye', () {
    const b = Budget(month: '2026-11', limitAmount: 100000);
    final over = BudgetLine(budget: b, spent: 120000);
    expect(over.remaining, -20000);
    expect(over.ratio, 1.2);
    expect(over.level, BudgetLevel.exceeded);
    expect(BudgetLine(budget: b, spent: 0).ratio, 0);
  });

  group('budgetLinesFor', () {
    late FakeRepos r;
    setUp(() async {
      r = FakeRepos();
      Future<void> add(
        int amount,
        int cat,
        DateTime date, [
        TxType type = TxType.expense,
      ]) => r.txs.add(
        TransactionRecord(
          type: type,
          amount: amount,
          categoryId: cat,
          date: date,
          source: TxSource.manual,
          createdAt: date,
        ),
      );
      await add(30000, 1, DateTime(2026, 11, 5)); // Market
      await add(20000, 2, DateTime(2026, 11, 6)); // Ulaşım
      await add(5000000, 8, DateTime(2026, 11, 1), TxType.income); // Maaş
      await add(99900, 1, DateTime(2026, 12, 1)); // başka ay
    });

    test('genel bütçe ayın tüm giderlerini sayar, gelirleri ve diğer ayları saymaz', () async {
      await r.budgets.upsert(
        const Budget(month: '2026-11', limitAmount: 1000000),
      );
      final lines = await budgetLinesFor(
        '2026-11',
        budgets: r.budgets,
        txs: r.txs,
      );
      expect(lines.single.spent, 50000);
      expect(lines.single.budget.isOverall, isTrue);
    });

    test('kategori limiti yalnızca o kategorinin giderini sayar', () async {
      await r.budgets.upsert(
        const Budget(categoryId: 1, month: '2026-11', limitAmount: 37500),
      );
      final lines = await budgetLinesFor(
        '2026-11',
        budgets: r.budgets,
        txs: r.txs,
      );
      expect(lines.single.spent, 30000);
      expect(lines.single.level, BudgetLevel.warning);
    });

    test('limit yoksa boş liste', () async {
      expect(
        await budgetLinesFor('2026-11', budgets: r.budgets, txs: r.txs),
        isEmpty,
      );
    });
  });
}
