import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/repositories/chat_message_repository.dart';
import 'package:cepte_cuzdan/features/budget/budget_alert_service.dart';
import 'package:cepte_cuzdan/features/transactions/category_provider.dart';
import 'package:cepte_cuzdan/features/transactions/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('bağımlılık ağacı provider ve repository\'leri sağlar', (
    t,
  ) async {
    late BuildContext ctx;
    await pumpApp(
      t,
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
      deps: TestDeps(),
    );

    expect(ctx.read<TransactionProvider>().revision, 0);
    expect(ctx.read<ChatMessageRepository>(), isNotNull);
    expect(ctx.read<CategoryProvider>().loaded, isTrue);
    expect(ctx.read<CategoryProvider>().categories, hasLength(9));
  });

  testWidgets('provider üzerinden eklenen harcama bütçe uyarısını tetikler', (
    t,
  ) async {
    final deps = TestDeps();
    final now = DateTime.now();
    await deps.budgets.upsert(
      Budget(categoryId: 1, month: monthKey(now), limitAmount: 10000),
    );
    late BuildContext ctx;
    await pumpApp(
      t,
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
      deps: deps,
    );

    await ctx.read<TransactionProvider>().add(
      TransactionRecord(
        type: TxType.expense,
        amount: 9000,
        categoryId: 1,
        date: now,
        source: TxSource.receipt,
        createdAt: now,
      ),
    );
    expect(deps.notifier.shown.single.title, 'Bütçe uyarısı');
    expect(ctx.read<BudgetAlertService>(), isNotNull);
  });
}
