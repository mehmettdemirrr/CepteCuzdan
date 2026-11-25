// Repository sözleşmesinin ortak test paketi. Hem SQLite implementasyonu hem
// de test/fakes altındaki sahte repository'ler bu testlerden geçmek zorunda;
// böylece widget testlerinde kullanılan fake'ler gerçek DB ile aynı davranır.
import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/category.dart';
import 'package:cepte_cuzdan/core/models/chat_message.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/repositories/budget_repository.dart';
import 'package:cepte_cuzdan/core/repositories/category_repository.dart';
import 'package:cepte_cuzdan/core/repositories/chat_message_repository.dart';
import 'package:cepte_cuzdan/core/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class RepoSet {
  RepoSet({
    required this.txs,
    required this.categories,
    required this.budgets,
    required this.chats,
    required this.close,
  });

  final TransactionRepository txs;
  final CategoryRepository categories;
  final BudgetRepository budgets;
  final ChatMessageRepository chats;
  final Future<void> Function() close;
}

void runRepositoryContract(String label, Future<RepoSet> Function() open) {
  group('$label sözleşmesi', () {
    late RepoSet r;
    setUp(() async => r = await open());
    tearDown(() => r.close());

    Future<int> catId(String name, [TxType type = TxType.expense]) async =>
        (await r.categories.findByName(name, type))!.id!;

    Future<int> addTx({
      required int amount,
      required int categoryId,
      required DateTime date,
      TxType type = TxType.expense,
      DateTime? createdAt,
      List<ReceiptItem> items = const [],
    }) => r.txs.add(
      TransactionRecord(
        type: type,
        amount: amount,
        categoryId: categoryId,
        date: date,
        source: TxSource.manual,
        createdAt: createdAt ?? DateTime(2026, 11, 25, 12),
      ),
      items: items,
    );

    group('kategoriler', () {
      test('varsayılan kategoriler eklenir', () async {
        final expense = await r.categories.all(type: TxType.expense);
        expect(expense.map((c) => c.name), [
          'Market',
          'Ulaşım',
          'Faturalar',
          'Yeme-İçme',
          'Eğlence',
          'Sağlık',
          'Diğer',
        ]);
        final income = await r.categories.all(type: TxType.income);
        expect(income.map((c) => c.name), ['Maaş', 'Diğer']);
        expect((await r.categories.all()).every((c) => c.isDefault), isTrue);
        expect((await r.categories.all()).every((c) => c.id != null), isTrue);
      });

      test('findByName büyük küçük harf duyarsız ve tipe bağlı', () async {
        expect(
          (await r.categories.findByName('market', TxType.expense))?.name,
          'Market',
        );
        expect(await r.categories.findByName('Yok', TxType.expense), isNull);
        expect(await r.categories.findByName('Market', TxType.income), isNull);
        final incomeOther = await r.categories.findByName(
          'Diğer',
          TxType.income,
        );
        expect(incomeOther?.type, TxType.income);
      });

      test('kategori eklenir ve güncellenir', () async {
        final id = await r.categories.add(
          const Category(
            name: 'Kahve',
            type: TxType.expense,
            color: 0xFF795548,
            icon: 'local_cafe',
          ),
        );
        final c = await r.categories.findByName('Kahve', TxType.expense);
        expect(c?.id, id);
        expect(c?.isDefault, isFalse);
        await r.categories.update(c!.copyWith(name: 'Kafe', color: 0xFF000000));
        final u = await r.categories.findByName('Kafe', TxType.expense);
        expect(u?.id, id);
        expect(u?.color, 0xFF000000);
      });

      test('aynı ad ve tipte kategori eklenemez', () async {
        expect(
          () => r.categories.add(
            const Category(
              name: 'Market',
              type: TxType.expense,
              color: 0,
              icon: 'category',
            ),
          ),
          throwsA(isA<DuplicateCategoryException>()),
        );
        // Aynı ad farklı tipte olabilir
        await r.categories.add(
          const Category(
            name: 'Market',
            type: TxType.income,
            color: 0,
            icon: 'category',
          ),
        );
      });

      test('başka bir kategorinin adına güncellenemez', () async {
        final c = (await r.categories.findByName('Ulaşım', TxType.expense))!;
        final custom = await r.categories.add(
          const Category(
            name: 'Kahve',
            type: TxType.expense,
            color: 0,
            icon: 'category',
          ),
        );
        expect(
          () => r.categories.update(
            Category(
              id: custom,
              name: c.name,
              type: TxType.expense,
              color: 0,
              icon: 'category',
            ),
          ),
          throwsA(isA<DuplicateCategoryException>()),
        );
      });

      test('varsayılan kategori silinemez', () async {
        final id = await catId('Market');
        expect(() => r.categories.delete(id), throwsStateError);
        expect(
          await r.categories.findByName('Market', TxType.expense),
          isNotNull,
        );
      });

      test(
        'kategori silinince işlemleri aynı tipteki Diğer\'e taşınır',
        () async {
          final kahve = await r.categories.add(
            const Category(
              name: 'Kahve',
              type: TxType.expense,
              color: 0,
              icon: 'category',
            ),
          );
          final txId = await addTx(
            amount: 5000,
            categoryId: kahve,
            date: DateTime(2026, 11, 20),
          );
          await r.categories.delete(kahve);
          expect(
            await r.categories.findByName('Kahve', TxType.expense),
            isNull,
          );
          expect((await r.txs.getById(txId))!.categoryId, await catId('Diğer'));
        },
      );

      test('kategori silinince bütçe limiti de silinir', () async {
        final kahve = await r.categories.add(
          const Category(
            name: 'Kahve',
            type: TxType.expense,
            color: 0,
            icon: 'category',
          ),
        );
        await r.budgets.upsert(
          Budget(categoryId: kahve, month: '2026-11', limitAmount: 50000),
        );
        await r.categories.delete(kahve);
        expect(await r.budgets.forMonth('2026-11'), isEmpty);
      });
    });

    group('işlemler', () {
      test('add fiş kalemleriyle kaydeder', () async {
        final id = await addTx(
          amount: 32000,
          categoryId: await catId('Market'),
          date: DateTime(2026, 11, 8),
          items: const [
            ReceiptItem(name: 'Süt', quantity: 2, price: 7990),
            ReceiptItem(name: 'Ekmek', price: 1500),
          ],
        );
        final tx = (await r.txs.getById(id))!;
        expect(tx.id, id);
        expect(tx.amount, 32000);
        expect(tx.date, DateTime(2026, 11, 8));
        final items = await r.txs.itemsOf(id);
        expect(items.map((i) => i.name), ['Süt', 'Ekmek']);
        expect(items.every((i) => i.transactionId == id), isTrue);
        expect(items.first.quantity, 2);
      });

      test('delete işlemi ve fiş kalemlerini siler', () async {
        final id = await addTx(
          amount: 1000,
          categoryId: await catId('Market'),
          date: DateTime(2026, 11, 8),
          items: const [ReceiptItem(name: 'Süt', price: 1000)],
        );
        await r.txs.delete(id);
        expect(await r.txs.getById(id), isNull);
        expect(await r.txs.itemsOf(id), isEmpty);
      });

      test('update alanları değiştirir', () async {
        final id = await addTx(
          amount: 15000,
          categoryId: await catId('Ulaşım'),
          date: DateTime(2026, 11, 8),
        );
        final tx = (await r.txs.getById(id))!;
        await r.txs.update(
          tx.copyWith(amount: 20000, date: DateTime(2026, 11, 9)),
        );
        final u = (await r.txs.getById(id))!;
        expect(u.amount, 20000);
        expect(u.date, DateTime(2026, 11, 9));
      });

      test(
        'query aralığın iki ucunu da dahil eder, ay sınırını aşmaz',
        () async {
          final market = await catId('Market');
          await addTx(
            amount: 100,
            categoryId: market,
            date: DateTime(2026, 11, 1),
          );
          await addTx(
            amount: 200,
            categoryId: market,
            date: DateTime(2026, 11, 30),
          );
          await addTx(
            amount: 300,
            categoryId: market,
            date: DateTime(2026, 12, 1),
          );
          await addTx(
            amount: 400,
            categoryId: market,
            date: DateTime(2026, 10, 31),
          );
          final nov = await r.txs.query(range: monthOf(DateTime(2026, 11, 15)));
          expect(nov.map((t) => t.amount).toSet(), {100, 200});
          final dec = await r.txs.query(range: monthOf(DateTime(2026, 12, 1)));
          expect(dec.map((t) => t.amount), [300]);
        },
      );

      test('query kategori, tip ve limit filtresi; en yeni önce', () async {
        final market = await catId('Market');
        final ulasim = await catId('Ulaşım');
        final maas = await catId('Maaş', TxType.income);
        await addTx(amount: 1, categoryId: market, date: DateTime(2026, 11, 5));
        await addTx(amount: 2, categoryId: ulasim, date: DateTime(2026, 11, 7));
        await addTx(
          amount: 3,
          categoryId: market,
          date: DateTime(2026, 11, 7),
          createdAt: DateTime(2026, 11, 25, 13),
        );
        await addTx(
          amount: 4,
          categoryId: maas,
          date: DateTime(2026, 11, 6),
          type: TxType.income,
        );

        expect((await r.txs.query()).map((t) => t.amount), [3, 2, 4, 1]);
        expect((await r.txs.query(categoryId: market)).map((t) => t.amount), [
          3,
          1,
        ]);
        expect((await r.txs.query(type: TxType.income)).map((t) => t.amount), [
          4,
        ]);
        expect((await r.txs.query(limit: 2)).map((t) => t.amount), [3, 2]);
      });

      test(
        'summarize gelir, gider ve kategori toplamlarını hesaplar',
        () async {
          final market = await catId('Market');
          final ulasim = await catId('Ulaşım');
          final maas = await catId('Maaş', TxType.income);
          await addTx(
            amount: 5000000,
            categoryId: maas,
            date: DateTime(2026, 11, 1),
            type: TxType.income,
          );
          await addTx(
            amount: 32000,
            categoryId: market,
            date: DateTime(2026, 11, 8),
          );
          await addTx(
            amount: 15000,
            categoryId: market,
            date: DateTime(2026, 11, 20),
          );
          await addTx(
            amount: 15000,
            categoryId: ulasim,
            date: DateTime(2026, 11, 30),
          );
          await addTx(
            amount: 99900,
            categoryId: market,
            date: DateTime(2026, 12, 1),
          );

          final s = await r.txs.summarize(monthOf(DateTime(2026, 11, 1)));
          expect(s.incomeTotal, 5000000);
          expect(s.expenseTotal, 62000);
          expect(s.expenseByCategory, {market: 47000, ulasim: 15000});
          expect(s.incomeByCategory, {maas: 5000000});
          expect(s.balance, 4938000);
        },
      );

      test('boş aralıkta summarize sıfır döner', () async {
        final s = await r.txs.summarize(monthOf(DateTime(2026, 11, 1)));
        expect(s.incomeTotal, 0);
        expect(s.expenseTotal, 0);
        expect(s.expenseByCategory, isEmpty);
      });
    });

    group('bütçeler', () {
      test('genel bütçe upsert tekrarlanmaz', () async {
        await r.budgets.upsert(
          const Budget(month: '2026-11', limitAmount: 1000000),
        );
        await r.budgets.upsert(
          const Budget(month: '2026-11', limitAmount: 1500000),
        );
        final list = await r.budgets.forMonth('2026-11');
        expect(list, hasLength(1));
        expect(list.single.limitAmount, 1500000);
        expect(list.single.isOverall, isTrue);
      });

      test('kategori limitleri ay bazında ayrı tutulur ve silinir', () async {
        final market = await catId('Market');
        await r.budgets.upsert(
          Budget(categoryId: market, month: '2026-11', limitAmount: 100000),
        );
        await r.budgets.upsert(
          Budget(categoryId: market, month: '2026-11', limitAmount: 120000),
        );
        await r.budgets.upsert(
          Budget(categoryId: market, month: '2026-12', limitAmount: 90000),
        );
        await r.budgets.upsert(
          const Budget(month: '2026-11', limitAmount: 1000000),
        );

        final nov = await r.budgets.forMonth('2026-11');
        expect(nov, hasLength(2));
        final marketNov = nov.firstWhere((b) => b.categoryId == market);
        expect(marketNov.limitAmount, 120000);

        await r.budgets.delete(marketNov.id!);
        expect(await r.budgets.forMonth('2026-11'), hasLength(1));
        expect(await r.budgets.forMonth('2026-12'), hasLength(1));
      });
    });

    group('sohbet', () {
      test(
        'mesajlar eskiden yeniye listelenir, limit son mesajları verir',
        () async {
          for (var i = 1; i <= 3; i++) {
            await r.chats.add(
              ChatMessage(
                role: i.isOdd ? ChatRole.user : ChatRole.assistant,
                content: 'm$i',
                createdAt: DateTime(2026, 11, 25, 10, i),
              ),
            );
          }
          expect((await r.chats.all()).map((m) => m.content), [
            'm1',
            'm2',
            'm3',
          ]);
          expect((await r.chats.all(limit: 2)).map((m) => m.content), [
            'm2',
            'm3',
          ]);
        },
      );

      test(
        'linkTransaction mesajı işleme bağlar, işlem silinince bağ kopar',
        () async {
          final txId = await addTx(
            amount: 15000,
            categoryId: await catId('Ulaşım'),
            date: DateTime(2026, 11, 25),
          );
          final msgId = await r.chats.add(
            ChatMessage(
              role: ChatRole.assistant,
              content: 'Kaydedildi',
              createdAt: DateTime(2026, 11, 25, 10),
            ),
          );
          await r.chats.linkTransaction(msgId, txId);
          expect((await r.chats.all()).single.transactionId, txId);

          await r.txs.delete(txId);
          final m = (await r.chats.all()).single;
          expect(m.transactionId, isNull);
          expect(m.content, 'Kaydedildi');
        },
      );

      test('clear tüm mesajları siler', () async {
        await r.chats.add(
          ChatMessage(
            role: ChatRole.user,
            content: 'x',
            createdAt: DateTime(2026),
          ),
        );
        await r.chats.clear();
        expect(await r.chats.all(), isEmpty);
      });
    });
  });
}
