import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import 'alert_notifier.dart';
import 'budget_status.dart';

/// İşlem değiştikçe o ayın limitlerini kontrol eder; %80'e ulaşılınca ve
/// limit aşılınca bir kez yerel bildirim gösterir. Gösterilen bildirimler
/// `alert_<yyyy-MM>_<kategoriId|all>_<warning|exceeded>` anahtarlarıyla
/// hatırlanır; harcama eşiğin altına inerse anahtar silinir.
class BudgetAlertService {
  BudgetAlertService({
    required this.budgets,
    required this.txs,
    required this.categories,
    required this.notifier,
    required this.prefs,
  });

  final BudgetRepository budgets;
  final TransactionRepository txs;
  final CategoryRepository categories;
  final AlertNotifier notifier;
  final SharedPreferences prefs;

  static const keyPrefix = 'alert_';

  Future<void> checkMonth(DateTime anyDayInMonth) async {
    final month = monthKey(anyDayInMonth);
    final lines = await budgetLinesFor(month, budgets: budgets, txs: txs);
    if (lines.isEmpty) return;
    final names = {for (final c in await categories.all()) c.id: c.name};

    for (final line in lines) {
      final categoryId = line.budget.categoryId;
      final scope = categoryId?.toString() ?? 'all';
      final warningKey = '$keyPrefix${month}_${scope}_warning';
      final exceededKey = '$keyPrefix${month}_${scope}_exceeded';
      final name = categoryId == null
          ? 'Aylık bütçe'
          : names[categoryId] ?? 'Kategori';
      final limit = line.budget.limitAmount;

      switch (line.level) {
        case BudgetLevel.ok:
          await prefs.remove(warningKey);
          await prefs.remove(exceededKey);
        case BudgetLevel.warning:
          await prefs.remove(exceededKey);
          if (!prefs.containsKey(warningKey)) {
            await _show(
              id: (categoryId ?? 0) * 10 + 1,
              title: 'Bütçe uyarısı',
              body:
                  "$name limitinin %80'ine ulaştın: "
                  '${formatKurus(line.spent)} / ${formatKurus(limit)}',
            );
            await prefs.setBool(warningKey, true);
          }
        case BudgetLevel.exceeded:
          if (!prefs.containsKey(exceededKey)) {
            await _show(
              id: (categoryId ?? 0) * 10 + 2,
              title: 'Bütçe aşıldı',
              body: '$name limitini ${formatKurus(-line.remaining)} aştın',
            );
            await prefs.setBool(exceededKey, true);
          }
          // Aşımdan sonra %80 uyarısı ayrıca gelmesin.
          await prefs.setBool(warningKey, true);
      }
    }
  }

  /// Bildirim gösterilemezse (izin yok vb.) kayıt akışı bozulmasın.
  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await notifier.show(id: id, title: title, body: body);
    } catch (e) {
      debugPrint('Bildirim gösterilemedi: $e');
    }
  }
}
