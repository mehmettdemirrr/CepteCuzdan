import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/reports/report_math.dart';
import 'package:cepte_cuzdan/features/reports/report_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('changePercent', () {
    test('artış, azalış, yeni ve sıfıra iniş', () {
      expect(changePercent(previous: 10000, current: 12000), 20);
      expect(changePercent(previous: 10000, current: 9500), -5);
      expect(changePercent(previous: 0, current: 5000), isNull);
      expect(changePercent(previous: 0, current: 0), isNull);
      expect(changePercent(previous: 5000, current: 0), -100);
      expect(changePercent(previous: 3000, current: 4000), 33);
    });
  });

  group('rangeLabel', () {
    test('hafta, ay ve özel aralık etiketleri', () {
      expect(
        rangeLabel(weekOf(DateTime(2026, 11, 25)), ReportPeriod.week),
        '23–29 Kasım 2026',
      );
      expect(
        rangeLabel(weekOf(DateTime(2026, 12, 2)), ReportPeriod.week),
        '30 Kasım – 6 Aralık 2026',
      );
      expect(
        rangeLabel(monthOf(DateTime(2026, 11, 3)), ReportPeriod.month),
        'Kasım 2026',
      );
      expect(
        rangeLabel(
          DateRange(DateTime(2025, 12, 20), DateTime(2026, 1, 5)),
          ReportPeriod.custom,
        ),
        '20 Aralık 2025 – 5 Ocak 2026',
      );
    });
  });

  group('ReportProvider', () {
    late FakeRepos r;
    late TransactionProvider events;
    late DateTime today;
    ReportProvider make() =>
        ReportProvider(txs: r.txs, events: events, clock: () => today);

    setUp(() {
      r = FakeRepos();
      events = TransactionProvider(r.txs);
      today = DateTime(2026, 11, 25, 9);
    });

    test(
      'varsayılan haftalık; hafta Pazartesi başlar ve önceki hafta kıyaslanır',
      () async {
        await r.txs.add(tx(10000, DateTime(2026, 11, 18))); // önceki hafta
        await r.txs.add(tx(12000, DateTime(2026, 11, 23))); // bu hafta
        await r.txs.add(tx(3000, DateTime(2026, 11, 30))); // sonraki hafta
        final p = make();
        await p.load();
        expect(p.period, ReportPeriod.week);
        expect(
          p.range,
          DateRange(DateTime(2026, 11, 23), DateTime(2026, 11, 29)),
        );
        expect(
          p.data!.previousRange,
          DateRange(DateTime(2026, 11, 16), DateTime(2026, 11, 22)),
        );
        expect(p.data!.currentTotal, 12000);
        expect(p.data!.previousTotal, 10000);
        expect(p.data!.transactions.map((t) => t.amount), [12000]);
      },
    );

    test(
      'aylık dönemde shift(-1) Ocak\'tan önceki yılın Aralık\'ına geçer',
      () async {
        today = DateTime(2026, 1, 10);
        final p = make();
        await p.setPeriod(ReportPeriod.month);
        expect(p.range, monthOf(DateTime(2026, 1, 1)));
        await p.shift(-1);
        expect(
          p.range,
          DateRange(DateTime(2025, 12, 1), DateTime(2025, 12, 31)),
        );
        await p.shift(1);
        expect(p.range, monthOf(DateTime(2026, 1, 1)));
      },
    );

    test('haftalık shift bir hafta kaydırır', () async {
      final p = make();
      await p.load();
      await p.shift(-1);
      expect(
        p.range,
        DateRange(DateTime(2026, 11, 16), DateTime(2026, 11, 22)),
      );
    });

    test('özel aralık ve kaydırma aynı uzunlukta çalışır', () async {
      await r.txs.add(tx(5000, DateTime(2026, 11, 12)));
      final p = make();
      await p.setCustomRange(
        DateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 14)),
      );
      expect(p.period, ReportPeriod.custom);
      expect(p.data!.currentTotal, 5000);
      expect(
        p.data!.previousRange,
        DateRange(DateTime(2026, 11, 5), DateTime(2026, 11, 9)),
      );
      await p.shift(1);
      expect(
        p.range,
        DateRange(DateTime(2026, 11, 15), DateTime(2026, 11, 19)),
      );
    });

    test('kategori filtresi işlemleri ve toplamları süzer', () async {
      await r.txs.add(tx(10000, DateTime(2026, 11, 24))); // Market
      await r.txs.add(tx(20000, DateTime(2026, 11, 24), category: 2)); // Ulaşım
      await r.txs.add(
        tx(500000, DateTime(2026, 11, 24), category: 8, type: TxType.income),
      );
      final p = make();
      await p.load();
      expect(p.data!.currentTotal, 30000);
      expect(p.data!.incomeTotal, 500000);
      expect(p.data!.transactions, hasLength(3));

      await p.setCategory(2);
      expect(p.data!.currentTotal, 20000);
      expect(p.data!.currentByCategory.keys, [2]);
      expect(p.data!.transactions.map((t) => t.amount), [20000]);

      await p.setCategory(null);
      expect(p.data!.currentTotal, 30000);
    });

    test('kategori dökümü bu ve önceki dönemi birleştirir, büyükten küçüğe sıralar', () async {
      await r.txs.add(tx(10000, DateTime(2026, 11, 24))); // Market bu hafta
      await r.txs.add(
        tx(30000, DateTime(2026, 11, 24), category: 2),
      ); // Ulaşım bu hafta
      await r.txs.add(
        tx(7000, DateTime(2026, 11, 17), category: 3),
      ); // Faturalar geçen hafta
      final p = make();
      await p.load();
      expect(p.data!.rows.map((r) => r.categoryId), [2, 1, 3]);
      expect(p.data!.rows.last.current, 0);
      expect(p.data!.rows.last.previous, 7000);
    });

    test('işlem eklenince yeniden yüklenir', () async {
      final p = make();
      await p.load();
      await events.add(tx(4000, DateTime(2026, 11, 25)));
      await pumpEventQueue();
      expect(p.data!.currentTotal, 4000);
    });
  });
}
