import '../models/budget.dart';

abstract class BudgetRepository {
  /// `yyyy-MM` ayının genel bütçesi ve kategori limitleri.
  Future<List<Budget>> forMonth(String month);

  /// Aynı (categoryId, month) varsa limiti günceller, yoksa ekler.
  /// `categoryId == null` (genel bütçe) için de tekildir.
  Future<void> upsert(Budget b);

  Future<void> delete(int id);
}
