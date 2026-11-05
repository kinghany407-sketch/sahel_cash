import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/models/product_sale_unit_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('sale units support retail-only and wholesale-only prices', () {
    final cup = ProductSaleUnit(
      productId: 1,
      saleUnit: 'كوب',
      retailPrice: 3,
      conversionToStorage: 1,
    );
    final column = ProductSaleUnit(
      productId: 1,
      saleUnit: 'عامود',
      retailPrice: null,
      wholesalePrice: 85,
      conversionToStorage: 50,
    );

    expect(cup.toMap()['retailPrice'], 3);
    expect(cup.toMap()['wholesalePrice'], isNull);
    expect(column.toMap()['retailPrice'], isNull);
    expect(column.toMap()['wholesalePrice'], 85);
    expect(ProductSaleUnit.fromMap(column.toMap()).retailPrice, isNull);
  });

  test(
    'migration preserves sale units and allows a missing retail price',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute('PRAGMA foreign_keys = ON');
      await db.execute('''
CREATE TABLE products(
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL
)
''');
      await db.execute('''
CREATE TABLE product_sale_units(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  productId INTEGER NOT NULL,
  saleUnit TEXT NOT NULL,
  retailPrice REAL NOT NULL,
  wholesalePrice REAL,
  conversionToStorage REAL NOT NULL,
  allowSellingByAmount INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE(productId, saleUnit)
)
''');
      await db.insert('products', {'id': 1, 'name': 'كوب شفاف بغطاء'});
      await db.insert('product_sale_units', {
        'id': 4,
        'productId': 1,
        'saleUnit': 'كوب',
        'retailPrice': 3,
        'conversionToStorage': 1,
      });
      await db.insert('product_sale_units', {
        'id': 12,
        'productId': 1,
        'saleUnit': 'عامود',
        'retailPrice': 4,
        'wholesalePrice': 85,
        'conversionToStorage': 50,
      });
      await db.delete('product_sale_units', where: 'id = ?', whereArgs: [12]);

      await DatabaseHelper.migrateSaleUnitRetailPrice(db);

      final columns = await db.rawQuery(
        'PRAGMA table_info(product_sale_units)',
      );
      final retailPriceColumn = columns.singleWhere(
        (column) => column['name'] == 'retailPrice',
      );
      expect(retailPriceColumn['notnull'], 0);

      final preserved = await db.query('product_sale_units');
      expect(preserved, hasLength(1));
      expect(preserved.single['id'], 4);
      expect(preserved.single['saleUnit'], 'كوب');
      expect(preserved.single['retailPrice'], 3);
      expect(preserved.single['conversionToStorage'], 1);

      final newId = await db.insert('product_sale_units', {
        'productId': 1,
        'saleUnit': 'عامود',
        'retailPrice': null,
        'wholesalePrice': 85,
        'conversionToStorage': 50,
      });
      expect(newId, 13);

      final migratedUnit = await db.query(
        'product_sale_units',
        where: 'id = ?',
        whereArgs: [newId],
      );
      expect(migratedUnit.single['retailPrice'], isNull);
      expect(migratedUnit.single['wholesalePrice'], 85);
      expect(migratedUnit.single['conversionToStorage'], 50);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
