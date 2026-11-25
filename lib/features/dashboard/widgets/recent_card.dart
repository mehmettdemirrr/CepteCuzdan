part of '../dashboard_screen.dart';

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
