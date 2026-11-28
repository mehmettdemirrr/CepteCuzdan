import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hocanın istediği ekran boyutları (mantıksal piksel).
enum TestScreen {
  phone(Size(360, 800)),
  small(Size(320, 568)),
  landscape(Size(800, 360)),
  tablet(Size(1280, 800));

  const TestScreen(this.size);
  final Size size;
}

/// Bir ekran boyutu + yazı ölçeği + sistem payları (durum çubuğu, çentik).
class ScreenCase {
  const ScreenCase(
    this.label,
    this.screen, {
    this.textScale = 1.0,
    this.padding = const EdgeInsets.only(top: 24),
  });

  final String label;
  final TestScreen screen;
  final double textScale;

  /// Sistemin kapladığı alan (`MediaQuery.viewPadding`).
  final EdgeInsets padding;

  Size get size => screen.size;

  static const phone = ScreenCase('dikey', TestScreen.phone);
  static const small = ScreenCase('küçük', TestScreen.small);

  /// Yatay telefon: solda çentik (kamera deliği) için 32 dp pay.
  static const landscape = ScreenCase(
    'yatay',
    TestScreen.landscape,
    padding: EdgeInsets.only(top: 24, left: 32),
  );
  static const tablet = ScreenCase('geniş', TestScreen.tablet);
  static const largeText = ScreenCase(
    'büyük yazı',
    TestScreen.phone,
    textScale: 2.0,
  );

  static const all = [phone, small, landscape, tablet, largeText];

  @override
  String toString() => label;
}

/// [body]'yi beş durumda ayrı testler olarak çalıştırır: dikey, küçük, yatay,
/// geniş (yazı 1,0×) ve dikey + yazı 2,0×. Test adına "[yatay]" gibi durum
/// eklenir. Gövde ekranı `pumpApp(t, ..., screen: screen)` ile kurar.
void testScreens(
  String description,
  Future<void> Function(WidgetTester t, ScreenCase screen) body, {
  List<ScreenCase> cases = ScreenCase.all,
}) {
  for (final c in cases) {
    testWidgets('$description [${c.label}]', (t) => body(t, c));
  }
}
