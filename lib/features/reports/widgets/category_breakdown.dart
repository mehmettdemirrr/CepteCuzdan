part of '../report_screen.dart';

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
