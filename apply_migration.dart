import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final testDb = r'C:\Projects\sahel_cash\test_temp.db';

  print('=== Applying Migration v23 to test database ===\n');

  final db = await openDatabase(
    testDb,
    version: 23,
    onUpgrade: (db, oldVersion, newVersion) async {
      print('Upgrading from $oldVersion to $newVersion');

      if (oldVersion < 23) {
        print('Adding conversionToStorage column to invoice_items...');
        await db.execute(
          'ALTER TABLE invoice_items ADD COLUMN conversionToStorage REAL DEFAULT NULL',
        );
        print('✅ Column added successfully');
      }
    },
  );

  final version = await db.rawQuery('PRAGMA user_version');
  print('\nDatabase version after migration: ${version.first['user_version']}');

  // Verify column exists
  final tableInfo = await db.rawQuery('PRAGMA table_info(invoice_items)');
  final hasConversionColumn = tableInfo.any((col) => col['name'] == 'conversionToStorage');
  print('Has conversionToStorage column: $hasConversionColumn');

  await db.close();

  print('\nMigration v23 applied successfully to: $testDb');
}
