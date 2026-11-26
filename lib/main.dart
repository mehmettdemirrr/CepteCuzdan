import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/db/app_database.dart';
import 'features/budget/alert_notifier.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase başlatılamazsa uygulama yine açılsın (manuel kayıt çalışmaya devam eder).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase başlatılamadı: $e');
  }
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  final notifier = LocalAlertNotifier();
  // Bildirim altyapısı kurulamazsa uygulama yine açılsın.
  try {
    await notifier.init();
  } catch (e) {
    debugPrint('Bildirimler başlatılamadı: $e');
  }
  runApp(
    buildProviders(
      deps: AppDeps.sqlite(db, prefs, notifier),
      child: const CepteCuzdanApp(),
    ),
  );
  // Bildirim izni uygulama açıldıktan sonra istenir.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await notifier.requestPermission();
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
    }
  });
}
