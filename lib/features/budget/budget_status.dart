import '../../core/format/dates.dart';
import '../../core/models/budget.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/transaction_repository.dart';

enum BudgetLevel { ok, warning, exceeded }

/// Harcama limitin %80'ine ulaştıysa uyarı, limiti geçtiyse aşım.
BudgetLevel levelFor({required int spent, required int limit}) {
  if (spent > limit) return BudgetLevel.exceeded;
  if (spent * 100 >= limit * 80) return BudgetLevel.warning;
  return BudgetLevel.ok;
}

/// Bir bütçe limiti ve o ayki harcama (kuruş).
class BudgetLine {
  const BudgetLine({required this.budget, required this.spent});

  final Budget budget;
  final int spent;

  int get remaining => budget.limitAmount - spent;
  double get ratio => spent / budget.limitAmount;
  BudgetLevel get level => levelFor(spent: spent, limit: budget.limitAmount);
}

/// [month] (`yyyy-MM`) için tanımlı her limit ve harcaması. Genel bütçede
/// harcama ayın toplam gideridir; gelirler sayılmaz.
Future<List<BudgetLine>> budgetLinesFor(
  String month, {
  required BudgetRepository budgets,
  required TransactionRepository txs,
}) async {
  final limits = await budgets.forMonth(month);
  if (limits.isEmpty) return const [];
  final summary = await txs.summarize(monthOf(DateTime.parse('$month-01')));
  return [
    for (final b in limits)
      BudgetLine(
        budget: b,
        spent: b.categoryId == null
            ? summary.expenseTotal
            : summary.expenseByCategory[b.categoryId] ?? 0,
      ),
  ];
}
