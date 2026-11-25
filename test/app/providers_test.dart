import 'package:cepte_cuzdan/core/repositories/chat_message_repository.dart';
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
}
