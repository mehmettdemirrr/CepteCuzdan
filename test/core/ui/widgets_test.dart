import 'package:cepte_cuzdan/core/models/default_categories.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/ui/app_theme.dart';
import 'package:cepte_cuzdan/core/ui/category_icons.dart';
import 'package:cepte_cuzdan/core/ui/widgets/amount_text.dart';
import 'package:cepte_cuzdan/core/ui/widgets/category_avatar.dart';
import 'package:cepte_cuzdan/core/ui/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  final light = AppTheme.light().extension<MoneyColors>()!;

  Color? colorOf(WidgetTester t, String text) =>
      t.widget<Text>(find.text(text)).style?.color;

  testWidgets('AmountText gideri eksi ve gider renginde gösterir', (t) async {
    await pumpApp(t, const AmountText(15000, type: TxType.expense));
    expect(find.text('-₺150,00'), findsOneWidget);
    expect(colorOf(t, '-₺150,00'), light.expense);
  });

  testWidgets('AmountText geliri artı ve gelir renginde gösterir', (t) async {
    await pumpApp(t, const AmountText(15000, type: TxType.income));
    expect(find.text('+₺150,00'), findsOneWidget);
    expect(colorOf(t, '+₺150,00'), light.income);
  });

  testWidgets('AmountText tip verilmezse işaretsiz gösterir', (t) async {
    await pumpApp(t, const AmountText(-5000));
    expect(find.text('-₺50,00'), findsOneWidget);
  });

  testWidgets('CategoryAvatar kategorinin ikonunu gösterir', (t) async {
    await pumpApp(t, CategoryAvatar(defaultCategories.first));
    expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
  });

  testWidgets('EmptyState mesajı ve aksiyonu gösterir', (t) async {
    await pumpApp(
      t,
      EmptyState(
        icon: Icons.inbox,
        message: 'Henüz işlem yok',
        action: TextButton(onPressed: () {}, child: const Text('Ekle')),
      ),
    );
    expect(find.text('Henüz işlem yok'), findsOneWidget);
    expect(find.text('Ekle'), findsOneWidget);
  });

  test('bilinmeyen ikon anahtarı varsayılana düşer', () {
    expect(iconFor('yok'), Icons.category);
    expect(iconFor('shopping_cart'), Icons.shopping_cart);
  });

  test('tüm varsayılan kategori ikonları kayıtlı ve seçim için yeterli', () {
    for (final c in defaultCategories) {
      expect(categoryIcons.containsKey(c.icon), isTrue, reason: c.icon);
    }
    expect(categoryIcons.length, greaterThanOrEqualTo(17));
    expect(categoryPalette, hasLength(10));
  });

  test('iki temada da para renkleri tanımlı ve birbirinden farklı', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final m = theme.extension<MoneyColors>();
      expect(m, isNotNull);
      expect(m!.income, isNot(m.expense));
    }
    expect(AppTheme.dark().brightness, Brightness.dark);
  });
}
