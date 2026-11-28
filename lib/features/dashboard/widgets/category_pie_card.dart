part of '../dashboard_screen.dart';

class _CategoryPieCard extends StatelessWidget {
  const _CategoryPieCard({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.summary.expenseTotal;
    if (total == 0) {
      return const _Section(
        title: 'Harcama dağılımı',
        child: EmptyState(
          icon: Icons.pie_chart_outline,
          message: 'Bu ay henüz harcama yok',
        ),
      );
    }
    final categories = context.watch<CategoryProvider>();
    final entries = data.summary.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final theme = Theme.of(context);
    // Yatay ekranda grafik küçülür (dikey 200 → yatay 144 dp); halka
    // kalınlığı ve ortadaki boşluk yükseklikle orantılı.
    final height = chartHeight(context, max: 180);
    final ring = height * 0.2;
    final hole = height * 0.29;

    return _Section(
      title: 'Harcama dağılımı',
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: hole,
                    sections: [
                      for (final e in entries)
                        PieChartSectionData(
                          value: e.value.toDouble(),
                          color: Color(
                            categories.byId(e.key)?.color ?? 0xFF9E9E9E,
                          ),
                          radius: ring,
                          title: e.value / total >= 0.08
                              ? '%${(e.value * 100 / total).round()}'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Toplam', style: theme.textTheme.labelSmall),
                    AmountText(total, style: theme.textTheme.titleSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(categories.byId(e.key)?.color ?? 0xFF9E9E9E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dar ekranda / büyük yazıda yüzde ve tutar alt satıra iner.
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(categories.byId(e.key)?.name ?? 'Kategori'),
                        Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '%${(e.value * 100 / total).round()}',
                              style: theme.textTheme.bodySmall,
                            ),
                            AmountText(e.value),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final ratio = s.expenseTotal / s.incomeTotal;
    final money = MoneyColors.of(context);
    return _Section(
      title: 'Gelir-gider dengesi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 10,
              color: ratio > 1 ? money.expense : money.income,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text('Gelirinin %${(ratio * 100).round()} kadarını harcadın'),
        ],
      ),
    );
  }
}
