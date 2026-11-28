part of '../report_screen.dart';

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();
    final small = Theme.of(context).textTheme.bodySmall;
    final strong = Theme.of(context).textTheme.titleSmall;
    // Büyük yazıda tutar ve değişim sağa sığmaz; satırın altına iner.
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    Widget amounts(int current, int? change) => large
        ? Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AmountText(current, style: strong),
              ChangeBadge(change),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(current, style: strong),
              ChangeBadge(change),
            ],
          );

    return Card(
      child: Column(
        children: [
          for (final row in data.rows)
            // Ekran okuyucu: önce bu dönem, sonra önceki dönem ve değişim.
            Semantics(
              container: true,
              excludeSemantics: true,
              label:
                  '${categories.byId(row.categoryId)?.name ?? 'Kategori'}: '
                  '${spokenAmount(row.current)}, '
                  'önceki ${spokenAmount(row.previous)}, '
                  '${spokenChange(row.change)}',
              child: ListTile(
                leading: categories.byId(row.categoryId) == null
                    ? const CircleAvatar(child: Icon(Icons.help_outline))
                    : CategoryAvatar(categories.byId(row.categoryId)!),
                title: Text(
                  categories.byId(row.categoryId)?.name ?? 'Kategori',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Önceki: '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: AmountText(row.previous, style: small),
                          ),
                        ],
                      ),
                    ),
                    if (large) amounts(row.current, row.change),
                  ],
                ),
                trailing: large ? null : amounts(row.current, row.change),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            key: const Key('breakdown-total'),
            title: Text('Toplam', style: strong),
            subtitle: large
                ? amounts(data.currentTotal, data.totalChange)
                : null,
            trailing: large
                ? null
                : amounts(data.currentTotal, data.totalChange),
          ),
        ],
      ),
    );
  }
}
