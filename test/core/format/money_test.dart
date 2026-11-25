import 'package:cepte_cuzdan/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('formatKurus', () {
    test('₺ önde, Türkçe ayırıcılarla biçimler', () {
      expect(formatKurus(123450), '₺1.234,50');
    });

    test('code stilinde TL sonda yazılır', () {
      expect(formatKurus(123450, style: CurrencyStyle.code), '1.234,50 TL');
    });

    test('negatif tutarda eksi işareti başa gelir', () {
      expect(formatKurus(-5000), '-₺50,00');
      expect(formatKurus(-5000, style: CurrencyStyle.code), '-50,00 TL');
    });

    test('sıfır', () {
      expect(formatKurus(0), '₺0,00');
    });
  });

  group('parseTlToKurus', () {
    test('Türkçe biçimli girişleri kuruşa çevirir', () {
      expect(parseTlToKurus('1.234,50'), 123450);
      expect(parseTlToKurus('150'), 15000);
      expect(parseTlToKurus('150,5'), 15050);
      expect(parseTlToKurus(' 150 '), 15000);
    });

    test('yalnızca nokta varsa 1-2 hane ondalık, 3 hane binliktir', () {
      expect(parseTlToKurus('12.50'), 1250);
      expect(parseTlToKurus('12.5'), 1250);
      expect(parseTlToKurus('1.234'), 123400);
      expect(parseTlToKurus('1.234.567'), 123456700);
    });

    test('geçersiz veya sıfır/negatif girişi reddeder', () {
      for (final bad in [
        '0',
        '0,00',
        '-5',
        'abc',
        '',
        '   ',
        '1,2,3',
        '12,345',
        '1.2.3',
      ]) {
        expect(parseTlToKurus(bad), isNull, reason: '"$bad"');
      }
    });
  });

  group('formatKurusInput', () {
    test('form alanı için ₺ işaretsiz yazar ve geri okunabilir', () {
      expect(formatKurusInput(32000), '320,00');
      expect(formatKurusInput(123450), '1.234,50');
      expect(parseTlToKurus(formatKurusInput(123450)), 123450);
    });
  });

  group('tlToKurus', () {
    test('kayan nokta hatasını yuvarlayarak giderir', () {
      expect(tlToKurus(320.00), 32000);
      expect(tlToKurus(19.99), 1999);
      expect(tlToKurus(0.1 + 0.2), 30);
    });
  });
}
