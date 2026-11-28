import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/shell.dart';
import '../../core/format/money.dart';
import '../../core/ui/app_theme.dart';
import '../../core/ui/responsive.dart';
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
              child: SafeArea(top: false, child: _DashboardBody(data: data)),
            ),
    );
  }
}

/// Dar ekranda tek sütun; geniş ekranda ve yatay telefonda solda bütçe ve
/// özet kartları, sağda harcama dağılımı ve son işlemler.
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final left = <Widget>[
      _RemainingCard(data: data),
      gap,
      _IncomeExpenseRow(data: data),
      if (data.categoryLines.any((l) => l.level != BudgetLevel.ok)) ...[
        gap,
        _BudgetBadges(lines: data.categoryLines),
      ],
      if (data.summary.incomeTotal > 0) ...[gap, _BalanceCard(data: data)],
    ];
    final right = <Widget>[
      _CategoryPieCard(data: data),
      gap,
      _RecentCard(data: data),
    ];
    const padding = EdgeInsets.fromLTRB(16, 8, 16, 24);

    if (!isWide(context)) {
      return ListView(padding: padding, children: [...left, gap, ...right]);
    }
    return ListView(
      padding: padding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            const SizedBox(width: 16),
            Expanded(child: Column(children: right)),
          ],
        ),
      ],
    );
  }
}
