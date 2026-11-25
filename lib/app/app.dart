import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/ui/app_theme.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/reports/report_screen.dart';
import '../features/settings/settings_provider.dart';
import '../features/transactions/transactions_screen.dart';
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
      themeMode: context.watch<SettingsProvider>().themeMode,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(
        pages: [
          DashboardScreen(),
          // Berkay: Asistan ekranı hazır olunca bu satırı kendi ekranınla değiştir.
          _ComingSoon('Asistan'),
          TransactionsScreen(),
          ReportScreen(),
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
