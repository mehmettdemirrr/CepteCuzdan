import 'package:cepte_cuzdan/core/models/category.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/features/transactions/category_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('varsayılan kategoride sil düğmesi yok, eklenende var', (
    t,
  ) async {
    final d = TestDeps();
    final id = await d.categories.add(
      const Category(
        name: 'Kahve',
        type: TxType.expense,
        color: 0xFF795548,
        icon: 'local_cafe',
      ),
    );
    await pumpApp(t, const CategoryManagementScreen(), deps: d);
    await t.pumpAndSettle();

    expect(find.text('Market'), findsOneWidget);
    expect(find.byKey(const Key('delete-category-1')), findsNothing);
    expect(find.byKey(Key('delete-category-$id')), findsOneWidget);
  });

  testWidgets('yeni kategori eklenir', (t) async {
    final d = TestDeps();
    await pumpApp(t, const CategoryManagementScreen(), deps: d);
    await t.pumpAndSettle();

    await t.tap(find.text('Kategori ekle'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('category-name-field')), 'Kahve');
    await t.tap(find.byKey(const Key('icon-local_cafe')));
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();

    final c = await d.categories.findByName('Kahve', TxType.expense);
    expect(c, isNotNull);
    expect(c!.icon, 'local_cafe');
    expect(find.text('Kahve'), findsOneWidget);
  });

  testWidgets('gelir sekmesinde eklenen kategori gelir tipindedir', (t) async {
    final d = TestDeps();
    await pumpApp(t, const CategoryManagementScreen(), deps: d);
    await t.pumpAndSettle();
    await t.tap(find.text('Gelir'));
    await t.pumpAndSettle();
    expect(find.text('Maaş'), findsOneWidget);

    await t.tap(find.text('Kategori ekle'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('category-name-field')), 'Burs');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(await d.categories.findByName('Burs', TxType.income), isNotNull);
  });

  testWidgets('aynı ad ve tipte kategori eklenemez', (t) async {
    final d = TestDeps();
    await pumpApp(t, const CategoryManagementScreen(), deps: d);
    await t.pumpAndSettle();

    await t.tap(find.text('Kategori ekle'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('category-name-field')), 'Market');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();

    expect(find.text('Bu adda kategori var'), findsOneWidget);
    expect(
      (await d.categories.all(type: TxType.expense))
          .where((c) => c.name == 'Market'),
      hasLength(1),
    );
  });

  testWidgets('boş adla kategori eklenemez', (t) async {
    await pumpApp(t, const CategoryManagementScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    await t.tap(find.text('Kategori ekle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(find.text('Kategori adı giriniz'), findsOneWidget);
  });

  testWidgets('kategori onaylanınca silinir', (t) async {
    final d = TestDeps();
    final id = await d.categories.add(
      const Category(
        name: 'Kahve',
        type: TxType.expense,
        color: 0,
        icon: 'local_cafe',
      ),
    );
    await pumpApp(t, const CategoryManagementScreen(), deps: d);
    await t.pumpAndSettle();

    await t.tap(find.byKey(Key('delete-category-$id')));
    await t.pumpAndSettle();
    expect(
      find.textContaining('"Diğer" kategorisine taşınacak'),
      findsOneWidget,
    );
    await t.tap(find.text('Sil'));
    await t.pumpAndSettle();
    expect(await d.categories.findByName('Kahve', TxType.expense), isNull);
    expect(find.text('Kahve'), findsNothing);
  });

  testWidgets('varsayılan kategorinin adı değiştirilemez', (t) async {
    await pumpApp(t, const CategoryManagementScreen(), deps: TestDeps());
    await t.pumpAndSettle();
    await t.tap(find.text('Diğer'));
    await t.pumpAndSettle();
    final field = t.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('category-name-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.enabled, isFalse);
  });
}
