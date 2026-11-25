import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/db/app_database.dart';
import 'features/budget/alert_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  final notifier = LocalAlertNotifier();
  await notifier.init();
  runApp(
    buildProviders(
      deps: AppDeps.sqlite(db, prefs, notifier),
      child: const CepteCuzdanApp(),
    ),
  );
  // Bildirim izni uygulama açıldıktan sonra istenir.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => notifier.requestPermission(),
  );
}
