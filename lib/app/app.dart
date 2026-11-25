import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/ui/app_theme.dart';
import 'shell.dart';

class CepteCuzdanApp extends StatelessWidget {
  const CepteCuzdanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CepteCüzdan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(
        pages: [
          _ComingSoon('Ana Sayfa'),
          // Berkay: Asistan ekranı hazır olunca bu satırı kendi ekranınla değiştir.
          _ComingSoon('Asistan'),
          _ComingSoon('İşlemler'),
          _ComingSoon('Raporlar'),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title yakında')),
    );
  }
}
