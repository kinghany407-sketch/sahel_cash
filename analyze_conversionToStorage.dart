import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(r'C:\Projects\sahel_cash\sahel_cash.db');

  print('=== CONVERSIONTOSTORAGE ANALYSIS ===\n');

  // Check database version
  final pragmaVersion = await db.rawQuery('PRAGMA user_version');
  print('Database version: ${pragmaVersion.first['user_version']}\n');

  // Get all sale units with their conversionToStorage
  final saleUnits = await db.rawQuery('''
    SELECT psu.id, psu.productId, p.name as productName, p.storageUnit,
           psu.saleUnit, psu.conversionToStorage, psu.retailPrice, psu.wholesalePrice
    FROM product_sale_units psu
    JOIN products p ON psu.productId = p.id
    ORDER BY psu.productId, psu.saleUnit
  ''');

  print('ALL SALE UNITS WITH conversionToStorage:\n');
  for (var su in saleUnits) {
    print('Product: ${su['productName']} (ID: ${su['productId']})');
    print('  Storage Unit: ${su['storageUnit']}');
    print('  Sale Unit: ${su['saleUnit']}');
    print('  conversionToStorage: ${su['conversionToStorage']}');
    print('  retailPrice: ${su['retailPrice']}, wholesalePrice: ${su['wholesalePrice']}');
    print('');
  }

  // Check how sale units are used in invoice_items
  print('=== INVOICE ITEMS USAGE ===\n');
  final invoiceItems = await db.rawQuery('''
    SELECT ii.productId, p.name as productName, ii.saleUnit, ii.quantity, ii.unitPrice, ii.total,
           COUNT(*) as count
    FROM invoice_items ii
    JOIN products p ON ii.productId = p.id
    WHERE p.name LIKE '%كيس%' OR p.name LIKE '%bag%'
       OR p.name LIKE '%شنط%' OR p.name LIKE '%شوال%'
       OR p.name LIKE '%شفاف%'
    GROUP BY ii.productId, ii.saleUnit
    ORDER BY ii.productId, ii.saleUnit
  ''');

  for (var item in invoiceItems) {
    print('Product: ${item['productName']} (ID: ${item['productId']})');
    print('  Sale Unit used in invoices: ${item['saleUnit']}');
    print('  Number of invoice items: ${item['count']}');
    print('');
  }

  // Specifically check Shوال (ID 17)
  print('=== SHوال (ID 17) SPECIFIC CHECK ===\n');
  final shawal = await db.rawQuery('''
    SELECT id, name, purchasePrice, salePrice, storageUnit, purchaseUnit, saleUnit,
           conversionFactor, unitsPerPurchaseUnit, quantity
    FROM products
    WHERE id = 17
  ''');

  if (shawal.isNotEmpty) {
    final p = shawal.first;
    print('Current Shوال configuration:');
    print('  Purchase Unit: ${p['purchaseUnit']}');
    print('  Storage Unit: ${p['storageUnit']}');
    print('  Sale Unit: ${p['saleUnit']}');
    print('  Purchase Price: ${p['purchasePrice']}');
    print('  Sale Price: ${p['salePrice']}');
    print('  unitsPerPurchaseUnit: ${p['unitsPerPurchaseUnit']}');
    print('  conversionFactor: ${p['conversionFactor']}');
    print('');

    final shawalSaleUnits = await db.rawQuery('''
      SELECT saleUnit, retailPrice, wholesalePrice, conversionToStorage
      FROM product_sale_units
      WHERE productId = 17
    ''');

    print('Shوال sale units in DB (${shawalSaleUnits.length}):');
    for (var su in shawalSaleUnits) {
      print('  - ${su['saleUnit']}: retail=${su['retailPrice']}, wholesale=${su['wholesalePrice']}, conversionToStorage=${su['conversionToStorage']}');
    }
    print('');

    final shawalInvoices = await db.rawQuery('''
      SELECT ii.saleUnit, ii.quantity, ii.unitPrice, ii.total, i.invoiceNumber, i.date
      FROM invoice_items ii
      JOIN invoices i ON ii.invoiceId = i.id
      WHERE ii.productId = 17
      ORDER BY i.date DESC
    ''');

    print('Shوال invoice items (${shawalInvoices.length}):');
    for (var inv in shawalInvoices) {
      print('  Invoice #${inv['invoiceNumber']} (${inv['date']}): saleUnit=${inv['saleUnit']}, qty=${inv['quantity']}, price=${inv['unitPrice']}, total=${inv['total']}');
    }
  }

  await db.close();
}
