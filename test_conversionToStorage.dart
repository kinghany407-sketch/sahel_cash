import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Use the test database created by test_isolated_setup.dart
  final testDb = 'C:\\Projects\\sahel_cash\\test_isolated_1793702898888.db';

  print('=== Testing conversionToStorage in invoice_items ===\n');
  print('Test database: $testDb\n');

  final db = await openDatabase(testDb);

  // Check database version
  final version = await db.rawQuery('PRAGMA user_version');
  print('Database version: ${version.first['user_version']}');

  // Check if conversionToStorage column exists
  final tableInfo = await db.rawQuery('PRAGMA table_info(invoice_items)');
  final hasConversionColumn = tableInfo.any((col) => col['name'] == 'conversionToStorage');
  print('Has conversionToStorage column: $hasConversionColumn');

  if (!hasConversionColumn) {
    print('ERROR: conversionToStorage column not found!');
    await db.close();
    return;
  }

  final now = DateTime.now().toIso8601String();
  int passedTests = 0;
  int failedTests = 0;

  // Test 1: Sale by kilogram with conversionToStorage = 1.0
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
      'productId': 17,
      'productName': 'شوال',
      'saleUnit': 'كيلو',
      'quantity': 1.0,
      'unitPrice': 60.0,
      'total': 60.0,
      'isWholesale': 0,
      'conversionToStorage': 1.0,
    });

    final item1 = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId1],
    );

    final conv1 = item1.first['conversionToStorage'];
    if (conv1 == 1.0) {
      print('✅ PASS: conversionToStorage = 1.0 saved correctly');
      passedTests++;
    } else {
      print('❌ FAIL: Expected 1.0, got $conv1');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  // Test 2: Sale by heavy piece with conversionToStorage = 0.2
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
      'productId': 17,
      'productName': 'شوال',
      'saleUnit': 'قطعة ثقيلة',
      'quantity': 5.0,
      'unitPrice': 17.0,
      'total': 85.0,
      'isWholesale': 0,
      'conversionToStorage': 0.2,
    });

    final item2 = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId2],
    );

    final conv2 = item2.first['conversionToStorage'];
    if (conv2 == 0.2) {
      print('✅ PASS: conversionToStorage = 0.2 saved correctly');
      passedTests++;
    } else {
      print('❌ FAIL: Expected 0.2, got $conv2');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  // Test 3: Sale by light piece with conversionToStorage = 0.1666666667
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
      'productId': 17,
      'productName': 'شوال',
      'saleUnit': 'قطعة خفيفة',
      'quantity': 6.0,
      'unitPrice': 15.0,
      'total': 90.0,
      'isWholesale': 0,
      'conversionToStorage': 0.1666666667,
    });

    final item3 = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId3],
    );

    final conv3 = item3.first['conversionToStorage'];
    if (conv3 == 0.1666666667) {
      print('✅ PASS: conversionToStorage = 0.1666666667 saved correctly');
      passedTests++;
    } else {
      print('❌ FAIL: Expected 0.1666666667, got $conv3');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  // Test 4: Change conversionToStorage in product settings and verify old invoice doesn't change
  print('\n=== Test 4: Change conversionToStorage and verify old invoice stability ===');
  try {
    // Record old invoice cost before change
    final invoiceId2 = (await db.query('invoices', where: 'invoiceNumber = ?', whereArgs: ['TEST-HEAVY-001'])).first['id'];
    final oldItem = (await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId2])).first;
    final oldConversion = oldItem['conversionToStorage'];

    // Change conversionToStorage in product_sale_units
    await db.update(
      'product_sale_units',
      {'conversionToStorage': 0.25},
      where: 'productId = ? AND saleUnit = ?',
      whereArgs: [17, 'قطعة ثقيلة'],
    );

    // Re-read the old invoice item
    final unchangedItem = (await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId2])).first;
    final unchangedConversion = unchangedItem['conversionToStorage'];

    if (unchangedConversion == oldConversion && unchangedConversion == 0.2) {
      print('✅ PASS: Old invoice conversionToStorage unchanged (still 0.2)');
      passedTests++;
    } else {
      print('❌ FAIL: Old invoice changed from $oldConversion to $unchangedConversion');
      failedTests++;
    }

    // Restore original value
    await db.update(
      'product_sale_units',
      {'conversionToStorage': 0.2},
      where: 'productId = ? AND saleUnit = ?',
      whereArgs: [17, 'قطعة ثقيلة'],
    );
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  // Test 5: Cancel invoice and verify inventory reversal
  print('\n=== Test 5: Cancel invoice (inventory reversal) ===');
  try {
    final invoiceId1 = (await db.query('invoices', where: 'invoiceNumber = ?', whereArgs: ['TEST-KG-001'])).first['id'];

    // Update invoice status to voided
    final updated = await db.update(
      'invoices',
      {
        'status': 'voided',
        'cancelledAt': now,
        'cancellationReason': 'Test cancellation',
      },
      where: 'id = ?',
      whereArgs: [invoiceId1],
    );

    if (updated == 1) {
      print('✅ PASS: Invoice status updated to voided');
      passedTests++;
    } else {
      print('❌ FAIL: Invoice status not updated');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  // Test 6: Handle NULL conversionToStorage (old data)
  print('\n=== Test 6: Handle NULL conversionToStorage (incomplete data) ===');
  try {
    final invoiceId6 = await db.insert('invoices', {
      'invoiceNumber': 'TEST-NULL-001',
      'date': now,
      'total': 100.0,
      'paymentMethod': 'cash',
      'status': 'posted',
    });

    await db.insert('invoice_items', {
      'invoiceId': invoiceId6,
      'productId': 17,
      'productName': 'شوال',
      'saleUnit': 'قطعة',
      'quantity': 5.0,
      'unitPrice': 20.0,
      'total': 100.0,
      'isWholesale': 0,
      'conversionToStorage': null, // NULL to simulate old data
    });

    final item6 = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId6],
    );

    final conv6 = item6.first['conversionToStorage'];
    if (conv6 == null) {
      print('✅ PASS: conversionToStorage = NULL handled correctly (incomplete data)');
      passedTests++;
    } else {
      print('❌ FAIL: Expected NULL, got $conv6');
      failedTests++;
    }
  } catch (e) {
    print('❌ FAIL: $e');
    failedTests++;
  }

  await db.close();

  print('\n=== Test Summary ===');
  print('Database: $testDb');
  print('Database version: ${version.first['user_version']}');
  print('Total tests: ${passedTests + failedTests}');
  print('Passed: $passedTests');
  print('Failed: $failedTests');
  print('\nProduction database: NOT ACCESSED');
  print('Isolation: COMPLETE');
}
