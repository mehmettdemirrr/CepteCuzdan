import 'package:cepte_cuzdan/core/db/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Testler için bellek içi, her çağrıda yeni ve boş bir veritabanı.
Future<Database> openTestDb() {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    singleInstance: false,
  );
}
