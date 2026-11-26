import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/models/enums.dart';
import '../../core/ui/widgets/category_avatar.dart';
import 'category_editor_sheet.dart';
import 'category_provider.dart';

/// Gider ve gelir kategorilerini listeler; ekleme, düzenleme, silme.
class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Kategoriler'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Gider'),
                Tab(text: 'Gelir'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Kategori ekle'),
            onPressed: () {
              final index = DefaultTabController.of(context).index;
              showCategoryEditor(
                context,
                type: index == 0 ? TxType.expense : TxType.income,
              );
            },
          ),
          body: const TabBarView(
            children: [
              _CategoryList(TxType.expense),
              _CategoryList(TxType.income),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList(this.type);
  final TxType type;

  Future<void> _delete(BuildContext context, Category c) async {
    final provider = context.read<CategoryProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Kategori silinsin mi?'),
        content: Text(
          '"${c.name}" silinecek. İşlemleri "Diğer" kategorisine taşınacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.delete(c.id!);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().ofType(type);
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final c in categories)
          ListTile(
            leading: CategoryAvatar(c),
            title: Text(c.name),
            subtitle: c.isDefault ? const Text('Varsayılan') : null,
            onTap: () => showCategoryEditor(context, type: type, initial: c),
            trailing: c.isDefault
                ? null
                : IconButton(
                    key: Key('delete-category-${c.id}'),
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, c),
                  ),
          ),
      ],
    );
  }
}
