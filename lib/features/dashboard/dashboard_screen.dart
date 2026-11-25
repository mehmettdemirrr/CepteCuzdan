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

part 'widgets/summary_cards.dart';
part 'widgets/category_pie_card.dart';
part 'widgets/recent_card.dart';

/// Ana Sayfa: bu ayın geliri, gideri, kalan bütçesi, kategori dağılımı ve
/// son işlemler.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static final _monthTitle = DateFormat('MMMM y', 'tr_TR');

  // Uygulama arka plandan dönünce yeniden yükle: ay değişmiş ya da başka bir
  // yerden veri eklenmiş olabilir.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => context.read<DashboardProvider>().load(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

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
          ? (p.error != null
                ? EmptyState(
                    icon: Icons.error_outline,
                    message: 'Veriler yüklenemedi',
                    action: FilledButton(
                      onPressed: p.load,
                      child: const Text('Tekrar dene'),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()))
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
