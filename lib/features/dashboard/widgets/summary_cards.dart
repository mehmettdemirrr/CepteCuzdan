part of '../dashboard_screen.dart';

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overall = data.overall;
    final remaining = data.remaining;
    final cs = Provider.of<CurrencyStyle?>(context) ?? CurrencyStyle.symbol;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kalan Bütçe',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            if (overall == null || remaining == null) ...[
              Text(
                'Bütçe tanımlanmadı',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BudgetSettingsScreen(),
                  ),
                ),
                child: const Text('Bütçe belirle'),
              ),
            ] else ...[
              Text(
                formatKurus(remaining, style: cs),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: remaining < 0
                      ? MoneyColors.of(context).expense
                      : scheme.onPrimaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overall.ratio.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: _levelColor(context, overall.level),
                  backgroundColor: scheme.surface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatKurus(overall.spent, style: cs)} / '
                '${formatKurus(overall.budget.limitAmount, style: cs)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _levelColor(BuildContext context, BudgetLevel level) {
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    BudgetLevel.ok => scheme.primary,
    BudgetLevel.warning => Colors.orange.shade700,
    BudgetLevel.exceeded => MoneyColors.of(context).expense,
  };
}

class _IncomeExpenseRow extends StatelessWidget {
  const _IncomeExpenseRow({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final money = MoneyColors.of(context);
    Widget tile(String label, int amount, Color color, IconData icon) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(
                amount,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
    final income = tile(
      'Gelir',
      data.summary.incomeTotal,
      money.income,
      Icons.arrow_downward,
    );
    final expense = tile(
      'Gider',
      data.summary.expenseTotal,
      money.expense,
      Icons.arrow_upward,
    );
    // Büyük yazıda yan yana sığmaz: alt alta.
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [income, const SizedBox(height: 12), expense],
      );
    }
    return Row(
      children: [
        Expanded(child: income),
        const SizedBox(width: 12),
        Expanded(child: expense),
      ],
    );
  }
}

class _BudgetBadges extends StatelessWidget {
  const _BudgetBadges({required this.lines});
  final List<BudgetLine> lines;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in lines.where((l) => l.level != BudgetLevel.ok))
          Chip(
            avatar: Icon(
              l.level == BudgetLevel.exceeded
                  ? Icons.error_outline
                  : Icons.warning_amber,
              size: 18,
              color: _levelColor(context, l.level),
            ),
            side: BorderSide(color: _levelColor(context, l.level)),
            label: Text(
              '${categories.byId(l.budget.categoryId!)?.name ?? 'Kategori'} '
              '${l.level == BudgetLevel.exceeded ? 'aşıldı' : '%${(l.ratio * 100).floor()}'}',
            ),
          ),
      ],
    );
  }
}
