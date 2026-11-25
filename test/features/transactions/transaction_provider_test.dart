import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/category.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repositories.dart';

TransactionRecord _tx(DateTime date, {int amount = 15000}) => TransactionRecord(
  type: TxType.expense,
  amount: amount,
  categoryId: 2,
  date: date,
  source: TxSource.receipt,
  createdAt: DateTime(2026, 11, 25, 12),
);

void main() {
  group('TransactionProvider', () {
    late FakeRepos repos;
    late List<DateTime> changed;
    late TransactionProvider p;
    late int notified;

    setUp(() {
      repos = FakeRepos();
      changed = [];
      notified = 0;
      p = TransactionProvider(repos.txs, onChanged: (d) async => changed.add(d))
        ..addListener(() => notified++);
    });

    test('add kaydı repository\'ye yazar, dinleyicileri bilgilendirir ve revision artar', () async {
      final id = await p.add(
        _tx(DateTime(2026, 11, 8)),
        items: const [ReceiptItem(name: 'Simit', price: 1500)],
      );
      expect((await repos.txs.getById(id))!.amount, 15000);
      expect(await repos.txs.itemsOf(id), hasLength(1));
      expect(notified, 1);
      expect(p.revision, 1);
      expect(changed, [DateTime(2026, 11, 8)]);
    });

    test(
      'update işlem ayını değiştirince onChanged iki ay için çağrılır',
      () async {
        final id = await p.add(_tx(DateTime(2026, 11, 30)));
        changed.clear();
        final tx = (await repos.txs.getById(id))!;
        await p.update(tx.copyWith(date: DateTime(2026, 12, 1)));
        expect(changed.map(monthKey).toSet(), {'2026-11', '2026-12'});
        expect(p.revision, 2);
      },
    );

    test('update aynı ayda kalırsa onChanged bir kez çağrılır', () async {
      final id = await p.add(_tx(DateTime(2026, 11, 3)));
      changed.clear();
      final tx = (await repos.txs.getById(id))!;
      await p.update(tx.copyWith(amount: 99));
      expect(changed, hasLength(1));
    });

    test(
      'delete kaydı siler ve silinen işlemin tarihiyle onChanged çağırır',
      () async {
        final id = await p.add(_tx(DateTime(2026, 11, 3)));
        changed.clear();
        await p.delete(id);
        expect(await repos.txs.getById(id), isNull);
        expect(changed, [DateTime(2026, 11, 3)]);
        expect(p.revision, 2);
      },
    );

    test('markChanged revision artırır ve bilgilendirir', () {
      p.markChanged();
      expect(p.revision, 1);
      expect(notified, 1);
    });

    test('query repository sonucunu döner', () async {
      await p.add(_tx(DateTime(2026, 11, 3), amount: 1));
      await p.add(_tx(DateTime(2026, 12, 3), amount: 2));
      final nov = await p.query(range: monthOf(DateTime(2026, 11, 1)));
      expect(nov.map((t) => t.amount), [1]);
    });
  });

  group('CategoryProvider', () {
    late CategoryProvider p;
    setUp(() async {
      p = CategoryProvider(FakeRepos().categories);
      await p.load();
    });

    test('ofType yalnızca o tipi döner', () {
      expect(p.ofType(TxType.income).map((c) => c.name), ['Maaş', 'Diğer']);
      expect(p.ofType(TxType.expense), hasLength(7));
    });

    test('byId kategoriyi bulur', () {
      expect(p.byId(1)?.name, 'Market');
      expect(p.byId(999), isNull);
    });

    test(
      'add sonrası liste yenilenir ve dinleyiciler bilgilendirilir',
      () async {
        var notified = 0;
        p.addListener(() => notified++);
        await p.add(
          const Category(
            name: 'Kahve',
            type: TxType.expense,
            color: 0,
            icon: 'local_cafe',
          ),
        );
        expect(p.ofType(TxType.expense).map((c) => c.name), contains('Kahve'));
        expect(notified, greaterThanOrEqualTo(1));
      },
    );

    test('varsayılan kategori silme hatası yukarı iletilir', () async {
      expect(() => p.delete(1), throwsStateError);
    });
  });
}
