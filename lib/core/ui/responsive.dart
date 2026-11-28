import 'package:flutter/widgets.dart';

/// Bu genişlik ve üstünde yan gezinme (`NavigationRail`) ve iki sütun.
/// Yatay telefon (≈ 800 dp) da geniş sayılır: dikey alan kıt olduğu için
/// alt gezinme çubuğu yerine yan çubuk kullanılır.
const double kWideBreakpoint = 600;

/// Geniş ekranda liste/içerik bu genişlikte ortalanır.
const double kMaxContentWidth = 840;

/// Form ekranlarının en fazla genişliği.
const double kMaxFormWidth = 600;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Grafik yüksekliği: ekran yüksekliğinin %40'ı, [min]–[max] arasında.
/// Dikey 800 dp → 200, yatay 360 dp → 144.
double chartHeight(
  BuildContext context, {
  double max = 200,
  double min = 120,
}) => (MediaQuery.sizeOf(context).height * 0.4).clamp(min, max);

/// İçeriği [maxWidth] ile sınırlayıp yatayda ortalar. Dar ekranda tam
/// genişlik kullanılır.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
