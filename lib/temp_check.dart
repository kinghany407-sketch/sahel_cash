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
    "SELECT id, name, imagePath FROM products WHERE name LIKE '%أكياس شفاف%' OR name LIKE '%شنط أسود%'"
  );

  for (var row in specificProducts) {
    print('ID: ${row['id']}');
    print('Name: ${row['name']}');
    final path = row['imagePath'] as String?;
    print('ImagePath: "$path"');
    print('Length: ${path?.length ?? 0}');
    print('Has leading/trailing spaces: ${path != path?.trim()}');
    print('Is "null" string: ${path == "null"}');
    print('Is NULL: ${row['imagePath'] == null}');
    print('Is empty: ${path?.isEmpty ?? true}');
    
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      final exists = await file.exists();
      print('File exists: $exists');
    } else {
      print('File exists: false (path is null or empty)');
    }
    print('---');
  }

  await db.close();
}
