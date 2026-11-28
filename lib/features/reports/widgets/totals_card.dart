part of '../report_screen.dart';

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
        // Büyük yazıda / dar ekranda Gelir alt satıra iner.
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
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
            if (data.categoryId == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
