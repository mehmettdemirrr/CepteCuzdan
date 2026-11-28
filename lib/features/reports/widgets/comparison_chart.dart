part of '../report_screen.dart';

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
              height: chartHeight(context),
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
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
