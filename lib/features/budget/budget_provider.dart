import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../core/models/budget.dart';
import '../../core/repositories/budget_repository.dart';
import '../transactions/transaction_provider.dart';
import 'budget_alert_service.dart';

/// Aylık genel bütçe ve kategori limitlerini okur ve kaydeder. Kayıttan sonra
/// limitler kontrol edilir (aşılmışsa bildirim) ve açık ekranlar yenilenir.
class BudgetProvider extends ChangeNotifier {
  BudgetProvider({
    required this.budgets,
    required this.alerts,
    required this.events,
  });

  final BudgetRepository budgets;
  final BudgetAlertService alerts;
  final TransactionProvider events;

  Future<List<Budget>> forMonth(String month) => budgets.forMonth(month);

  /// [month] (`yyyy-MM`) limitlerini yazar. `null` olan limit silinir.
  /// [categoryLimits] yalnızca formda gösterilen kategorileri içerir.
  Future<void> save(
    String month, {
    required int? overall,
    required Map<int, int?> categoryLimits,
  }) async {
    final existing = await budgets.forMonth(month);
    Future<void> apply(int? categoryId, int? limit) async {
      if (limit == null) {
        for (final b in existing.where((b) => b.categoryId == categoryId)) {
          await budgets.delete(b.id!);
        }
      } else {
        await budgets.upsert(
          Budget(categoryId: categoryId, month: month, limitAmount: limit),
        );
      }
    }

    await apply(null, overall);
    for (final e in categoryLimits.entries) {
      await apply(e.key, e.value);
    }
    await alerts.checkMonth(DateTime.parse('$month-01'));
    events.markChanged();
    notifyListeners();
  }
}
