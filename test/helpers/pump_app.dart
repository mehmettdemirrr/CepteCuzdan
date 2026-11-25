import 'package:cepte_cuzdan/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// [child]'ı uygulamanın teması ve Türkçe yerelleştirmesiyle sarar.
Future<void> pumpApp(WidgetTester t, Widget child) async {
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}
