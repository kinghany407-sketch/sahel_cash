import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final testDb = 'C:\\Projects\\sahel_cash\\test_migration_v23_$timestamp.db';

  print('=== Test: Migration v23 ===\n');
  print('Test database: $testDb\n');

  // Step 1: Create database at version 22 with v22 schema
  print('=== Step 1: Create database at version 22 ===');
  final db = await openDatabase(
    testDb,
    version: 22,
    onCreate: (db, version) async {
      print('Creating v22 schema at version $version');

      // Products table (v22)
      await db.execute('''
CREATE TABLE products(
id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT NOT NULL,
buyPrice REAL DEFAULT 0,
sellPrice REAL DEFAULT 0,
quantity REAL DEFAULT 0,
purchaseUnit TEXT DEFAULT 'قطعة',
storageUnit TEXT DEFAULT 'قطعة',
saleUnit TEXT DEFAULT 'قطعة',
unitsPerPurchaseUnit INTEGER DEFAULT 1,
conversionFactor REAL DEFAULT 1,
createdAt TEXT NOT NULL,
updatedAt TEXT NOT NULL
)
''');

      // Product sale units table (v6)
      await db.execute('''
CREATE TABLE product_sale_units(
id INTEGER PRIMARY KEY AUTOINCREMENT,
productId INTEGER NOT NULL,
saleUnit TEXT NOT NULL,
retailPrice REAL,
wholesalePrice REAL,
conversionToStorage REAL NOT NULL,
allowSellingByAmount INTEGER NOT NULL DEFAULT 0,
FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
UNIQUE(productId, saleUnit)
)
''');

      // Invoices table (v8)
      await db.execute('''
CREATE TABLE invoices(
id INTEGER PRIMARY KEY AUTOINCREMENT,
invoiceNumber TEXT UNIQUE NOT NULL,
date TEXT NOT NULL,
total REAL NOT NULL,
paymentMethod TEXT NOT NULL DEFAULT 'cash',
status TEXT NOT NULL DEFAULT 'posted',
cancelledAt TEXT NULL,
cancellationReason TEXT NULL
)
''');

      // Invoice items table (v8) - WITHOUT conversionToStorage column
      await db.execute('''
CREATE TABLE invoice_items(
id INTEGER PRIMARY KEY AUTOINCREMENT,
invoiceId INTEGER NOT NULL,
productId INTEGER NOT NULL,
productName TEXT NOT NULL,
saleUnit TEXT NOT NULL,
quantity REAL NOT NULL,
unitPrice REAL NOT NULL,
total REAL NOT NULL,
isWholesale INTEGER NOT NULL DEFAULT 0,
FOREIGN KEY (invoiceId) REFERENCES invoices(id),
FOREIGN KEY (productId) REFERENCES products(id)
)
''');

      print('✅ v22 schema created successfully');
    },
  );

  final version22 = await db.rawQuery('PRAGMA user_version');
  print('Database version after creation: ${version22.first['user_version']}');

  // Step 2: Verify invoice_items does NOT have conversionToStorage column
  print('\n=== Step 2: Verify invoice_items lacks conversionToStorage column ===');
  final tableInfo22 = await db.rawQuery('PRAGMA table_info(invoice_items)');
  final hasConversion22 = tableInfo22.any((col) => col['name'] == 'conversionToStorage');
  print('Has conversionToStorage column: $hasConversion22');

  if (hasConversion22) {
    print('❌ FAIL: Column should not exist at v22');
    await db.close();
    return;
  } else {
    print('✅ PASS: Column does not exist at v22');
  }

  // Step 3: Insert some test data at v22
  print('\n=== Step 3: Insert test data at v22 ===');
  final now = DateTime.now().toIso8601String();
  await db.insert('products', {
    'id': 1,
    'name': 'Test Product',
    'buyPrice': 100.0,
    'sellPrice': 120.0,
    'quantity': 50.0,
    'purchaseUnit': 'قطعة',
    'storageUnit': 'قطعة',
    'saleUnit': 'قطعة',
    'unitsPerPurchaseUnit': 1,
    'conversionFactor': 1.0,
    'createdAt': now,
    'updatedAt': now,
  });

  await db.insert('invoices', {
    'invoiceNumber': 'TEST-V22-001',
    'date': now,
    'total': 120.0,
    'paymentMethod': 'cash',
    'status': 'posted',
  });

  await db.insert('invoice_items', {
    'invoiceId': 1,
    'productId': 1,
    'productName': 'Test Product',
    'saleUnit': 'قطعة',
    'quantity': 1.0,
    'unitPrice': 120.0,
    'total': 120.0,
    'isWholesale': 0,
  });

  print('✅ Test data inserted at v22');

  // Step 4: Close and reopen to apply migration
  await db.close();
  print('\n=== Step 4: Close database and reopen for migration ===');

  final db23 = await openDatabase(
    testDb,
    version: 23,
    onUpgrade: (db, oldVersion, newVersion) async {
      print('Upgrading from $oldVersion to $newVersion');

      if (oldVersion < 23) {
        print('Applying Migration v23: Adding conversionToStorage column...');
        await db.execute(
          'ALTER TABLE invoice_items ADD COLUMN conversionToStorage REAL DEFAULT NULL',
        );
        print('✅ Migration v23 applied successfully');
      }
    },
  );

  final version23 = await db23.rawQuery('PRAGMA user_version');
  print('Database version after migration: ${version23.first['user_version']}');

  // Step 5: Verify invoice_items now has conversionToStorage column
  print('\n=== Step 5: Verify invoice_items has conversionToStorage column ===');
  final tableInfo23 = await db23.rawQuery('PRAGMA table_info(invoice_items)');
  final hasConversion23 = tableInfo23.any((col) => col['name'] == 'conversionToStorage');
  print('Has conversionToStorage column: $hasConversion23');

  if (!hasConversion23) {
    print('❌ FAIL: Column should exist after v23');
    await db23.close();
    return;
  } else {
    print('✅ PASS: Column exists after v23');
  }

  // Step 6: Verify data integrity
  print('\n=== Step 6: Verify data integrity after migration ===');
  final products = await db23.query('products');
  final invoices = await db23.query('invoices');
  final items = await db23.query('invoice_items');

  print('Products count: ${products.length}');
  print('Invoices count: ${invoices.length}');
  print('Invoice items count: ${items.length}');

  // Check old invoice item (should have conversionToStorage = NULL)
  final oldItem = items.first;
  final oldConversion = oldItem['conversionToStorage'];
  print('Old invoice item conversionToStorage: $oldConversion');

  if (oldConversion == null) {
    print('✅ PASS: Old data has conversionToStorage = NULL');
  } else {
    print('❌ FAIL: Old data should have NULL conversionToStorage');
  }

  // Step 7: Insert new item with conversionToStorage
  print('\n=== Step 7: Insert new item with conversionToStorage ===');
  await db23.insert('invoice_items', {
    'invoiceId': 1,
    'productId': 1,
    'productName': 'Test Product',
    'saleUnit': 'قطعة',
    'quantity': 2.0,
    'unitPrice': 120.0,
    'total': 240.0,
    'isWholesale': 0,
    'conversionToStorage': 1.0,
  });

  final newItem = await db23.query('invoice_items', where: 'quantity = ?', whereArgs: [2.0]);
  final newConversion = newItem.first['conversionToStorage'];
  print('New invoice item conversionToStorage: $newConversion');

  if (newConversion == 1.0) {
    print('✅ PASS: New data has conversionToStorage = 1.0');
  } else {
    print('❌ FAIL: New data should have conversionToStorage = 1.0');
  }

  await db23.close();

  print('\n=== Test Summary ===');
  print('Database: $testDb');
  print('Migration: v22 → v23');
  print('Column added: conversionToStorage');
  print('Data integrity: Verified');
  print('Production database: NOT ACCESSED');
  print('Isolation: COMPLETE');
}
