import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(r'C:\Projects\sahel_cash\sahel_cash.db');

  print('=== COMPREHENSIVE BAGS & BAGS DIAGNOSTIC ===\n');

  // Check database version
  final pragmaVersion = await db.rawQuery('PRAGMA user_version');
  print('Database version: ${pragmaVersion.first['user_version']}\n');

  // Get all products with bags-related names
  final products = await db.rawQuery('''
    SELECT id, name, purchasePrice, salePrice, storageUnit, purchaseUnit, saleUnit,
           conversionFactor, unitsPerPurchaseUnit, quantity
    FROM products
    WHERE name LIKE '%كيس%' OR name LIKE '%bag%'
       OR name LIKE '%شنط%' OR name LIKE '%شوال%'
       OR name LIKE '%شفاف%'
    ORDER BY id
  ''');

  print('Found ${products.length} bags/bags-related products\n');

  for (var product in products) {
    print('--- Product ID: ${product['id']} ---');
    print('Name: ${product['name']}');
    print('Purchase Price: ${product['purchasePrice']}');
    print('Sale Price: ${product['salePrice']}');
    print('Purchase Unit: ${product['purchaseUnit']}');
    print('Storage Unit: ${product['storageUnit']}');
    print('Sale Unit: ${product['saleUnit']}');
    print('Conversion Factor: ${product['conversionFactor']}');
    print('Units Per Purchase Unit: ${product['unitsPerPurchaseUnit']}');
    print('Quantity: ${product['quantity']}');

    // Get sale units for this product
    final saleUnits = await db.rawQuery('''
      SELECT saleUnit, retailPrice, wholesalePrice, conversionToStorage
      FROM product_sale_units
      WHERE productId = ?
    ''', [product['id']]);

    print('Sale Units (${saleUnits.length}):');
    for (var su in saleUnits) {
      print('  - ${su['saleUnit']}: retail=${su['retailPrice']}, wholesale=${su['wholesalePrice']}, conversionToStorage=${su['conversionToStorage']}');
    }

    // Special check for Shوال (ID 17)
    if (product['id'] == 17) {
      print('SPECIAL CHECK FOR SHوال (ID 17):');
      print('  Current configuration:');
      print('    Purchase Unit: ${product['purchaseUnit']}');
      print('    Storage Unit: ${product['storageUnit']}');
      print('    Sale Unit: ${product['saleUnit']}');
      print('  Required configuration:');
      print('    Purchase Unit: كيلو');
      print('    Storage Unit: كيلو');
      print('    Sale Units: كيلو + قطعة (heavy: 5 pcs/kg, light: 6 pcs/kg)');
      print('  Current sale units from DB:');
      for (var su in saleUnits) {
        print('    - ${su['saleUnit']}: retail=${su['retailPrice']}, wholesale=${su['wholesalePrice']}, conversionToStorage=${su['conversionToStorage']}');
      }
    }

    print('');
  }

  // Check all sale units with conversionToStorage = 1000
  print('=== ALL SALE UNITS WITH conversionToStorage = 1000 ===');
  final badSaleUnits = await db.rawQuery('''
    SELECT psu.id, psu.productId, p.name as productName, psu.saleUnit, psu.conversionToStorage
    FROM product_sale_units psu
    JOIN products p ON psu.productId = p.id
    WHERE psu.conversionToStorage = 1000.0
  ''');

  for (var su in badSaleUnits) {
    print('Product: ${su['productName']} (ID: ${su['productId']})');
    print('  Sale Unit: ${su['saleUnit']}, conversionToStorage: ${su['conversionToStorage']}');
    print('  Current saleUnit: ${su['saleUnit']}');
    print('  Action Required: If saleUnit is كيلو, change conversionToStorage to 1.0');
    print('');
  }

  // Check if any invoice uses these products
  print('=== INVOICE ITEMS WITH THESE PRODUCTS ===');
  for (var product in products) {
    final invoiceItems = await db.rawQuery('''
      SELECT ii.id, ii.invoiceId, ii.saleUnit, ii.quantity, ii.unitPrice, ii.total,
             i.invoiceNumber, i.date
      FROM invoice_items ii
      JOIN invoices i ON ii.invoiceId = i.id
      WHERE ii.productId = ?
      LIMIT 5
    ''', [product['id']]);

    if (invoiceItems.isNotEmpty) {
      print('Product: ${product['name']} (ID: ${product['id']}) - ${invoiceItems.length} invoice items');
      for (var item in invoiceItems) {
        print('  Invoice #${item['invoiceNumber']} (${item['date']}): saleUnit=${item['saleUnit']}, qty=${item['quantity']}, total=${item['total']}');
      }
    }
  }

  await db.close();
}
