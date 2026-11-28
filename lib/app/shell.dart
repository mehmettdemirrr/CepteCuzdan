import 'package:flutter/material.dart';

import '../core/ui/responsive.dart';

/// Ana kabuk: dar ekranda alt gezinme çubuğu, geniş ekranda ve yatay
/// telefonda yan gezinme (`NavigationRail`). Sekme sırası: Ana Sayfa, Asistan,
/// İşlemler, Raporlar. Sayfalar [IndexedStack] içinde tutulur, böylece
/// sekme değişince durumlarını kaybetmezler.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.pages});

  final List<Widget> pages;

  static const homeTab = 0;
  static const assistantTab = 1;
  static const transactionsTab = 2;
  static const reportsTab = 3;

  /// Sekmelerin içinden başka bir sekmeye geçmek için (ör. "Tümü" düğmesi).
  static void selectTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_AppShellState>()?._select(index);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Ana Sayfa'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Asistan'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'İşlemler'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Raporlar'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(index: _index, children: widget.pages);

    if (!isWide(context)) {
      return Scaffold(
        body: pages,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final (icon, selected, label) in _items)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    }

    // Geniş ekran ve yatay telefon: yan gezinme. Çubuk soldaki sistem payını
    // (çentik, durum çubuğu) kendisi alır; sayfaya yalnızca sağ pay kalır.
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: _ScrollableRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              items: _items,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: pages,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kısa ekranda (yatay + büyük yazı) öğeler sığmazsa kayan [NavigationRail].
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    // Etiketler 1,5× üstünde büyümez: yan çubuk sayfanın genişliğini
    // yemesin (büyük yazıda "Ana Sayfa" tek başına ekranın üçte birini alır).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (icon, selected, label) in items)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: Text(label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
