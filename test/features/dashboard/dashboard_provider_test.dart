import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/dashboard/dashboard_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repositories.dart';

TransactionRecord tx(
  int amount,
  DateTime date, {
  int category = 1,
  TxType type = TxType.expense,
}) => TransactionRecord(
  type: type,
  amount: amount,
  categoryId: category,
  date: date,
  source: TxSource.manual,
  createdAt: date,
);

void main() {
  late FakeRepos r;
  late TransactionProvider events;
  DashboardProvider make() => DashboardProvider(
    txs: r.txs,
    budgets: r.budgets,
    events: events,
    clock: () => DateTime(2026, 11, 25, 9),
  );

  setUp(() {
    r = FakeRepos();
    events = TransactionProvider(r.txs);
  });

  test('ayın özetini, limitleri ve son 5 işlemi yükler', () async {
    await r.txs.add(
      tx(5000000, DateTime(2026, 11, 1), category: 8, type: TxType.income),
    );
    for (var d = 2; d <= 6; d++) {
      await r.txs.add(tx(10000, DateTime(2026, 11, d)));
    }
    await r.txs.add(tx(12000, DateTime(2026, 11, 24), category: 2));
    await r.txs.add(tx(99900, DateTime(2026, 10, 31)));
    await r.budgets.upsert(const Budget(month: '2026-11', limitAmount: 100000));
    await r.budgets.upsert(
      const Budget(categoryId: 1, month: '2026-11', limitAmount: 50000),
    );

    final p = make();
    await p.load();
    final d = p.data!;
    expect(d.summary.incomeTotal, 5000000);
    expect(d.summary.expenseTotal, 62000);
    expect(d.recent, hasLength(5));
    expect(d.recent.first.date, DateTime(2026, 11, 24));
    expect(d.overall?.spent, 62000);
    expect(d.remaining, 38000);
    expect(d.categoryLines.single.spent, 50000);
    expect(d.month, DateTime(2026, 11));
  });

  test('genel bütçe yoksa kalan null', () async {
    final p = make();
    await p.load();
    expect(p.data!.overall, isNull);
    expect(p.data!.remaining, isNull);
    expect(p.data!.summary.expenseTotal, 0);
  });

  test('işlem eklenince yeniden yüklenir', () async {
    final p = make();
    await p.load();
    await events.add(tx(15000, DateTime(2026, 11, 25)));
    await pumpEventQueue();
    expect(p.data!.summary.expenseTotal, 15000);
    expect(p.data!.recent, hasLength(1));
  });

  test('dispose sonrası olaylar yüklemeyi tetiklemez', () async {
    final p = make();
    await p.load();
    p.dispose();
    await events.add(tx(15000, DateTime(2026, 11, 25)));
    await pumpEventQueue();
  });
}
