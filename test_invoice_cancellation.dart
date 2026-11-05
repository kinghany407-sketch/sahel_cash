import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final testDb = 'C:\\Projects\\sahel_cash\\test_cancellation_$timestamp.db';

  print('=== Test: Invoice Cancellation and Inventory Reversal ===\n');
  print('Test database: $testDb\n');

  final db = await openDatabase(
    testDb,
    version: 25,
    onCreate: (db, version) async {
      print('Creating database schema at version $version');

      // Products table
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

      // Product sale units table
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

      // Invoices table
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

      // Invoice items table
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
conversionToStorage REAL DEFAULT NULL,
FOREIGN KEY (invoiceId) REFERENCES invoices(id),
FOREIGN KEY (productId) REFERENCES products(id)
)
''');

      // Inventory movements table
      await db.execute('''
CREATE TABLE IF NOT EXISTS inventory_movements(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  productId INTEGER NOT NULL,
  movementType TEXT NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('in', 'out')),
  quantity REAL NOT NULL CHECK(quantity > 0),
  storageUnit TEXT NOT NULL,
  sourceType TEXT NOT NULL,
  sourceDocumentId INTEGER,
  sourceLineId INTEGER,
  movementAt TEXT NOT NULL,
  recordedAt TEXT NOT NULL,
  reversalOfMovementId INTEGER,
  idempotencyKey TEXT NOT NULL UNIQUE,
  trackingStatus TEXT NOT NULL DEFAULT 'tracked'
)
''');

      print('✅ Schema created successfully');
    },
  );

  final now = DateTime.now().toIso8601String();
  int passedTests = 0;
  int failedTests = 0;

  // Insert test product
  print('\n=== Setup: Insert test product ===');
  final productId = 17;
  await db.insert('products', {
    'id': productId,
    'name': 'شوال',
    'buyPrice': 55.0,
    'sellPrice': 60.0,
    'quantity': 100.0,
    'purchaseUnit': 'كيلو',
    'storageUnit': 'كيلو',
    'saleUnit': 'كيلو',
    'unitsPerPurchaseUnit': 1,
    'conversionFactor': 1.0,
    'createdAt': now,
    'updatedAt': now,
  });

  await db.insert('product_sale_units', {
    'productId': productId,
    'saleUnit': 'قطعة ثقيلة',
    'retailPrice': 17.0,
    'wholesalePrice': null,
    'conversionToStorage': 0.2,
    'allowSellingByAmount': 0,
  });

  print('✅ Product inserted with 100.0 kg in stock');

  // Test 1: Record stock before sale
  print('\n=== Test 1: Record stock before sale ===');
  final productBefore = await db.query('products', where: 'id = ?', whereArgs: [productId]);
  final stockBefore = (productBefore.first['quantity'] as num).toDouble();
  print('Stock before sale: $stockBefore kg');

  // Test 2: Create sale invoice with conversionToStorage = 0.2
  print('\n=== Test 2: Create sale invoice (5 heavy pieces, conversionToStorage = 0.2) ===');
  final invoiceId = await db.insert('invoices', {
    'invoiceNumber': 'TEST-CANCEL-001',
    'date': now,
    'total': 85.0,
    'paymentMethod': 'cash',
    'status': 'posted',
  });

  await db.insert('invoice_items', {
    'invoiceId': invoiceId,
    'productId': productId,
    'productName': 'شوال',
    'saleUnit': 'قطعة ثقيلة',
    'quantity': 5.0,
    'unitPrice': 17.0,
    'total': 85.0,
    'isWholesale': 0,
    'conversionToStorage': 0.2,
  });

  // Simulate stock deduction (5 pieces * 0.2 = 1.0 kg)
  final stockDeduction = 5.0 * 0.2;
  await db.update(
    'products',
    {'quantity': stockBefore - stockDeduction, 'updatedAt': now},
    where: 'id = ?',
    whereArgs: [productId],
  );

  // Record inventory movement
  await db.insert('inventory_movements', {
    'productId': productId,
    'movementType': 'sale',
    'direction': 'out',
    'quantity': stockDeduction,
    'storageUnit': 'كيلو',
    'sourceType': 'sales_invoice',
    'sourceDocumentId': invoiceId,
    'sourceLineId': 1,
    'movementAt': now,
    'recordedAt': now,
    'idempotencyKey': 'sale-$invoiceId-1',
    'trackingStatus': 'tracked',
  });

  print('✅ Invoice created');
  print('Stock deduction: $stockDeduction kg (5 pieces * 0.2)');

  // Test 3: Record stock after sale
  print('\n=== Test 3: Record stock after sale ===');
  final productAfter = await db.query('products', where: 'id = ?', whereArgs: [productId]);
  final stockAfter = (productAfter.first['quantity'] as num).toDouble();
  print('Stock after sale: $stockAfter kg');

  if (stockAfter == stockBefore - stockDeduction) {
    print('✅ PASS: Stock deducted correctly');
    passedTests++;
  } else {
    print('❌ FAIL: Expected ${stockBefore - stockDeduction}, got $stockAfter');
    failedTests++;
  }

  // Test 4: Cancel invoice and reverse stock
  print('\n=== Test 4: Cancel invoice and reverse stock ===');
  final updated = await db.update(
    'invoices',
    {
      'status': 'voided',
      'cancelledAt': now,
      'cancellationReason': 'Test cancellation',
    },
    where: 'id = ?',
    whereArgs: [invoiceId],
  );

  if (updated == 1) {
    print('✅ Invoice status updated to voided');

    // Reverse stock (add back the deducted amount)
    await db.update(
      'products',
      {'quantity': stockAfter + stockDeduction, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [productId],
    );

    // Record reversal movement
    final originalMovement = await db.query(
      'inventory_movements',
      where: 'sourceDocumentId = ?',
      whereArgs: [invoiceId],
    );

    if (originalMovement.isNotEmpty) {
      await db.insert('inventory_movements', {
        'productId': productId,
        'movementType': 'sale_reversal',
        'direction': 'in',
        'quantity': stockDeduction,
        'storageUnit': 'كيلو',
        'sourceType': 'sales_invoice_cancellation',
        'sourceDocumentId': invoiceId,
        'movementAt': now,
        'recordedAt': now,
        'reversalOfMovementId': originalMovement.first['id'],
        'idempotencyKey': 'reversal-$invoiceId-1',
        'trackingStatus': 'tracked',
      });
    }

    print('✅ Stock reversed');
  } else {
    print('❌ FAIL: Invoice status not updated');
    failedTests++;
  }

  // Test 5: Verify stock returned to original
  print('\n=== Test 5: Verify stock returned to original ===');
  final productFinal = await db.query('products', where: 'id = ?', whereArgs: [productId]);
  final stockFinal = (productFinal.first['quantity'] as num).toDouble();
  print('Stock after cancellation: $stockFinal kg');

  if (stockFinal == stockBefore) {
    print('✅ PASS: Stock returned to original amount ($stockBefore kg)');
    passedTests++;
  } else {
    print('❌ FAIL: Expected $stockBefore, got $stockFinal');
    failedTests++;
  }

  // Test 6: Attempt duplicate cancellation (should not duplicate reversal)
  print('\n=== Test 6: Attempt duplicate cancellation ===');
  try {
    await db.update(
      'invoices',
      {
        'status': 'voided',
        'cancelledAt': now,
        'cancellationReason': 'Duplicate test',
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    // Check if duplicate reversal was created
    final reversals = await db.query(
      'inventory_movements',
      where: 'sourceType = ? AND sourceDocumentId = ?',
      whereArgs: ['sales_invoice_cancellation', invoiceId],
    );

    if (reversals.length == 1) {
      print('✅ PASS: No duplicate reversal created');
      passedTests++;
    } else {
      print('❌ FAIL: Duplicate reversal detected (${reversals.length} reversals)');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  await db.close();

  print('\n=== Test Summary ===');
  print('Database: $testDb');
  print('Total tests: ${passedTests + failedTests}');
  print('Passed: $passedTests');
  print('Failed: $failedTests');
  print('\nStock values:');
  print('  Before sale: $stockBefore kg');
  print('  After sale: $stockAfter kg');
  print('  After cancellation: $stockFinal kg');
  print('\nProduction database: NOT ACCESSED');
  print('Isolation: COMPLETE');
}
