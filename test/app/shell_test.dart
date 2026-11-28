import 'package:cepte_cuzdan/app/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screen_matrix.dart';

void main() {
  responsiveShellTests();
  rotationStateTest();

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

Widget _shellApp() => MaterialApp(
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
);

void _setScreen(WidgetTester t, ScreenCase s) {
  t.view.physicalSize = s.size;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(
    left: s.padding.left,
    top: s.padding.top,
    right: s.padding.right,
    bottom: s.padding.bottom,
  );
  t.view.viewPadding = t.view.padding;
  addTearDown(t.view.reset);
}

void responsiveShellTests() {
  for (final s in [ScreenCase.landscape, ScreenCase.tablet]) {
    testWidgets('geniş ekranda yan gezinme [${s.label}]', (t) async {
      _setScreen(t, s);
      await t.pumpWidget(_shellApp());
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await t.tap(find.text('Raporlar'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('tab-reports')).hitTestable(),
        findsOneWidget,
      );
    });
  }

  for (final s in [ScreenCase.phone, ScreenCase.small]) {
    testWidgets('dar ekranda alt gezinme [${s.label}]', (t) async {
      _setScreen(t, s);
      await t.pumpWidget(_shellApp());
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  }

  testWidgets('yatayda yan gezinme ve sayfa çentiğin altında kalmaz', (
    t,
  ) async {
    _setScreen(t, ScreenCase.landscape);
    await t.pumpWidget(_shellApp());
    // Sol 32 dp çentik payı: gezinme öğeleri ve sayfa bu alanın sağında.
    expect(t.getRect(find.text('Ana Sayfa')).left, greaterThanOrEqualTo(32));
    expect(
      t.getRect(find.byKey(const Key('tab-home'))).left,
      greaterThanOrEqualTo(32),
    );
  });

  testWidgets('düzen değişince seçili sekme korunur', (t) async {
    _setScreen(t, ScreenCase.phone);
    await t.pumpWidget(_shellApp());
    await t.tap(find.text('İşlemler'));
    await t.pumpAndSettle();
    _setScreen(t, ScreenCase.landscape); // telefon yan çevrildi
    await t.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      find.byKey(const Key('tab-transactions')).hitTestable(),
      findsOneWidget,
    );
  });
}

void rotationStateTest() {
  testWidgets('telefon yan çevrilince sayfaların durumu korunur', (t) async {
    _setScreen(t, ScreenCase.phone);
    await t.pumpWidget(
      const MaterialApp(
        home: AppShell(
          pages: [
            Material(child: TextField(key: Key('draft'))),
            SizedBox(),
            SizedBox(),
            SizedBox(),
          ],
        ),
      ),
    );
    await t.enterText(find.byKey(const Key('draft')), 'Migros 320');
    _setScreen(t, ScreenCase.landscape);
    await t.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Migros 320'), findsOneWidget);
  });
}
