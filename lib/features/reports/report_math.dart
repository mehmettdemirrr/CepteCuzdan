import 'package:intl/intl.dart';

import '../../core/format/dates.dart';
import '../../core/models/period_summary.dart';
import '../../core/models/transaction_record.dart';

enum ReportPeriod { week, month, custom }

/// Önceki döneme göre yüzde değişim, tam sayıya yuvarlanmış. Önceki dönem
/// 0 ise kıyas yapılamaz: `null` ("Yeni").
int? changePercent({required int previous, required int current}) {
  if (previous == 0) return null;
  return ((current - previous) * 100 / previous).round();
}

final _dayMonth = DateFormat('d MMMM', 'tr_TR');
final _dayMonthYear = DateFormat('d MMMM y', 'tr_TR');
final _monthYear = DateFormat('MMMM y', 'tr_TR');

/// Rapor başlığındaki dönem adı: `Kasım 2026`, `23–29 Kasım 2026`,
/// `30 Kasım – 6 Aralık 2026`, `20 Aralık 2025 – 5 Ocak 2026`.
String rangeLabel(DateRange r, ReportPeriod period) {
  if (period == ReportPeriod.month) return _monthYear.format(r.start);
  final s = r.start, e = r.end;
  if (s == e) return _dayMonthYear.format(s);
  if (s.year != e.year) {
    return '${_dayMonthYear.format(s)} – ${_dayMonthYear.format(e)}';
  }
  if (s.month != e.month) {
    return '${_dayMonth.format(s)} – ${_dayMonthYear.format(e)}';
  }
  return '${s.day}–${_dayMonthYear.format(e)}';
}

/// Raporda bir gider kategorisinin bu ve önceki dönem toplamı.
class CategoryRow {
  const CategoryRow({
    required this.categoryId,
    required this.current,
    required this.previous,
  });

  final int categoryId;
  final int current;
  final int previous;

  int? get change => changePercent(previous: previous, current: current);
}

/// Bir rapor döneminin sonucu. [categoryId] verilmişse gider toplamları
/// yalnızca o kategoriyi kapsar.
class ReportData {
  const ReportData({
    required this.range,
    required this.previousRange,
    required this.current,
    required this.previous,
    required this.transactions,
    this.categoryId,
  });

  final DateRange range;
  final DateRange previousRange;
  final PeriodSummary current;
  final PeriodSummary previous;
  final List<TransactionRecord> transactions;
  final int? categoryId;

  Map<int, int> _filter(Map<int, int> m) => categoryId == null
      ? m
      : {if (m[categoryId] != null) categoryId!: m[categoryId]!};

  Map<int, int> get currentByCategory => _filter(current.expenseByCategory);
  Map<int, int> get previousByCategory => _filter(previous.expenseByCategory);

  int get currentTotal => currentByCategory.values.fold(0, (a, b) => a + b);
  int get previousTotal => previousByCategory.values.fold(0, (a, b) => a + b);
  int get incomeTotal => current.incomeTotal;

  int? get totalChange =>
      changePercent(previous: previousTotal, current: currentTotal);

  /// Bu ya da önceki dönemde gideri olan kategoriler; bu dönem büyükten
  /// küçüğe, eşitlikte önceki dönem.
  List<CategoryRow> get rows {
    final cur = currentByCategory, prev = previousByCategory;
    final ids = {...cur.keys, ...prev.keys};
    return [
      for (final id in ids)
        CategoryRow(
          categoryId: id,
          current: cur[id] ?? 0,
          previous: prev[id] ?? 0,
        ),
    ]..sort((a, b) {
      final c = b.current.compareTo(a.current);
      return c != 0 ? c : b.previous.compareTo(a.previous);
    });
  }
}
