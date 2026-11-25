import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/shell.dart';
import '../../core/format/money.dart';
import '../../core/ui/app_theme.dart';
import '../../core/ui/widgets/amount_text.dart';
import '../../core/ui/widgets/empty_state.dart';
import '../budget/budget_status.dart';
import '../settings/budget_settings_screen.dart';
import '../transactions/category_provider.dart';
import '../transactions/transaction_form_screen.dart';
import '../transactions/transaction_tile.dart';
import 'dashboard_provider.dart';

/// Ana Sayfa: bu ayın geliri, gideri, kalan bütçesi, kategori dağılımı ve
/// son işlemler.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static final _monthTitle = DateFormat('MMMM y', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DashboardProvider>();
    final data = p.data;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          data == null ? 'Ana Sayfa' : _monthTitle.format(data.month),
        ),
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: p.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _RemainingCard(data: data),
                  const SizedBox(height: 12),
                  _IncomeExpenseRow(data: data),
                  if (data.categoryLines.any(
                    (l) => l.level != BudgetLevel.ok,
                  )) ...[
                    const SizedBox(height: 12),
                    _BudgetBadges(lines: data.categoryLines),
                  ],
                  const SizedBox(height: 12),
                  _CategoryPieCard(data: data),
                  if (data.summary.incomeTotal > 0) ...[
                    const SizedBox(height: 12),
                    _BalanceCard(data: data),
                  ],
                  const SizedBox(height: 12),
                  _RecentCard(data: data),
                ],
              ),
            ),
    );
  }
}

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
                formatKurus(remaining),
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
                '${formatKurus(overall.spent)} / '
                '${formatKurus(overall.budget.limitAmount)}',
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
                Text(label, style: Theme.of(context).textTheme.labelLarge),
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
    return Row(
      children: [
        Expanded(
          child: tile(
            'Gelir',
            data.summary.incomeTotal,
            money.income,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: tile(
            'Gider',
            data.summary.expenseTotal,
            money.expense,
            Icons.arrow_upward,
          ),
        ),
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

    return _Section(
      title: 'Harcama dağılımı',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
                    sections: [
                      for (final e in entries)
                        PieChartSectionData(
                          value: e.value.toDouble(),
                          color: Color(
                            categories.byId(e.key)?.color ?? 0xFF9E9E9E,
                          ),
                          radius: 36,
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
                  Expanded(
                    child: Text(categories.byId(e.key)?.name ?? 'Kategori'),
                  ),
                  Text(
                    '%${(e.value * 100 / total).round()}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  AmountText(e.value),
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

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Son işlemler',
      action: TextButton(
        onPressed: () => AppShell.selectTab(context, AppShell.transactionsTab),
        child: const Text('Tümü'),
      ),
      child: data.recent.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Henüz işlem yok',
            )
          : Column(
              children: [
                for (final tx in data.recent)
                  TransactionTile(
                    tx: tx,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TransactionFormScreen(initial: tx),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
