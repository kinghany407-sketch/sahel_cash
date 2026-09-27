import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = r'C:\Users\hany\OneDrive\Documenti\sahel_cash.db';
  final db = await openDatabase(dbPath);

  // Check specific products
  print('=== Check Specific Products ===\n');

  final specificProducts = await db.rawQuery(
    "SELECT id, name, sku, barcode, imagePath FROM products WHERE name LIKE '%أكياس شفاف%' OR name LIKE '%شنط أسود%'"
  );

  for (var row in specificProducts) {
    print('ID: ${row['id']}');
    print('Name: ${row['name']}');
    print('SKU: ${row['sku']}');
    print('Barcode: ${row['barcode']}');
    print('ImagePath: ${row['imagePath']}');
    
    final path = row['imagePath'] as String?;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      final exists = await file.exists();
      print('File exists: $exists');
    } else {
      print('File exists: false (path is null or empty)');
    }
    print('---');
  }

  // Check if these products would be returned by getProductsWithImages
  print('\n=== getProductsWithImages Query ===\n');
  final imageProducts = await db.rawQuery(
    "SELECT id, name, imagePath FROM products WHERE imagePath IS NOT NULL AND imagePath != '' ORDER BY id DESC LIMIT 20"
  );

  print('Products that match the query:');
  for (var row in imageProducts) {
    print('ID: ${row['id']}, Name: ${row['name']}, Path: ${row['imagePath']}');
  }

  print('\nTotal matching products: ${imageProducts.length}');

  await db.close();
}
