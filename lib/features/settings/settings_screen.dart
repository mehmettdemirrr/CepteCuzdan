import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/money.dart';
import '../transactions/category_management_screen.dart';
import '../transactions/category_provider.dart';
import '../transactions/transaction_provider.dart';
import 'budget_settings_screen.dart';
import 'data_resetter.dart';
import 'settings_provider.dart';

/// Tema, tutar görünümü, bütçe limitleri, kategoriler ve veri sıfırlama.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Veriler sıfırlansın mı?'),
        content: const Text(
          'Tüm işlemler, bütçeler ve sohbet geçmişi silinecek. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(d).colorScheme.error,
              foregroundColor: Theme.of(d).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final reset = context.read<DataResetter>();
    final txs = context.read<TransactionProvider>();
    final categories = context.read<CategoryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await reset();
    } catch (e) {
      debugPrint('Veri sıfırlama başarısız: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Veriler sıfırlanamadı')),
      );
      return;
    }
    await categories.load();
    txs.markChanged();
    messenger.showSnackBar(const SnackBar(content: Text('Veriler sıfırlandı')));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    Widget group(String title, Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          group(
            'Tema',
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
                ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          group(
            'Tutar görünümü',
            SegmentedButton<CurrencyStyle>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: CurrencyStyle.symbol,
                  label: Text('₺1.234,50'),
                ),
                ButtonSegment(
                  value: CurrencyStyle.code,
                  label: Text('1.234,50 TL'),
                ),
              ],
              selected: {settings.currencyStyle},
              onSelectionChanged: (s) => settings.setCurrencyStyle(s.first),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Bütçe limitleri'),
            subtitle: const Text('Aylık genel bütçe ve kategori limitleri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BudgetSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Kategoriler'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoryManagementScreen(),
              ),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Verileri sıfırla',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text(
              'İşlemler, bütçeler ve sohbet geçmişi silinir',
            ),
            onTap: () => _reset(context),
          ),
        ],
      ),
    );
  }
}
