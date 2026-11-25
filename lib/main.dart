import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    buildProviders(
      deps: AppDeps.sqlite(db, prefs),
      child: const CepteCuzdanApp(),
    ),
  );
}
