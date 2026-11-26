import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekOf Pazartesi-Pazar aralığı döner', () {
    expect(
      weekOf(DateTime(2026, 11, 25)),
      DateRange(DateTime(2026, 11, 23), DateTime(2026, 11, 29)),
    );
    // Pazar günü kendi haftasına aittir
    expect(
      weekOf(DateTime(2026, 11, 29, 23, 59)).start,
      DateTime(2026, 11, 23),
    );
    // Pazartesi yeni haftayı başlatır
    expect(weekOf(DateTime(2026, 11, 30)).start, DateTime(2026, 11, 30));
  });

  test('monthOf ayın ilk ve son gününü döner', () {
    expect(
      monthOf(DateTime(2026, 11, 30)),
      DateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
    );
    expect(monthOf(DateTime(2028, 2, 10)).end, DateTime(2028, 2, 29));
    expect(
      monthOf(DateTime(2026, 11, 30)).contains(DateTime(2026, 12, 1)),
      isFalse,
    );
    expect(monthOf(DateTime(2026, 12, 1)).start, DateTime(2026, 12, 1));
  });

  test('contains iki ucu da gün bazında dahil eder', () {
    final r = DateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 30));
    expect(r.contains(DateTime(2026, 11, 1)), isTrue);
    expect(r.contains(DateTime(2026, 11, 30, 23, 59)), isTrue);
    expect(r.contains(DateTime(2026, 10, 31, 23, 59)), isFalse);
  });

  test('DateRange saat bilgisini atar', () {
    expect(
      DateRange(DateTime(2026, 11, 1, 10), DateTime(2026, 11, 2, 22)),
      DateRange(DateTime(2026, 11, 1), DateTime(2026, 11, 2)),
    );
  });

  test(
    'previousOf takvim ayı için önceki ayı, yıl sınırında önceki yılı döner',
    () {
      expect(
        previousOf(monthOf(DateTime(2026, 1, 15))),
        DateRange(DateTime(2025, 12, 1), DateTime(2025, 12, 31)),
      );
      expect(
        previousOf(monthOf(DateTime(2026, 3, 15))),
        DateRange(DateTime(2026, 2, 1), DateTime(2026, 2, 28)),
      );
    },
  );

  test(
    'previousOf diğer aralıklar için aynı uzunlukta hemen önceki aralığı döner',
    () {
      expect(
        previousOf(DateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 16))),
        DateRange(DateTime(2026, 11, 3), DateTime(2026, 11, 9)),
      );
      expect(
        previousOf(weekOf(DateTime(2026, 11, 25))),
        DateRange(DateTime(2026, 11, 16), DateTime(2026, 11, 22)),
      );
    },
  );

  test('DB tarih ve ay anahtarı biçimleri', () {
    expect(toDbDate(DateTime(2026, 11, 8, 23, 59)), '2026-11-08');
    expect(fromDbDate('2026-11-08'), DateTime(2026, 11, 8));
    expect(monthKey(DateTime(2026, 1, 3)), '2026-01');
  });
}
