import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  // Copy production DB to test location
  final sourceDb = r'C:\Users\IP\Documents\sahel_cash.db';
  final testDb = r'C:\Projects\sahel_cash\test_temp.db';
  
  File(sourceDb).copy(testDb);
  
  print('Created temporary test database at: $testDb');
  
  // Verify the copy
  final db = await openDatabase(testDb);
  final version = await db.rawQuery('PRAGMA user_version');
  print('Test database version: ${version.first['user_version']}');
  
  await db.close();
}
