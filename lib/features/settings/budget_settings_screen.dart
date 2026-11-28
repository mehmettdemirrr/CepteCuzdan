import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/ui/responsive.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/models/category.dart';
import '../../core/models/enums.dart';
import '../../core/ui/widgets/category_avatar.dart';
import '../budget/budget_provider.dart';
import '../transactions/category_provider.dart';

/// Bir ayın genel bütçesi ve gider kategorisi limitleri. Boş bırakılan alanın
/// limiti silinir.
class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _overall = TextEditingController();
  final _byCategory = <int, TextEditingController>{};
  late DateTime _month;
  bool _loading = true;
  bool _saving = false;

  static final _monthTitle = DateFormat('MMMM y', 'tr_TR');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _overall.dispose();
    for (final c in _byCategory.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int categoryId) =>
      _byCategory.putIfAbsent(categoryId, TextEditingController.new);

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await context.read<BudgetProvider>().forMonth(
      monthKey(_month),
    );
    if (!mounted) return;
    _overall.text = '';
    for (final c in _byCategory.values) {
      c.text = '';
    }
    for (final b in list) {
      final text = formatKurusInput(b.limitAmount);
      if (b.categoryId == null) {
        _overall.text = text;
      } else {
        _controllerFor(b.categoryId!).text = text;
      }
    }
    _saved = _snapshot();
    setState(() => _loading = false);
  }

  /// Son yüklenen/kaydedilen alan değerleri; değişiklik tespiti için.
  Map<int?, String> _saved = const {};

  Map<int?, String> _snapshot() => {
    null: _overall.text.trim(),
    for (final e in _byCategory.entries) e.key: e.value.text.trim(),
  };

  bool get _dirty {
    final now = _snapshot();
    return now.entries.any((e) => (_saved[e.key] ?? '') != e.value);
  }

  Future<void> _shiftMonth(int delta) async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Kaydedilmemiş değişiklikler silinsin mi?'),
          content: const Text(
            'Bu ayın limitlerinde yaptığın değişiklikler kaydedilmedi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Sil ve geç'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    _month = DateTime(_month.year, _month.month + delta);
    await _load();
  }

  Future<void> _save(List<Category> categories) async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    int? parse(TextEditingController c) =>
        c.text.trim().isEmpty ? null : parseTlToKurus(c.text);

    setState(() => _saving = true);
    try {
      await context.read<BudgetProvider>().save(
        monthKey(_month),
        overall: parse(_overall),
        categoryLimits: {
          for (final c in categories) c.id!: parse(_controllerFor(c.id!)),
        },
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    _saved = _snapshot();
    messenger.showSnackBar(const SnackBar(content: Text('Bütçe kaydedildi')));
  }

  String? _validate(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return parseTlToKurus(v) == null ? 'Geçerli bir tutar giriniz' : null;
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().ofType(TxType.expense);
    const amountKeyboard = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bütçe limitleri'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : () => _save(categories),
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: kMaxFormWidth,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Önceki ay',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _loading || _saving
                          ? null
                          : () => _shiftMonth(-1),
                    ),
                    Expanded(
                      child: Text(
                        _monthTitle.format(_month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sonraki ay',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _loading || _saving
                          ? null
                          : () => _shiftMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  TextFormField(
                    key: const Key('budget-overall'),
                    controller: _overall,
                    keyboardType: amountKeyboard,
                    decoration: const InputDecoration(
                      labelText: 'Aylık genel bütçe',
                      prefixText: '₺ ',
                      helperText: 'Boş bırakırsan genel bütçe olmaz',
                    ),
                    validator: _validate,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Kategori limitleri',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CategoryAvatar(c, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: Key('budget-cat-${c.id}'),
                              controller: _controllerFor(c.id!),
                              keyboardType: amountKeyboard,
                              decoration: InputDecoration(
                                labelText: c.name,
                                prefixText: '₺ ',
                                isDense: true,
                              ),
                              validator: _validate,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
