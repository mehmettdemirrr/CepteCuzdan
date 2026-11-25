import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../../core/format/dates.dart';
import '../../core/repositories/transaction_repository.dart';
import '../transactions/transaction_provider.dart';
import 'report_math.dart';

/// Raporlar sekmesinin durumu: dönem tipi, aralık, kategori filtresi ve
/// yüklenen veri. İşlemler değişince yeniden yükler.
class ReportProvider extends ChangeNotifier {
  ReportProvider({
    required this.txs,
    required this.events,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    _range = weekOf(this.clock());
    events.addListener(load);
  }

  final TransactionRepository txs;
  final TransactionProvider events;
  final DateTime Function() clock;

  ReportPeriod _period = ReportPeriod.week;
  late DateRange _range;
  int? _categoryId;
  ReportData? _data;
  int _generation = 0;
  bool _disposed = false;

  ReportPeriod get period => _period;
  DateRange get range => _range;
  int? get categoryId => _categoryId;
  ReportData? get data => _data;

  Object? _error;

  /// Son yükleme hata verdiyse hata; başarılı yüklemede temizlenir.
  Object? get error => _error;

  /// Haftalık ve aylıkta bugünün dönemine döner. Özel aralık
  /// [setCustomRange] ile seçilir.
  Future<void> setPeriod(ReportPeriod p) {
    _period = p;
    final now = clock();
    if (p == ReportPeriod.week) _range = weekOf(now);
    if (p == ReportPeriod.month) _range = monthOf(now);
    return load();
  }

  Future<void> setCustomRange(DateRange r) {
    _period = ReportPeriod.custom;
    _range = r;
    return load();
  }

  Future<void> setCategory(int? id) {
    _categoryId = id;
    return load();
  }

  /// Dönemi [delta] kadar ileri (+) ya da geri (−) kaydırır.
  Future<void> shift(int delta) {
    final s = _range.start;
    switch (_period) {
      case ReportPeriod.week:
        _range = weekOf(DateTime(s.year, s.month, s.day + 7 * delta));
      case ReportPeriod.month:
        _range = monthOf(DateTime(s.year, s.month + delta, 1));
      case ReportPeriod.custom:
        final days = _range.days * delta;
        _range = DateRange(
          DateTime(s.year, s.month, s.day + days),
          DateTime(_range.end.year, _range.end.month, _range.end.day + days),
        );
    }
    return load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final range = _range;
    final categoryId = _categoryId;
    final previousRange = previousOf(range);
    try {
      final current = await txs.summarize(range);
      final previous = await txs.summarize(previousRange);
      final list = await txs.query(range: range, categoryId: categoryId);
      if (_disposed || generation != _generation) return;
      _data = ReportData(
        range: range,
        previousRange: previousRange,
        current: current,
        previous: previous,
        transactions: list,
        categoryId: categoryId,
      );
      _error = null;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      debugPrint('Rapor yüklenemedi: $e');
      _error = e;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    events.removeListener(load);
    super.dispose();
  }
}
