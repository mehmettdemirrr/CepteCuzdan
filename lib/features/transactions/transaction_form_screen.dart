import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/format/money.dart';
import '../../core/models/enums.dart';
import '../../core/models/transaction_record.dart';
import '../../core/ui/widgets/category_avatar.dart';
import 'category_provider.dart';
import 'transaction_provider.dart';

/// Gelir/gider ekleme ve düzenleme formu. [initial] verilmezse ya da id'si
/// yoksa yeni kayıt eklenir; aksi halde güncellenir. Kaydın kaynağı
/// (`source`), fiş yolu ve oluşturulma zamanı korunur.
class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.initial});

  final TransactionRecord? initial;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TxType _type;
  late DateTime _date;
  int? _categoryId;
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _note;
  bool _saving = false;

  bool get _isEdit => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final now = DateTime.now();
    _type = i?.type ?? TxType.expense;
    _date = i?.date ?? DateTime(now.year, now.month, now.day);
    _categoryId = i?.categoryId;
    _amount = TextEditingController(
      text: i == null ? '' : formatKurusInput(i.amount),
    );
    _merchant = TextEditingController(text: i?.merchant ?? '');
    _note = TextEditingController(text: i?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final txs = context.read<TransactionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final i = widget.initial;
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final record = TransactionRecord(
      id: i?.id,
      type: _type,
      amount: parseTlToKurus(_amount.text)!,
      categoryId: _categoryId!,
      date: _date,
      merchant: opt(_merchant),
      note: opt(_note),
      source: i?.source ?? TxSource.manual,
      receiptPath: i?.receiptPath,
      createdAt: i?.createdAt ?? DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await txs.update(record);
      } else {
        await txs.add(record);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    messenger.showSnackBar(const SnackBar(content: Text('İşlem kaydedildi')));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().ofType(_type);
    final selected = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'İşlemi düzenle' : 'Yeni işlem')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text('Gider'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TxType.income,
                  label: Text('Gelir'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('amount-field'),
              controller: _amount,
              autofocus: !_isEdit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tutar',
                prefixText: '₺ ',
                hintText: '0,00',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Tutar giriniz';
                if (parseTlToKurus(v) == null) {
                  return 'Geçerli bir tutar giriniz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const Key('category-field'),
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        CategoryAvatar(c, size: 28),
                        const SizedBox(width: 12),
                        Text(c.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Kategori seçiniz' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('date-field'),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tarih',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('d MMMM y, EEEE', 'tr_TR').format(_date),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('merchant-field'),
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'İşletme (isteğe bağlı)',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('note-field'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
