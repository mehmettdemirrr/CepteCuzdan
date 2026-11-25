import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/models/enums.dart';
import '../../core/ui/app_theme.dart';
import '../../core/ui/category_icons.dart';
import '../../core/ui/widgets/amount_text.dart';
import '../../core/ui/widgets/category_avatar.dart';
import '../../core/ui/widgets/empty_state.dart';
import '../settings/settings_screen.dart';
import '../transactions/category_provider.dart';
import '../transactions/transaction_form_screen.dart';
import '../transactions/transaction_tile.dart';
import 'report_math.dart';
import 'report_provider.dart';

part 'widgets/totals_card.dart';
part 'widgets/comparison_chart.dart';
part 'widgets/category_breakdown.dart';

/// Raporlar sekmesi: haftalık/aylık/özel dönem gider dökümü, önceki dönemle
/// kıyas, kategori filtresi ve dönemin işlemleri.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  Future<void> _pickCustom(BuildContext context, ReportProvider p) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: p.range.start, end: p.range.end),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      await p.setCustomRange(DateRange(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ReportProvider>();
    final data = p.data;
    final categories = context.watch<CategoryProvider>().ofType(TxType.expense);
    // Filtredeki kategori silindiyse (kategori yönetimi, veri sıfırlama)
    // filtreyi temizle; açılır liste olmayan bir değerle çizilmesin.
    final categoryExists = categories.any((c) => c.id == p.categoryId);
    if (p.categoryId != null && !categoryExists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!categories.any((c) => c.id == p.categoryId)) p.setCategory(null);
      });
    }
    final selectedCategory = categoryExists ? p.categoryId : null;
    final isCustom = p.period == ReportPeriod.custom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedButton<ReportPeriod>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ReportPeriod.week, label: Text('Haftalık')),
              ButtonSegment(value: ReportPeriod.month, label: Text('Aylık')),
              ButtonSegment(value: ReportPeriod.custom, label: Text('Özel')),
            ],
            selected: {p.period},
            onSelectionChanged: (s) {
              if (s.first == ReportPeriod.custom) {
                _pickCustom(context, p);
              } else {
                p.setPeriod(s.first);
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                key: const Key('report-prev'),
                tooltip: 'Önceki dönem',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => p.shift(-1),
              ),
              Expanded(
                // Özel dönemde "Özel" düğmesi tekrar basılınca tetiklenmediği
                // için aralık etiketine dokunarak yeni aralık seçilir.
                child: InkWell(
                  key: const Key('report-range'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: isCustom ? () => _pickCustom(context, p) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            rangeLabel(p.range, p.period),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_calendar, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('report-next'),
                tooltip: 'Sonraki dönem',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => p.shift(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            // Değer dışarıdan değişince (filtre temizlendi) alan yenilensin.
            key: ValueKey('report-category-$selectedCategory'),
            initialValue: selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tüm kategoriler'),
              ),
              for (final c in categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: p.setCategory,
          ),
          const SizedBox(height: 16),
          if (data == null && p.error != null)
            EmptyState(
              icon: Icons.error_outline,
              message: 'Veriler yüklenemedi',
              action: FilledButton(
                onPressed: p.load,
                child: const Text('Tekrar dene'),
              ),
            )
          else if (data == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _TotalsCard(data: data),
            const SizedBox(height: 12),
            if (data.rows.isEmpty)
              const Card(
                child: EmptyState(
                  icon: Icons.bar_chart,
                  message: 'Bu dönemde harcama yok',
                ),
              )
            else ...[
              _ComparisonChart(data: data),
              const SizedBox(height: 12),
              _Breakdown(data: data),
            ],
            const SizedBox(height: 16),
            Text('Döküm', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (data.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Bu dönemde işlem yok'),
              )
            else
              for (final tx in data.transactions)
                TransactionTile(
                  tx: tx,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TransactionFormScreen(initial: tx),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
