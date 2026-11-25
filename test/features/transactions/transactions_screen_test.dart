import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_form_screen.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transactions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

TransactionRecord _tx(
  int amount,
  DateTime date, {
  String? merchant,
  TxSource source = TxSource.manual,
}) => TransactionRecord(
  type: TxType.expense,
  amount: amount,
  categoryId: 1,
  date: date,
  merchant: merchant,
  source: source,
  createdAt: DateTime(2026, 11, 25, 12),
);

void main() {
  testWidgets('boş listede boş durum gösterir', (t) async {
    await pumpApp(t, const TransactionsScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    expect(find.text('Henüz işlem yok'), findsOneWidget);
  });

  testWidgets('işlemleri gün başlıklarıyla en yeni önce listeler', (t) async {
    final d = TestDeps();
    await d.txs.add(_tx(15000, DateTime(2026, 11, 24), merchant: 'Taksi'));
    await d.txs.add(
      _tx(
        32000,
        DateTime(2026, 11, 25),
        merchant: 'Migros',
        source: TxSource.receipt,
      ),
    );
    await pumpApp(t, const TransactionsScreen(), deps: d);
    await t.pumpAndSettle();

    expect(find.text('25 Kasım 2026 Çarşamba'), findsOneWidget);
    expect(find.text('24 Kasım 2026 Salı'), findsOneWidget);
    expect(find.text('-₺320,00'), findsOneWidget);
    expect(find.textContaining('Fiş'), findsOneWidget);
    final migrosY = t.getTopLeft(find.text('Migros')).dy;
    final taksiY = t.getTopLeft(find.text('Taksi')).dy;
    expect(migrosY, lessThan(taksiY));
  });

  testWidgets('provider üzerinden eklenen işlem listede hemen görünür', (
    t,
  ) async {
    final d = TestDeps();
    await pumpApp(t, const TransactionsScreen(), deps: d);
    await t.pumpAndSettle();
    final ctx = t.element(find.byType(TransactionsScreen));
    await ctx.read<TransactionProvider>().add(
      _tx(5000, DateTime(2026, 11, 25), merchant: 'Kahve'),
    );
    await t.pumpAndSettle();
    expect(find.text('Kahve'), findsOneWidget);
  });

  testWidgets('kaydırıp onaylayınca siler, vazgeçince silmez', (t) async {
    final d = TestDeps();
    await d.txs.add(_tx(15000, DateTime(2026, 11, 24), merchant: 'Taksi'));
    await pumpApp(t, const TransactionsScreen(), deps: d);
    await t.pumpAndSettle();

    await t.drag(find.text('Taksi'), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('İşlem silinsin mi?'), findsOneWidget);
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(d.txs.records, hasLength(1));
    expect(find.text('Taksi'), findsOneWidget);

    await t.drag(find.text('Taksi'), const Offset(-500, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('Sil'));
    await t.pumpAndSettle();
    expect(d.txs.records, isEmpty);
    expect(find.text('Taksi'), findsNothing);
  });

  testWidgets('işleme dokununca düzenleme formu açılır', (t) async {
    final d = TestDeps();
    await d.txs.add(_tx(15000, DateTime(2026, 11, 24), merchant: 'Taksi'));
    await pumpApp(t, const TransactionsScreen(), deps: d);
    await t.pumpAndSettle();
    await t.tap(find.text('Taksi'));
    await t.pumpAndSettle();
    expect(find.byType(TransactionFormScreen), findsOneWidget);
    expect(find.text('İşlemi düzenle'), findsOneWidget);
  });
}
