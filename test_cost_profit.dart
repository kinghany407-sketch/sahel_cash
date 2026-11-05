import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final testDb = 'C:\\Projects\\sahel_cash\\test_cost_profit_$timestamp.db';

  print('=== Test: Cost and Profit Calculation ===\n');
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
status TEXT NOT NULL DEFAULT 'posted'
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

      print('✅ Schema created successfully');
    },
  );

  final now = DateTime.now().toIso8601String();
  int passedTests = 0;
  int failedTests = 0;

  // Setup: Insert الشوال product
  print('\n=== Setup: Insert الشوال product ===');
  final productId = 17;
  final buyPrice = 55.0; // 55 جنيه/كيلو

  await db.insert('products', {
    'id': productId,
    'name': 'شوال',
    'buyPrice': buyPrice,
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
    'saleUnit': 'كيلو',
    'retailPrice': 60.0,
    'wholesalePrice': null,
    'conversionToStorage': 1.0,
    'allowSellingByAmount': 1,
  });

  await db.insert('product_sale_units', {
    'productId': productId,
    'saleUnit': 'قطعة ثقيلة',
    'retailPrice': 17.0,
    'wholesalePrice': null,
    'conversionToStorage': 0.2,
    'allowSellingByAmount': 0,
  });

  await db.insert('product_sale_units', {
    'productId': productId,
    'saleUnit': 'قطعة خفيفة',
    'retailPrice': 15.0,
    'wholesalePrice': null,
    'conversionToStorage': 0.1666666667,
    'allowSellingByAmount': 0,
  });

  print('✅ Product inserted');
  print('Buy price: $buyPrice جنيه/كيلو');

  // Test 1: Sale by kilogram
  print('\n=== Test 1: Sale by kilogram (conversionToStorage = 1.0) ===');
  try {
    final invoiceId1 = await db.insert('invoices', {
      'invoiceNumber': 'TEST-KG-001',
      'date': now,
      'total': 60.0,
      'paymentMethod': 'cash',
      'status': 'posted',
    });

    await db.insert('invoice_items', {
      'invoiceId': invoiceId1,
      'productId': productId,
      'productName': 'شوال',
      'saleUnit': 'كيلو',
      'quantity': 1.0,
      'unitPrice': 60.0,
      'total': 60.0,
      'isWholesale': 0,
      'conversionToStorage': 1.0,
    });

    final item1 = await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId1]);
    final conv1 = (item1.first['conversionToStorage'] as num).toDouble();
    final qty1 = (item1.first['quantity'] as num).toDouble();
    final price1 = (item1.first['unitPrice'] as num).toDouble();
    final total1 = (item1.first['total'] as num).toDouble();

    final storageQty1 = qty1 * conv1;
    final cost1 = storageQty1 * buyPrice;
    final profit1 = total1 - cost1;

    print('معامل التحويل المحفوظ: $conv1');
    print('كمية المخزون المقابلة: $storageQty1 كيلو');
    print('تكلفة الوحدة: $cost1 جنيه');
    print('سعر البيع: $total1 جنيه');
    print('الربح: $profit1 جنيه');

    if (conv1 == 1.0 && storageQty1 == 1.0 && cost1 == 55.0 && profit1 == 5.0) {
      print('✅ PASS: Calculations correct');
      passedTests++;
    } else {
      print('❌ FAIL: Calculations incorrect');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  // Test 2: Sale by heavy piece
  print('\n=== Test 2: Sale by heavy piece (conversionToStorage = 0.2) ===');
  try {
    final invoiceId2 = await db.insert('invoices', {
      'invoiceNumber': 'TEST-HEAVY-001',
      'date': now,
      'total': 85.0,
      'paymentMethod': 'cash',
      'status': 'posted',
    });

    await db.insert('invoice_items', {
      'invoiceId': invoiceId2,
      'productId': productId,
      'productName': 'شوال',
      'saleUnit': 'قطعة ثقيلة',
      'quantity': 5.0,
      'unitPrice': 17.0,
      'total': 85.0,
      'isWholesale': 0,
      'conversionToStorage': 0.2,
    });

    final item2 = await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId2]);
    final conv2 = (item2.first['conversionToStorage'] as num).toDouble();
    final qty2 = (item2.first['quantity'] as num).toDouble();
    final price2 = (item2.first['unitPrice'] as num).toDouble();
    final total2 = (item2.first['total'] as num).toDouble();

    final storageQty2 = qty2 * conv2;
    final cost2 = storageQty2 * buyPrice;
    final profit2 = total2 - cost2;

    print('معامل التحويل المحفوظ: $conv2');
    print('كمية المخزون المقابلة: $storageQty2 كيلو');
    print('تكلفة الوحدة: $cost2 جنيه');
    print('سعر البيع: $total2 جنيه');
    print('الربح: $profit2 جنيه');

    if (conv2 == 0.2 && storageQty2 == 1.0 && cost2 == 55.0 && profit2 == 30.0) {
      print('✅ PASS: Calculations correct');
      passedTests++;
    } else {
      print('❌ FAIL: Calculations incorrect');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  // Test 3: Sale by light piece
  print('\n=== Test 3: Sale by light piece (conversionToStorage = 0.1666666667) ===');
  try {
    final invoiceId3 = await db.insert('invoices', {
      'invoiceNumber': 'TEST-LIGHT-001',
      'date': now,
      'total': 90.0,
      'paymentMethod': 'cash',
      'status': 'posted',
    });

    await db.insert('invoice_items', {
      'invoiceId': invoiceId3,
      'productId': productId,
      'productName': 'شوال',
      'saleUnit': 'قطعة خفيفة',
      'quantity': 6.0,
      'unitPrice': 15.0,
      'total': 90.0,
      'isWholesale': 0,
      'conversionToStorage': 0.1666666667,
    });

    final item3 = await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId3]);
    final conv3 = (item3.first['conversionToStorage'] as num).toDouble();
    final qty3 = (item3.first['quantity'] as num).toDouble();
    final price3 = (item3.first['unitPrice'] as num).toDouble();
    final total3 = (item3.first['total'] as num).toDouble();

    final storageQty3 = qty3 * conv3;
    final cost3 = storageQty3 * buyPrice;
    final profit3 = total3 - cost3;

    print('معامل التحويل المحفوظ: $conv3');
    print('كمية المخزون المقابلة: $storageQty3 كيلو');
    print('تكلفة الوحدة: $cost3 جنيه');
    print('سعر البيع: $total3 جنيه');
    print('الربح: $profit3 جنيه');

    // Allow small floating point error margin
    final expectedProfit = 35.0;
    final profitDiff = (profit3 - expectedProfit).abs();
    final storageQtyDiff = (storageQty3 - 1.0).abs();
    final costDiff = (cost3 - 55.0).abs();

    if (conv3 == 0.1666666667 && storageQtyDiff < 0.01 && costDiff < 0.01 && profitDiff < 0.01) {
      print('✅ PASS: Calculations correct (within floating point tolerance)');
      passedTests++;
    } else {
      print('❌ FAIL: Calculations incorrect');
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
  print('\nProduction database: NOT ACCESSED');
  print('Isolation: COMPLETE');
}
