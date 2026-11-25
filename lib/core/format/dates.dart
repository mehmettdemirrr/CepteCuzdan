import 'package:intl/intl.dart';

/// Gün bazında, iki ucu da dahil tarih aralığı. Saat bilgisi atılır.
class DateRange {
  DateRange(DateTime start, DateTime end)
    : start = _day(start),
      end = _day(end);

  final DateTime start;
  final DateTime end;

  /// Aralıktaki gün sayısı (iki uç dahil).
  int get days =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;

  bool contains(DateTime d) {
    final day = _day(d);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  bool get isCalendarMonth =>
      start.day == 1 && end == DateTime(start.year, start.month + 1, 0);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange(${toDbDate(start)}, ${toDbDate(end)})';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateRange monthOf(DateTime d) =>
    DateRange(DateTime(d.year, d.month, 1), DateTime(d.year, d.month + 1, 0));

/// Pazartesi–Pazar haftası.
DateRange weekOf(DateTime d) {
  final monday = DateTime(
    d.year,
    d.month,
    d.day - (d.weekday - DateTime.monday),
  );
  return DateRange(monday, DateTime(monday.year, monday.month, monday.day + 6));
}

/// Takvim ayıysa önceki takvim ayı; değilse aynı uzunlukta hemen önceki aralık.
DateRange previousOf(DateRange r) {
  if (r.isCalendarMonth) {
    return monthOf(DateTime(r.start.year, r.start.month - 1, 1));
  }
  final prevEnd = DateTime(r.start.year, r.start.month, r.start.day - 1);
  final prevStart = DateTime(
    prevEnd.year,
    prevEnd.month,
    prevEnd.day - (r.days - 1),
  );
  return DateRange(prevStart, prevEnd);
}

final _dbDate = DateFormat('yyyy-MM-dd');
final _monthKey = DateFormat('yyyy-MM');

/// DB'deki işlem tarihi biçimi: `yyyy-MM-dd` (yerel gün).
String toDbDate(DateTime d) => _dbDate.format(d);

DateTime fromDbDate(String s) => _dbDate.parseStrict(s);

/// Bütçe ayı anahtarı: `yyyy-MM`.
String monthKey(DateTime d) => _monthKey.format(d);
