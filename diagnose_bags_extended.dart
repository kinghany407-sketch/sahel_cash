import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(r'C:\Projects\sahel_cash\sahel_cash.db');

  print('=== BAGS & BAGS PRODUCTS DIAGNOSTIC ===\n');

  // Get all products with bags-related names
  final products = await db.rawQuery('''
    SELECT id, name, purchasePrice, storageUnit, purchaseUnit, saleUnit,
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

    // Check compliance with rules
    print('Compliance Check:');
    final purchaseUnit = (product['purchaseUnit'] as String?)?.trim().toLowerCase() ?? '';
    final storageUnit = (product['storageUnit'] as String?)?.trim().toLowerCase() ?? '';
    final unitsPerPurchaseUnit = (product['unitsPerPurchaseUnit'] as num?)?.toInt() ?? 1;

    // Rule 1: unitsPerPurchaseUnit should be 1
    if (unitsPerPurchaseUnit == 1) {
      print('  ✅ unitsPerPurchaseUnit = 1 (CORRECT)');
    } else {
      print('  ❌ unitsPerPurchaseUnit = $unitsPerPurchaseUnit (SHOULD BE 1)');
    }

    // Rule 2: purchaseUnit should be كيلو or kg
    if (purchaseUnit.contains('كيلو') || purchaseUnit.contains('kg')) {
      print('  ✅ purchaseUnit = ${product['purchaseUnit']} (CORRECT)');
    } else {
      print('  ❌ purchaseUnit = ${product['purchaseUnit']} (SHOULD BE كيلو)');
    }

    // Rule 3: storageUnit should be كيلو or kg
    if (storageUnit.contains('كيلو') || storageUnit.contains('kg')) {
      print('  ✅ storageUnit = ${product['storageUnit']} (CORRECT)');
    } else {
      print('  ❌ storageUnit = ${product['storageUnit']} (SHOULD BE كيلو)');
    }

    // Rule 4: conversionToStorage for كيلو should be 1
    bool hasKiloSaleUnit = false;
    for (var su in saleUnits) {
      final saleUnit = (su['saleUnit'] as String?)?.trim().toLowerCase() ?? '';
      if (saleUnit.contains('كيلو') || saleUnit.contains('kg')) {
        hasKiloSaleUnit = true;
        final conversionToStorage = (su['conversionToStorage'] as num?)?.toDouble() ?? 0.0;
        if (conversionToStorage == 1.0) {
          print('  ✅ conversionToStorage for كيلو = 1.0 (CORRECT)');
        } else {
          print('  ❌ conversionToStorage for كيلو = $conversionToStorage (SHOULD BE 1.0)');
        }
      }
    }

    if (!hasKiloSaleUnit) {
      print('  ⚠️  No كيلو sale unit found (SHOULD HAVE كيلو sale unit)');
    }

    print('');
  }

  await db.close();
}
