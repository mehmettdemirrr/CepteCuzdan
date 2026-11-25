import 'package:cepte_cuzdan/app/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kabuk 4 sekmeyi gösterir ve sekme değiştirir', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: AppShell(
          pages: [
            for (final k in ['home', 'assistant', 'transactions', 'reports'])
              ColoredBox(
                key: Key('tab-$k'),
                color: Colors.white,
                child: const SizedBox.expand(),
              ),
          ],
        ),
      ),
    );

    for (final l in ['Ana Sayfa', 'Asistan', 'İşlemler', 'Raporlar']) {
      expect(find.text(l), findsOneWidget);
    }

    await t.tap(find.text('Raporlar'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tab-reports')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('tab-home')).hitTestable(), findsNothing);
  });

  testWidgets('sayfa içinden selectTab ile sekme değiştirilir', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: AppShell(
          pages: [
            Builder(
              builder: (c) => Center(
                child: TextButton(
                  onPressed: () =>
                      AppShell.selectTab(c, AppShell.transactionsTab),
                  child: const Text('Tümü'),
                ),
              ),
            ),
            const SizedBox(),
            const ColoredBox(
              key: Key('tab-transactions'),
              color: Colors.white,
              child: SizedBox.expand(),
            ),
            const SizedBox(),
          ],
        ),
      ),
    );
    await t.tap(find.text('Tümü'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('tab-transactions')).hitTestable(),
      findsOneWidget,
    );
  });
}
