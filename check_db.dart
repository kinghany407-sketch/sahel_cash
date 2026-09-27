import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = r'C:\Users\hany\OneDrive\Documenti\sahel_cash.db';
  final db = await openDatabase(dbPath);

  // Total products
  final totalProducts = await db.rawQuery('SELECT COUNT(*) as count FROM products');
  print('Total products: ${totalProducts.first['count']}');

  // Products with imagePath
  final withImage = await db.rawQuery(
    "SELECT COUNT(*) as count FROM products WHERE imagePath IS NOT NULL AND imagePath != ''"
  );
  print('Products with imagePath: ${withImage.first['count']}');

  // Products without imagePath
  final withoutImage = await db.rawQuery(
    "SELECT COUNT(*) as count FROM products WHERE imagePath IS NULL OR imagePath = ''"
  );
  print('Products without imagePath: ${withoutImage.first['count']}');

  // First 10 imagePath values
  final imagePaths = await db.rawQuery(
    "SELECT imagePath FROM products WHERE imagePath IS NOT NULL AND imagePath != '' LIMIT 10"
  );
  print('\nFirst 10 image paths:');
  for (var row in imagePaths) {
    print('  ${row['imagePath']}');
  }

  // Check if files exist
  print('\nChecking file existence:');
  int existingCount = 0;
  int missingCount = 0;
  for (var row in imagePaths) {
    final path = row['imagePath'] as String;
    final file = File(path);
    if (await file.exists()) {
      existingCount++;
      print('  EXISTS: $path');
    } else {
      missingCount++;
      print('  MISSING: $path');
    }
  }
  print('\nExisting files: $existingCount');
  print('Missing files: $missingCount');

  await db.close();
}
