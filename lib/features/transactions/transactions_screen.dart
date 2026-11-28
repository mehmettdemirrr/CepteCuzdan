import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/ui/responsive.dart';

import '../../core/models/transaction_record.dart';
import '../../core/ui/widgets/empty_state.dart';
import 'category_management_screen.dart';
import 'transaction_form_screen.dart';
import 'transaction_provider.dart';
import 'transaction_tile.dart';

/// İşlemler sekmesi: tüm kayıtlar gün gün, en yeni önce. Dokununca düzenle,
/// sola kaydırınca sil.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int? _revision;
  Future<List<TransactionRecord>>? _future;
  List<TransactionRecord>? _last;

  /// Kaydırılarak silinen işlemler; liste yeniden yüklenene kadar
  /// Dismissible'ın ağaçta kalmaması için hemen gizlenir.
  final _dismissed = <int>{};

  /// Silinemeyip geri gelen satırların anahtar sürümü: aynı karede yeniden
  /// eklenen satır yeni bir Dismissible olsun (eskisi "kapatıldı" durumunda).
  final _restored = <int, int>{};

  static final _dayHeader = DateFormat('d MMMM y EEEE', 'tr_TR');

  void _openForm([TransactionRecord? tx]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionFormScreen(initial: tx),
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('İşlem silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final txs = context.watch<TransactionProvider>();
    if (_revision != txs.revision) {
      _revision = txs.revision;
      _future = txs.query();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('İşlemler'),
        actions: [
          IconButton(
            tooltip: 'Kategoriler',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoryManagementScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('İşlem ekle'),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: FutureBuilder<List<TransactionRecord>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasData) _last = snap.data;
              // Yükleme hatası: önceki liste varsa o gösterilir, yoksa hata.
              if (snap.hasError && _last == null) {
                return EmptyState(
                  icon: Icons.error_outline,
                  message: 'İşlemler yüklenemedi',
                  action: FilledButton(
                    onPressed: () {
                      final retry = context.read<TransactionProvider>().query();
                      setState(() {
                        _future = retry;
                      });
                    },
                    child: const Text('Tekrar dene'),
                  ),
                );
              }
              final list = (snap.data ?? _last)
                  ?.where((t) => !_dismissed.contains(t.id))
                  .toList();
              if (list == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'Henüz işlem yok',
                );
              }
              return _buildList(list);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<TransactionRecord> list) {
    final rows = <Widget>[];
    DateTime? day;
    for (final tx in list) {
      if (tx.date != day) {
        day = tx.date;
        rows.add(_DayHeader(_dayHeader.format(tx.date)));
      }
      rows.add(
        Dismissible(
          key: ValueKey('tx-${tx.id}-${_restored[tx.id] ?? 0}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          confirmDismiss: (_) => _confirmDelete(),
          onDismissed: (_) async {
            setState(() => _dismissed.add(tx.id!));
            final messenger = ScaffoldMessenger.of(context);
            try {
              await context.read<TransactionProvider>().delete(tx.id!);
            } catch (e) {
              // Silinemeyen satır listeye geri döner.
              debugPrint('İşlem silinemedi: $e');
              if (mounted) {
                setState(() {
                  _dismissed.remove(tx.id);
                  _restored.update(tx.id!, (v) => v + 1, ifAbsent: () => 1);
                });
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('İşlem silinemedi')),
              );
              return;
            }
            messenger.showSnackBar(
              const SnackBar(content: Text('İşlem silindi')),
            );
          },
          child: TransactionTile(tx: tx, onTap: () => _openForm(tx)),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.only(bottom: 88), children: rows);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
