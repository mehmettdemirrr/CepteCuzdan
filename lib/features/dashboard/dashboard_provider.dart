import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../../core/format/dates.dart';
import '../../core/models/period_summary.dart';
import '../../core/models/transaction_record.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../budget/budget_status.dart';
import '../transactions/transaction_provider.dart';

/// Ana Sayfa'nın bu ay için gösterdiği her şey.
class DashboardData {
  const DashboardData({
    required this.month,
    required this.summary,
    required this.budgetLines,
    required this.recent,
  });

  /// Ayın ilk günü.
  final DateTime month;
  final PeriodSummary summary;
  final List<BudgetLine> budgetLines;
  final List<TransactionRecord> recent;

  BudgetLine? get overall {
    for (final l in budgetLines) {
      if (l.budget.isOverall) return l;
    }
    return null;
  }

  List<BudgetLine> get categoryLines =>
      budgetLines.where((l) => !l.budget.isOverall).toList();

  /// Genel bütçe yoksa `null`.
  int? get remaining => overall?.remaining;
}

/// Dashboard verisini yükler; [events] her değiştiğinde (işlem eklendi,
/// silindi, bütçe kaydedildi) yeniden yükler.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required this.txs,
    required this.budgets,
    required this.events,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    events.addListener(load);
  }

  final TransactionRepository txs;
  final BudgetRepository budgets;
  final TransactionProvider events;
  final DateTime Function() clock;

  DashboardData? _data;
  bool _loading = false;
  bool _disposed = false;
  int _generation = 0;

  Object? _error;

  DashboardData? get data => _data;
  bool get loading => _loading;

  /// Son yükleme hata verdiyse hata; başarılı yüklemede temizlenir.
  Object? get error => _error;

  /// Ay her yüklemede saatten hesaplanır; uygulamaya geri dönülünce de
  /// çağrılır (ay değişmiş olabilir).
  Future<void> load() async {
    final generation = ++_generation;
    _loading = true;
    try {
      final now = clock();
      final range = monthOf(now);
      final summary = await txs.summarize(range);
      final lines = await budgetLinesFor(
        monthKey(now),
        budgets: budgets,
        txs: txs,
        summary: summary,
      );
      final recent = await txs.query(limit: 5);
      // Arada daha yeni bir yükleme başladıysa bu sonucu at.
      if (_disposed || generation != _generation) return;
      _data = DashboardData(
        month: range.start,
        summary: summary,
        budgetLines: lines,
        recent: recent,
      );
      _error = null;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      debugPrint('Dashboard yüklenemedi: $e');
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    events.removeListener(load);
    super.dispose();
  }
}
