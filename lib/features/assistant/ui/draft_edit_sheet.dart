import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/format/text.dart';
import '../../../core/models/enums.dart';
import '../services/gemini/parsed_expense_draft.dart';

/// Onay kartındaki taslağı (kalemler dahil) düzenlemek için kaydırılabilir alt sayfa.
Future<ParsedExpenseDraft?> showDraftEditSheet(
  BuildContext context, {
  required ParsedExpenseDraft initial,
  required Map<TxType, List<String>> categoriesByType,
}) {
  return showModalBottomSheet<ParsedExpenseDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _DraftEditSheet(initial: initial, categoriesByType: categoriesByType),
  );
}

class _EditableItemRow {
  _EditableItemRow({
    required String name,
    required double quantity,
    required double priceTl,
  }) : nameCtrl = TextEditingController(text: name),
       qtyCtrl = TextEditingController(
         text: quantity == quantity.roundToDouble()
             ? quantity.toInt().toString()
             : quantity.toString(),
       ),
       priceCtrl = TextEditingController(
         text: priceTl.toStringAsFixed(2).replaceAll('.', ','),
       );

  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _DraftEditSheet extends StatefulWidget {
  const _DraftEditSheet({
    required this.initial,
    required this.categoriesByType,
  });

  final ParsedExpenseDraft initial;
  final Map<TxType, List<String>> categoriesByType;

  @override
  State<_DraftEditSheet> createState() => _DraftEditSheetState();
}

class _DraftEditSheetState extends State<_DraftEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TxType _type;
  late String _categoryName;
  late DateTime _date;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _merchantCtrl;
  late final List<_EditableItemRow> _itemRows;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.type;
    _date = widget.initial.date;
    _categoryName = _resolveCategoryForType(widget.initial.categoryName, _type);
    _amountCtrl = TextEditingController(
      text: widget.initial.amountTl.toStringAsFixed(2).replaceAll('.', ','),
    );
    _merchantCtrl = TextEditingController(text: widget.initial.merchant ?? '');
    _itemRows = widget.initial.items
        .map(
          (i) => _EditableItemRow(
            name: i.name,
            quantity: i.quantity,
            priceTl: i.priceTl,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    for (final row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  List<String> _optionsFor(TxType type) {
    final list = widget.categoriesByType[type] ?? const ['Diğer'];
    return list.isEmpty ? const ['Diğer'] : list;
  }

  String _resolveCategoryForType(String current, TxType type) {
    final options = _optionsFor(type);
    final folded = foldTr(current);
    for (final opt in options) {
      if (foldTr(opt) == folded) return opt;
    }
    for (final opt in options) {
      if (foldTr(opt) == foldTr('Diğer')) return opt;
    }
    return options.first;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  void _addItemRow() {
    setState(() {
      _itemRows.add(_EditableItemRow(name: '', quantity: 1, priceTl: 0));
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      final removed = _itemRows.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amountKurus = parseTlToKurus(_amountCtrl.text);
    if (amountKurus == null || amountKurus <= 0) return;

    final parsedItems = <ParsedReceiptItem>[];
    for (final row in _itemRows) {
      final name = row.nameCtrl.text.trim();
      final priceKurus = parseTlToKurus(row.priceCtrl.text);
      if (name.isEmpty || priceKurus == null || priceKurus <= 0) continue;
      final qty =
          double.tryParse(row.qtyCtrl.text.trim().replaceAll(',', '.')) ?? 1;
      parsedItems.add(
        ParsedReceiptItem(
          name: name,
          quantity: qty > 0 ? qty : 1,
          priceTl: priceKurus / 100.0,
        ),
      );
    }

    final merchant = _merchantCtrl.text.trim();
    Navigator.of(context).pop(
      ParsedExpenseDraft(
        type: _type,
        amountTl: amountKurus / 100.0,
        merchant: merchant.isEmpty ? null : merchant,
        date: _date,
        categoryName: _categoryName,
        source: widget.initial.source,
        items: parsedItems,
        usedDefaultDate: false,
        usedFallbackCategory: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final options = _optionsFor(_type);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Taslağı düzenle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('Gider')),
                  ButtonSegment(value: TxType.income, label: Text('Gelir')),
                ],
                selected: {_type},
                onSelectionChanged: (sel) {
                  final next = sel.first;
                  setState(() {
                    _type = next;
                    _categoryName = _resolveCategoryForType(
                      _categoryName,
                      next,
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tutar (TL)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final kurus = parseTlToKurus(value ?? '');
                  if (kurus == null || kurus <= 0) {
                    return 'Geçerli ve pozitif bir tutar girin.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: options.contains(_categoryName)
                    ? _categoryName
                    : options.first,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final name in options)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _categoryName = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _merchantCtrl,
                decoration: const InputDecoration(
                  labelText: 'İşletme / Kaynak (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Tarih: ${toDbDate(_date)}'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ürün kalemleri',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addItemRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Kalem ekle'),
                  ),
                ],
              ),
              for (var i = 0; i < _itemRows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _itemRows[i].nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ürün',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _itemRows[i].priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tutar (TL)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kalemi sil',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () => _removeItemRow(i),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _submit,
                    child: const Text('Taslağı güncelle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
