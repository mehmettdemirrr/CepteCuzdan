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

class ChangeBadge extends StatelessWidget {
  const ChangeBadge(this.change, {super.key});

  /// `null` = önceki dönemde harcama yok.
  final int? change;

  @override
  Widget build(BuildContext context) {
    final money = MoneyColors.of(context);
    final c = change;
    final (text, color) = switch (c) {
      null => ('Yeni', Theme.of(context).colorScheme.primary),
      0 => ('%0', Theme.of(context).colorScheme.outline),
      // Giderde artış kötü (gider rengi), azalış iyi (gelir rengi).
      > 0 => ('▲ %$c', money.expense),
      _ => ('▼ %${-c}', money.income),
    };
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = MoneyColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Toplam gider', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  AmountText(
                    data.currentTotal,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: money.expense,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (data.currentTotal > 0 || data.previousTotal > 0)
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChangeBadge(data.totalChange),
                        Text(
                          'önceki döneme göre',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (data.categoryId == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Gelir', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  AmountText(
                    data.incomeTotal,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: money.income,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonChart extends StatelessWidget {
  const _ComparisonChart({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();
    final theme = Theme.of(context);
    final rows = data.rows;
    final previousColor = theme.colorScheme.outlineVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              children: [
                _Legend(color: theme.colorScheme.primary, label: 'Bu dönem'),
                _Legend(color: previousColor, label: 'Önceki dönem'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final c = categories.byId(
                            rows[value.toInt()].categoryId,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(
                              iconFor(c?.icon ?? ''),
                              size: 20,
                              color: Color(c?.color ?? 0xFF9E9E9E),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < rows.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: rows[i].previous / 100,
                            color: previousColor,
                            width: 10,
                          ),
                          BarChartRodData(
                            toY: rows[i].current / 100,
                            color: Color(
                              categories.byId(rows[i].categoryId)?.color ??
                                  theme.colorScheme.primary.toARGB32(),
                            ),
                            width: 10,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();
    return Card(
      child: Column(
        children: [
          for (final row in data.rows)
            ListTile(
              leading: categories.byId(row.categoryId) == null
                  ? const CircleAvatar(child: Icon(Icons.help_outline))
                  : CategoryAvatar(categories.byId(row.categoryId)!),
              title: Text(categories.byId(row.categoryId)?.name ?? 'Kategori'),
              subtitle: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Önceki: '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: AmountText(
                        row.previous,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    row.current,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ChangeBadge(row.change),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            key: const Key('breakdown-total'),
            title: Text(
              'Toplam',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  data.currentTotal,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ChangeBadge(data.totalChange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
