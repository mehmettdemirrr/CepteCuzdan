import 'package:cepte_cuzdan/features/settings/data_resetter.dart';
import 'package:cepte_cuzdan/features/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('DataResetter sıfırlama sinyali', () {
    test(
      'başarılı sıfırlamada resets bir artar ve dinleyicileri bilgilendirir',
      () async {
        SharedPreferences.setMockInitialValues({});
        final resetter = DataResetter(
          reset: () async {},
          prefs: await SharedPreferences.getInstance(),
        );
        final seen = <int>[];
        resetter.resets.addListener(() => seen.add(resetter.resets.value));
        expect(resetter.resets.value, 0);

        await resetter();
        await resetter();

        expect(resetter.resets.value, 2);
        expect(seen, [1, 2]);
      },
    );

    test(
      'sinyal geldiğinde veriler ve uyarı kayıtları zaten silinmiştir',
      () async {
        SharedPreferences.setMockInitialValues({
          'alert_2026-11_1_warning': true,
        });
        final prefs = await SharedPreferences.getInstance();
        var dataCleared = false;
        final resetter = DataResetter(
          reset: () async => dataCleared = true,
          prefs: prefs,
        );
        bool? clearedAtSignal;
        bool? alertKeyAtSignal;
        resetter.resets.addListener(() {
          clearedAtSignal = dataCleared;
          alertKeyAtSignal = prefs.containsKey('alert_2026-11_1_warning');
        });

        await resetter();

        expect(clearedAtSignal, isTrue);
        expect(alertKeyAtSignal, isFalse);
      },
    );

    test('başarısız sıfırlamada sinyal gelmez', () async {
      SharedPreferences.setMockInitialValues({});
      final resetter = DataResetter(
        reset: () async => throw StateError('disk dolu'),
        prefs: await SharedPreferences.getInstance(),
      );
      var notified = false;
      resetter.resets.addListener(() => notified = true);

      await expectLater(resetter(), throwsStateError);

      expect(resetter.resets.value, 0);
      expect(notified, isFalse);
    });
  });

  testWidgets('Ayarlar\'dan sıfırlama uygulama ağacındaki sinyali tetikler', (
    t,
  ) async {
    await pumpApp(t, const SettingsScreen(), deps: TestDeps());
    final resets = t
        .element(find.byType(SettingsScreen))
        .read<DataResetter>()
        .resets;
    expect(resets.value, 0);

    await t.scrollUntilVisible(find.text('Verileri sıfırla'), 100);
    await t.tap(find.text('Verileri sıfırla'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sıfırla'));
    await t.pumpAndSettle();

    expect(resets.value, 1);
  });
}
