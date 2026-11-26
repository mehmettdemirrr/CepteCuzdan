import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/models/enums.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/ui/category_icons.dart';
import 'category_provider.dart';

/// Kategori ekleme/düzenleme alt sayfasını açar.
Future<void> showCategoryEditor(
  BuildContext context, {
  required TxType type,
  Category? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CategoryEditorSheet(type: type, initial: initial),
  );
}

class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({super.key, required this.type, this.initial});

  final TxType type;
  final Category? initial;

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late int _color;
  late String _icon;
  String? _duplicateError;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _color = i?.color ?? categoryPalette.first.toARGB32();
    _icon = i?.icon ?? 'category';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    // Çift dokunmada ikinci kayıt denemesi sayfa kapandıktan sonra
    // bitip setState çağırmasın.
    if (_saving) return;
    setState(() => _duplicateError = null);
    if (!_formKey.currentState!.validate()) return;
    _saving = true;
    final provider = context.read<CategoryProvider>();
    final navigator = Navigator.of(context);
    final i = widget.initial;
    final c = Category(
      id: i?.id,
      name: _name.text.trim(),
      type: i?.type ?? widget.type,
      color: _color,
      icon: _icon,
      isDefault: i?.isDefault ?? false,
    );
    try {
      if (i == null) {
        await provider.add(c);
      } else {
        await provider.update(c);
      }
      navigator.pop();
    } on DuplicateCategoryException {
      if (mounted) setState(() => _duplicateError = 'Bu adda kategori var');
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Varsayılan kategorilerin adı değişmez ("Diğer" yedek kategori olarak
    // adıyla bulunur); yalnızca renk ve ikon düzenlenir.
    final nameEditable = !(widget.initial?.isDefault ?? false);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null ? 'Yeni kategori' : 'Kategoriyi düzenle',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('category-name-field'),
                controller: _name,
                enabled: nameEditable,
                autofocus: widget.initial == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Kategori adı',
                  errorText: _duplicateError,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Kategori adı giriniz'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Renk', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in categoryPalette)
                    _ColorDot(
                      color: color,
                      selected: color.toARGB32() == _color,
                      onTap: () => setState(() => _color = color.toARGB32()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('İkon', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final entry in categoryIcons.entries)
                    IconButton(
                      key: Key('icon-${entry.key}'),
                      isSelected: entry.key == _icon,
                      style: IconButton.styleFrom(
                        backgroundColor: entry.key == _icon
                            ? Color(_color).withValues(alpha: 0.2)
                            : null,
                      ),
                      icon: Icon(
                        entry.value,
                        color: entry.key == _icon ? Color(_color) : null,
                      ),
                      onPressed: () => setState(() => _icon = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Kaydet')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
