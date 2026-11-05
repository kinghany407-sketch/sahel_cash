import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = r'C:\Projects\sahel_cash\sahel_cash.db';
  final db = await openDatabase(dbPath);

  print('=== DATABASE DIAGNOSTIC REPORT ===\n');

  // Check database version
  final pragmaVersion = await db.rawQuery('PRAGMA user_version');
  print('Database version: ${pragmaVersion.first['user_version']}\n');

  // Get products with names containing cups, foam, bags (Arabic and English)
  final products = await db.rawQuery('''
    SELECT id, name, purchasePrice, storageUnit, purchaseUnit, saleUnit,
           conversionFactor, unitsPerPurchaseUnit, quantity
    FROM products
    WHERE name LIKE '%كوب%' OR name LIKE '%cup%'
       OR name LIKE '%فوم%' OR name LIKE '%foam%'
       OR name LIKE '%كيس%' OR name LIKE '%bag%'
       OR name LIKE '%طبق%' OR name LIKE '%plate%'
    ORDER BY id
  ''');

  print('=== PRODUCTS ===');
  print('Found ${products.length} products matching cups/foam/bags/plates\n');

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
    print('');
  }

  // Get recent invoices with negative profit
  print('=== RECENT INVOICES ===');
  final invoices = await db.rawQuery('''
    SELECT id, invoiceNumber, date, total
    FROM invoices
    ORDER BY id DESC
    LIMIT 20
  ''');

  print('Last 20 invoices:\n');

  for (var invoice in invoices) {
    final invoiceId = invoice['id'];
    final invoiceItems = await db.rawQuery('''
      SELECT ii.productId, ii.productName, ii.saleUnit, ii.quantity,
             ii.unitPrice, ii.total as itemTotal,
             p.purchasePrice, p.storageUnit, p.purchaseUnit,
             p.conversionFactor, p.unitsPerPurchaseUnit,
             psu.conversionToStorage
      FROM invoice_items ii
      LEFT JOIN products p ON ii.productId = p.id
      LEFT JOIN product_sale_units psu ON ii.productId = psu.productId
        AND LOWER(TRIM(ii.saleUnit)) = LOWER(TRIM(psu.saleUnit))
      WHERE ii.invoiceId = ?
    ''', [invoiceId]);

    if (invoiceItems.isEmpty) {
      continue;
    }

    print('--- Invoice #${invoice['invoiceNumber']} (ID: ${invoice['id']}) ---');
    print('Date: ${invoice['date']}');
    print('Total: ${invoice['total']}');
    print('Items:');

    double invoiceRevenue = (invoice['total'] as num).toDouble();
    double invoiceCost = 0.0;

    for (var item in invoiceItems) {
      final buyPrice = (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;
      final unitsPerPurchaseUnit = (item['unitsPerPurchaseUnit'] as num?)?.toInt() ?? 1;
      final conversionFactor = (item['conversionFactor'] as num?)?.toDouble() ?? 1.0;
      final conversionToStorage = (item['conversionToStorage'] as num?)?.toDouble() ?? 1.0;
      final quantity = (item['quantity'] as num).toDouble();
      final itemTotal = (item['itemTotal'] as num).toDouble();

      // Calculate cost using current logic
      double factor = unitsPerPurchaseUnit > 1
          ? unitsPerPurchaseUnit.toDouble()
          : (conversionFactor > 1.0 ? conversionFactor : 1.0);

      double costPerStorage = buyPrice;
      if (factor > 1.0) {
        costPerStorage = buyPrice / factor;
      }

      double storageQty = quantity;
      if (conversionToStorage > 0 && conversionToStorage != 1.0) {
        storageQty = quantity * conversionToStorage;
      }

      double itemCost = storageQty * costPerStorage;
      double itemProfit = itemTotal - itemCost;

      invoiceCost += itemCost;

      print('  - ${item['productName']}');
      print('    Sale Unit: ${item['saleUnit']}, Qty: $quantity, Price: $itemTotal');
      print('    Buy Price: $buyPrice, unitsPerPurchaseUnit: $unitsPerPurchaseUnit, conversionFactor: $conversionFactor');
      print('    conversionToStorage: $conversionToStorage');
      print('    Calculated: costPerStorage=$costPerStorage, storageQty=$storageQty, itemCost=$itemCost, itemProfit=$itemProfit');
    }

    double invoiceProfit = invoiceRevenue - invoiceCost;
    print('Invoice Revenue: $invoiceRevenue');
    print('Invoice Cost: $invoiceCost');
    print('Invoice Profit: $invoiceProfit');
    print('');
  }

  // Check if invoice_items has itemCost column
  final columns = await db.rawQuery('PRAGMA table_info(invoice_items)');
  print('=== INVOICE_ITEMS COLUMNS ===');
  bool hasItemCost = false;
  for (var col in columns) {
    print('${col['name']}: ${col['type']}');
    if (col['name'] == 'itemCost') {
      hasItemCost = true;
    }
  }
  print('\nHas itemCost column: $hasItemCost');

  // Check purchase_invoice_items structure
  final purchaseColumns = await db.rawQuery('PRAGMA table_info(purchase_invoice_items)');
  print('\n=== PURCHASE_INVOICE_ITEMS COLUMNS ===');
  for (var col in purchaseColumns) {
    print('${col['name']}: ${col['type']}');
  }

  await db.close();
}
