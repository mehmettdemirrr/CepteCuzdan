import 'package:cepte_cuzdan/core/ui/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> _pumpAt(WidgetTester t, Size size, Widget child) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('chartHeight dikeyde 200, yatayda 144, çok kısa ekranda 120', (
    t,
  ) async {
    final seen = <double>[];
    Widget probe() => Builder(
      builder: (c) {
        seen.add(chartHeight(c));
        return const SizedBox();
      },
    );
    await _pumpAt(t, const Size(360, 800), probe());
    await _pumpAt(t, const Size(800, 360), probe());
    await _pumpAt(t, const Size(800, 250), probe());
    expect(seen, [200, 144, 120]);
  });

  testWidgets('isWide 600 dp ve üstünde true', (t) async {
    final seen = <bool>[];
    Widget probe() => Builder(
      builder: (c) {
        seen.add(isWide(c));
        return const SizedBox();
      },
    );
    await _pumpAt(t, const Size(599, 800), probe());
    await _pumpAt(t, const Size(600, 800), probe());
    expect(seen, [false, true]);
  });

  testWidgets('ContentWidth tablette içeriği 840 dp ile sınırlar ve ortalar', (
    t,
  ) async {
    await _pumpAt(
      t,
      const Size(1280, 800),
      const ContentWidth(child: SizedBox(key: Key('c'), height: 10)),
    );
    final rect = t.getRect(find.byKey(const Key('c')));
    expect(rect.width, 840);
    expect(rect.left, 220);
  });

  testWidgets('ContentWidth dar ekranda tam genişlik kullanır', (t) async {
    await _pumpAt(
      t,
      const Size(360, 800),
      const ContentWidth(child: SizedBox(key: Key('c'), height: 10)),
    );
    expect(t.getRect(find.byKey(const Key('c'))).width, 360);
  });

  group('testScreens', () {
    final seen = <(Size, double, String)>[];
    testScreens('beş durum', (t, screen) async {
      await pumpApp(
        t,
        Builder(
          builder: (c) {
            final mq = MediaQuery.of(c);
            seen.add((mq.size, mq.textScaler.scale(10) / 10, screen.label));
            return const SizedBox();
          },
        ),
        screen: screen,
      );
    });

    test('beş varyasyon üretir, boyut ve yazı ölçeği doğru', () {
      expect(seen.map((s) => (s.$1, s.$2)), [
        (const Size(360, 800), 1.0),
        (const Size(320, 568), 1.0),
        (const Size(800, 360), 1.0),
        (const Size(1280, 800), 1.0),
        (const Size(360, 800), 2.0),
      ]);
      expect(seen.map((s) => s.$3), [
        'dikey',
        'küçük',
        'yatay',
        'geniş',
        'büyük yazı',
      ]);
    });
  });

  testWidgets('pumpApp yazı ölçeğini test sonunda sıfırlar', (t) async {
    late double scale;
    await pumpApp(
      t,
      Builder(
        builder: (c) {
          scale = MediaQuery.textScalerOf(c).scale(10) / 10;
          return const SizedBox();
        },
      ),
    );
    expect(scale, 1.0);
  });

  testWidgets('yatay ekranda çentik payı (sol 32 dp) verilir', (t) async {
    late EdgeInsets padding;
    await pumpApp(
      t,
      Builder(
        builder: (c) {
          padding = MediaQuery.viewPaddingOf(c);
          return const SizedBox();
        },
      ),
      screen: ScreenCase.landscape,
    );
    expect(padding.left, 32);
  });

  testWidgets('pumpApp koyu temayı kurabilir', (t) async {
    late Brightness b;
    await pumpApp(
      t,
      Builder(
        builder: (c) {
          b = Theme.of(c).brightness;
          return const SizedBox();
        },
      ),
      themeMode: ThemeMode.dark,
    );
    expect(b, Brightness.dark);
  });
}
