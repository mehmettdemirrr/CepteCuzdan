import 'package:flutter/material.dart';

/// Alt gezinme çubuklu ana kabuk. Sekme sırası: Ana Sayfa, Asistan,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: widget.pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Asistan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'İşlemler',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Raporlar',
          ),
        ],
      ),
    );
  }
}
