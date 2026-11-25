import 'package:cepte_cuzdan/app/providers.dart';
import 'package:cepte_cuzdan/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_repositories.dart';

/// Widget testleri için sahte bağımlılıklar.
class TestDeps {
  TestDeps({this.initialPrefs = const {}});

  final repos = FakeRepos();

  /// `SharedPreferences.setMockInitialValues` için başlangıç değerleri.
  final Map<String, Object> initialPrefs;

  FakeTransactionRepository get txs => repos.txs;
  FakeCategoryRepository get categories => repos.categories;
  FakeBudgetRepository get budgets => repos.budgets;
  FakeChatMessageRepository get chats => repos.chats;

  Future<AppDeps> build() async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    return AppDeps(
      txs: txs,
      categories: categories,
      budgets: budgets,
      chats: chats,
      prefs: await SharedPreferences.getInstance(),
    );
  }
}

/// [child]'ı uygulamanın teması ve Türkçe yerelleştirmesiyle sarar. [deps]
/// verilirse uygulamanın provider ağacı sahte repository'lerle kurulur.
Future<void> pumpApp(WidgetTester t, Widget child, {TestDeps? deps}) async {
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';
  Widget app = MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
  if (deps != null) {
    app = buildProviders(deps: await deps.build(), child: app);
  }
  await t.pumpWidget(app);
  // Provider'ların ilk async yüklemesini (kategoriler vb.) bitir.
  await t.pump();
  await t.pump();
}
