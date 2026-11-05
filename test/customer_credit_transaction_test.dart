import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/models/inventory_movement_model.dart';
import 'package:sahel_cash/models/invoice_item_model.dart';
import 'package:sahel_cash/models/invoice_model.dart';
import 'package:sahel_cash/models/product_model.dart';
import 'package:sahel_cash/models/receipt_voucher_model.dart';
import 'package:sahel_cash/data/repositories/invoice_repository.dart';
import 'package:sahel_cash/repositories/purchase_invoice_repository.dart';
import 'package:sahel_cash/utils/stock_quantity_converter.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  final helper = DatabaseHelper.instance;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
CREATE TABLE products(
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  barcode TEXT,
  sku TEXT,
  purchasePrice REAL,
  salePrice REAL,
  quantity REAL,
  minimumQuantity REAL,
  category TEXT,
  brand TEXT,
  supplier TEXT,
  description TEXT,
  imagePath TEXT,
  storageUnit TEXT,
  conversionFactor REAL,
  purchaseUnit TEXT,
  saleUnit TEXT,
  unitsPerPurchaseUnit REAL,
  isActive INTEGER NOT NULL DEFAULT 1
)
''');
    await db.execute('''
CREATE TABLE customers(
  id INTEGER PRIMARY KEY,
  currentBalance REAL DEFAULT 0,
  updatedAt TEXT
)
''');
    await db.execute('''
CREATE TABLE invoices(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceNumber TEXT UNIQUE NOT NULL,
  date TEXT NOT NULL,
  total REAL NOT NULL,
  paymentMethod TEXT NOT NULL,
  customerId INTEGER,
  notes TEXT,
  cashierId INTEGER,
  cashierName TEXT,
  discount REAL DEFAULT 0.0,
  discountType TEXT,
  paidAmount REAL DEFAULT 0.0,
  changeAmount REAL DEFAULT 0.0,
  status TEXT NOT NULL DEFAULT 'posted',
  cancelledAt TEXT,
  cancellationReason TEXT,
  FOREIGN KEY(customerId) REFERENCES customers(id)
)
''');
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
  isWholesale INTEGER NOT NULL,
  FOREIGN KEY(invoiceId) REFERENCES invoices(id),
  FOREIGN KEY(productId) REFERENCES products(id)
)
''');
    await db.execute('''
CREATE TABLE product_sale_units(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  productId INTEGER NOT NULL,
  saleUnit TEXT NOT NULL,
  conversionToStorage REAL NOT NULL
)
''');
    await db.execute('''
CREATE TABLE receipt_vouchers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  voucherNumber TEXT UNIQUE NOT NULL,
  customerId INTEGER NOT NULL,
  invoiceId INTEGER,
  date TEXT NOT NULL,
  amount REAL NOT NULL,
  paymentMethod TEXT NOT NULL,
  notes TEXT,
  createdAt TEXT NOT NULL,
  FOREIGN KEY(customerId) REFERENCES customers(id),
  FOREIGN KEY(invoiceId) REFERENCES invoices(id) ON DELETE SET NULL
)
''');
    await db.execute('''
CREATE TABLE suppliers(
  id INTEGER PRIMARY KEY,
  name TEXT,
  currentBalance REAL DEFAULT 0,
  updatedAt TEXT
)
''');
    await db.execute('''
CREATE TABLE purchase_invoices(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceNumber TEXT NOT NULL UNIQUE,
  supplierId INTEGER NOT NULL,
  date TEXT NOT NULL,
  subtotal REAL DEFAULT 0,
  discount REAL DEFAULT 0,
  totalAmount REAL DEFAULT 0,
  paymentType TEXT NOT NULL,
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'posted',
  cancelledAt TEXT,
  cancellationReason TEXT
)
''');
    await db.execute('''
CREATE TABLE purchase_invoice_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceId INTEGER NOT NULL,
  productId INTEGER NOT NULL,
  quantity REAL NOT NULL DEFAULT 0,
  unitPrice REAL NOT NULL DEFAULT 0,
  total REAL NOT NULL DEFAULT 0,
  purchaseUnit TEXT NOT NULL DEFAULT 'قطعة',
  conversionFactor REAL NOT NULL DEFAULT 1,
  storageQuantity REAL NOT NULL DEFAULT 0
)
''');
    await DatabaseHelper.createInventoryMovementsTable(db);
    await DatabaseHelper.createCustomerAccountTransactionsTable(db);
    await db.insert('products', {
      'id': 1,
      'name': 'اختبار',
      'quantity': 10.0,
      'storageUnit': 'قطعة',
      'conversionFactor': 1.0,
    });
    await db.insert('customers', {
      'id': 1,
      'currentBalance': 20.0,
      'updatedAt': '2026-10-01',
    });
    await db.insert('customer_account_transactions', {
      'customerId': 1,
      'transactionType': 'opening_balance',
      'amount': 20.0,
      'sourceType': 'legacy_opening_balance',
      'sourceDocumentId': 1,
      'occurredAt': '2026-10-01',
      'recordedAt': '2026-10-01',
      'reason': 'رصيد مرحلي محفوظ',
      'idempotencyKey': 'legacy-opening:1',
    });
    await db.insert('suppliers', {
      'id': 1,
      'name': 'مورد اختبار',
      'currentBalance': 0.0,
      'updatedAt': '2026-10-01',
    });
    await db.insert('products', {
      'id': 2,
      'name': 'اختبار بالكيلو',
      'quantity': 0.0,
      'storageUnit': 'كيلو',
      'conversionFactor': 1.0,
      'purchaseUnit': 'كيلو',
      'unitsPerPurchaseUnit': 1,
    });
    DatabaseHelper.setDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  test(
    'cash sale commits stock and leaves customer balance unchanged',
    () async {
      await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'cash', customerId: 1, total: 30),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );

      expect(await _productQuantity(db), 8);
      expect(await _customerBalance(db), 20);
      expect(await _countRows(db, 'invoices'), 1);
      expect(await _countRows(db, 'invoice_items'), 1);
    },
  );

  test(
    'split invoice repository writes cannot bypass ledger transactions',
    () async {
      final repository = InvoiceRepository();

      await expectLater(
        repository.createInvoice(
          _invoice(paymentMethod: 'credit', customerId: 1, total: 30),
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.createInvoiceItem(_item(productId: 1, invoiceId: 0)),
        throwsA(isA<StateError>()),
      );

      expect(await _countRows(db, 'invoices'), 0);
      expect(await _countRows(db, 'invoice_items'), 0);
    },
  );

  test(
    'credit sale atomically commits stock and increases customer balance',
    () async {
      await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 30),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );

      expect(await _productQuantity(db), 8);
      expect(await _customerBalance(db), 50);
    },
  );

  test(
    'failed stock update rolls back invoice, earlier stock, and balance changes',
    () async {
      await expectLater(
        helper.createSalesInvoiceWithItems(
          invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 30),
          items: [
            _item(productId: 1, invoiceId: 0),
            _item(productId: 999, invoiceId: 0),
          ],
          stockReductions: {1: 2, 999: 1},
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _productQuantity(db), 10);
      expect(await _customerBalance(db), 20);
      expect(await _countRows(db, 'invoices'), 0);
      expect(await _countRows(db, 'invoice_items'), 0);
      expect(await _countRows(db, 'inventory_movements'), 0);
    },
  );

  test('inbound and outbound movements update stock atomically', () async {
    final now = DateTime.now().toIso8601String();
    await helper.recordInventoryMovement(
      InventoryMovement(
        productId: 1,
        movementType: InventoryMovement.purchaseReceipt,
        direction: InventoryMovement.inbound,
        quantity: 3,
        storageUnit: 'قطعة',
        sourceType: InventoryMovement.purchaseInvoice,
        movementAt: now,
        recordedAt: now,
        idempotencyKey: 'test-purchase-receipt',
      ),
    );
    expect(await _productQuantity(db), 13);

    await helper.recordInventoryMovement(
      InventoryMovement(
        productId: 1,
        movementType: InventoryMovement.saleIssue,
        direction: InventoryMovement.outbound,
        quantity: 2,
        storageUnit: 'قطعة',
        sourceType: InventoryMovement.salesInvoice,
        movementAt: now,
        recordedAt: now,
        idempotencyKey: 'test-sale-issue',
      ),
    );
    expect(await _productQuantity(db), 11);
    expect(await _countRows(db, 'inventory_movements'), 2);
  });

  test('duplicate movement key does not update stock twice', () async {
    final now = DateTime.now().toIso8601String();
    final movement = InventoryMovement(
      productId: 1,
      movementType: InventoryMovement.adjustmentIn,
      direction: InventoryMovement.inbound,
      quantity: 2,
      storageUnit: 'قطعة',
      sourceType: InventoryMovement.manualAdjustment,
      movementAt: now,
      recordedAt: now,
      idempotencyKey: 'same-adjustment',
    );

    final firstId = await helper.recordInventoryMovement(movement);
    final secondId = await helper.recordInventoryMovement(movement);

    expect(secondId, firstId);
    expect(await _productQuantity(db), 12);
    expect(await _countRows(db, 'inventory_movements'), 1);
  });

  test('opening stock and product quantity edits create movements', () async {
    final productId = await helper.insertProduct(
      Product(
        name: 'رصيد افتتاحي',
        barcode: '',
        sku: '',
        category: '',
        brand: '',
        buyPrice: 0,
        sellPrice: 0,
        quantity: 5,
        minQuantity: 0,
        description: '',
        storageUnit: 'قطعة',
      ),
    );
    expect(await _productQuantity(db, productId: productId), 5);
    final openingMovement = (await db.query(
      'inventory_movements',
      where: 'productId = ?',
      whereArgs: [productId],
    )).single;
    expect(openingMovement['movementType'], InventoryMovement.openingBalance);
    expect(
      openingMovement['sourceType'],
      InventoryMovement.sourceOpeningBalance,
    );

    final product = Product.fromMap(
      (await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      )).single,
    )..quantity = 8;
    await helper.updateProduct(product, inventoryChangeReason: 'تسوية جرد');
    expect(await _productQuantity(db, productId: productId), 8);
    final movements = await db.query(
      'inventory_movements',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'id',
    );
    expect(movements, hasLength(2));
    expect(movements.last['movementType'], InventoryMovement.adjustmentIn);
    expect(movements.last['reason'], 'تسوية جرد');

    product.quantity = 7;
    await helper.updateProduct(
      product,
      inventoryChangeReason: 'تالف أثناء الفحص',
    );
    expect(await _productQuantity(db, productId: productId), 7);
    final lastMovement = (await db.query(
      'inventory_movements',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'id DESC',
      limit: 1,
    )).single;
    expect(lastMovement['movementType'], InventoryMovement.damage);
  });

  test(
    'product quantity cannot change without a reason or below zero',
    () async {
      final product = Product.fromMap(
        (await db.query('products', where: 'id = 1')).single,
      )..quantity = 12;

      await expectLater(
        helper.updateProduct(product),
        throwsA(isA<StateError>()),
      );
      expect(await _productQuantity(db), 10);
      expect(await _countRows(db, 'inventory_movements'), 0);

      product.quantity = -1;
      await expectLater(
        helper.updateProduct(product, inventoryChangeReason: 'تصحيح'),
        throwsArgumentError,
      );
      expect(await _productQuantity(db), 10);
      expect(await _countRows(db, 'inventory_movements'), 0);
    },
  );

  test(
    'product deletion and clear archive products without erasing history',
    () async {
      final now = DateTime.now().toIso8601String();
      await helper.recordInventoryMovement(
        InventoryMovement(
          productId: 1,
          movementType: InventoryMovement.adjustmentIn,
          direction: InventoryMovement.inbound,
          quantity: 1,
          storageUnit: 'قطعة',
          sourceType: InventoryMovement.manualAdjustment,
          movementAt: now,
          recordedAt: now,
          idempotencyKey: 'product-archive-history',
        ),
      );
      final invoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'cash', customerId: null, total: 15),
        items: [
          _item(
            productId: 1,
            invoiceId: 0,
            quantity: 1,
            unitPrice: 15,
            total: 15,
          ),
        ],
        stockReductions: {1: 1},
      );

      await helper.deleteProduct(1);

      final archived = (await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [1],
      )).single;
      expect(archived['isActive'], 0);
      expect(archived['quantity'], 10);
      expect(await _countRows(db, 'inventory_movements'), 2);
      expect(await _countRows(db, 'invoices'), 1);
      expect(await _countRows(db, 'invoice_items'), 1);
      expect((await db.query('invoices')).single['id'], invoiceId);
      expect(
        await helper.getActiveProducts().then(
          (products) => products.any((product) => product.id == 1),
        ),
        isFalse,
      );

      await helper.restoreProduct(1);
      expect(
        (await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [1],
        )).single['isActive'],
        1,
      );

      await helper.clearProducts();
      expect(await _countRows(db, 'products'), 2);
      expect(await _countRows(db, 'inventory_movements'), 2);
      expect(
        (await db.query(
          'products',
        )).every((product) => product['isActive'] == 0),
        isTrue,
      );
    },
  );

  test('failed opening movement rolls back new product creation', () async {
    await db.execute('''
CREATE TRIGGER reject_test_opening_movement
BEFORE INSERT ON inventory_movements
WHEN NEW.movementType = 'opening_balance'
BEGIN
  SELECT RAISE(ABORT, 'test opening movement failure');
END
''');

    await expectLater(
      helper.insertProduct(
        Product(
          name: 'يجب التراجع عنه',
          barcode: '',
          sku: '',
          category: '',
          brand: '',
          buyPrice: 0,
          sellPrice: 0,
          quantity: 5,
          minQuantity: 0,
          description: '',
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect(await _countRows(db, 'products'), 2);
    expect(await _countRows(db, 'inventory_movements'), 0);
  });

  test(
    'movement reversal is one-time and a reversal cannot be reversed',
    () async {
      final now = DateTime.now().toIso8601String();
      final originalId = await helper.recordInventoryMovement(
        InventoryMovement(
          productId: 1,
          movementType: InventoryMovement.adjustmentIn,
          direction: InventoryMovement.inbound,
          quantity: 1,
          storageUnit: 'قطعة',
          sourceType: InventoryMovement.manualAdjustment,
          movementAt: now,
          recordedAt: now,
          idempotencyKey: 'reversal-test-original',
        ),
      );
      final reversalId = await helper.reverseInventoryMovement(
        originalId,
        idempotencyKey: 'reversal-test-once',
        recordedAt: now,
        reason: 'اختبار',
      );

      await expectLater(
        helper.reverseInventoryMovement(
          originalId,
          idempotencyKey: 'reversal-test-another-key',
          recordedAt: now,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        helper.reverseInventoryMovement(
          reversalId,
          idempotencyKey: 'reverse-a-reversal',
          recordedAt: now,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _productQuantity(db), 10);
      expect(await _countRows(db, 'inventory_movements'), 2);
    },
  );

  test('new movements do not rewrite legacy invoice records', () async {
    final oldInvoiceId = await db.insert('invoices', {
      'invoiceNumber': 'LEGACY-1',
      'date': '2025-01-01',
      'total': 30.0,
      'paymentMethod': 'cash',
    });
    await db.insert('invoice_items', {
      'invoiceId': oldInvoiceId,
      'productId': 1,
      'productName': 'اختبار',
      'saleUnit': 'قطعة',
      'quantity': 2.0,
      'unitPrice': 15.0,
      'total': 30.0,
      'isWholesale': 0,
    });
    final now = DateTime.now().toIso8601String();

    await helper.recordInventoryMovement(
      InventoryMovement(
        productId: 1,
        movementType: InventoryMovement.adjustmentIn,
        direction: InventoryMovement.inbound,
        quantity: 1,
        storageUnit: 'قطعة',
        sourceType: InventoryMovement.manualAdjustment,
        movementAt: now,
        recordedAt: now,
        idempotencyKey: 'post-ledger-adjustment',
      ),
    );

    final invoice = (await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [oldInvoiceId],
    )).single;
    final invoiceItems = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [oldInvoiceId],
    );
    expect(invoice['total'], 30);
    expect(invoiceItems.single['quantity'], 2);
    expect(await _countRows(db, 'inventory_movements'), 1);
  });

  test(
    'legacy sale cancellation is blocked when movement history is missing',
    () async {
      final oldInvoiceId = await db.insert('invoices', {
        'invoiceNumber': 'LEGACY-SALE-1',
        'date': '2025-01-01',
        'total': 30.0,
        'paymentMethod': 'cash',
      });
      final oldItemId = await db.insert('invoice_items', {
        'invoiceId': oldInvoiceId,
        'productId': 1,
        'productName': 'اختبار',
        'saleUnit': 'قطعة',
        'quantity': 2.0,
        'unitPrice': 15.0,
        'total': 30.0,
        'isWholesale': 0,
      });
      await db.update('products', {'quantity': 8.0}, where: 'id = 1');

      await expectLater(
        helper.cancelSalesInvoiceWithEffects(
          oldInvoiceId,
          reason: 'فحص فاتورة قديمة',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _productQuantity(db), 8);
      expect(await _countRows(db, 'inventory_movements'), 0);
      final invoice = (await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [oldInvoiceId],
      )).single;
      expect(invoice['status'], 'posted');
      expect(invoice['cancellationReason'], isNull);
      expect(
        await _countRows(db, 'invoice_items'),
        1,
        reason: 'The original invoice line must remain unchanged',
      );
      expect(oldItemId, isPositive);
    },
  );

  test('purchase invoice records an inbound movement and reversal', () async {
    final now = DateTime.now().toIso8601String();
    final invoiceId = await helper.createPurchaseInvoice(
      {
        'supplierId': 1,
        'date': now,
        'subtotal': 360.0,
        'discount': 0.0,
        'totalAmount': 360.0,
        'paymentType': 'cash',
        'createdAt': now,
        'updatedAt': now,
      },
      [
        {
          'productId': 2,
          'quantity': 4.0,
          'unitPrice': 90.0,
          'total': 360.0,
          'purchaseUnit': 'كيلو',
        },
      ],
    );

    expect(await _productQuantity(db, productId: 2), 4);
    final receiptRows = await db.query(
      'inventory_movements',
      where: 'sourceType = ? AND sourceDocumentId = ?',
      whereArgs: [InventoryMovement.purchaseInvoice, invoiceId],
    );
    expect(receiptRows, hasLength(1));
    expect(receiptRows.single['totalCost'], 360);
    expect(receiptRows.single['costStatus'], InventoryMovement.costKnown);

    await helper.cancelPurchaseInvoice(invoiceId, reason: 'إلغاء اختبار');

    expect(await _productQuantity(db, productId: 2), 0);
    expect(await _countRows(db, 'purchase_invoice_items'), 1);
    expect(await _countRows(db, 'purchase_invoices'), 1);
    expect(await _countRows(db, 'inventory_movements'), 2);
    final invoice = (await db.query(
      'purchase_invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    )).single;
    expect(invoice['status'], 'voided');
    expect(invoice['cancellationReason'], 'إلغاء اختبار');
    final reversalRows = await db.query(
      'inventory_movements',
      where: 'reversalOfMovementId = ?',
      whereArgs: [receiptRows.single['id']],
    );
    expect(reversalRows, hasLength(1));
    expect(
      reversalRows.single['sourceType'],
      InventoryMovement.purchaseInvoiceReversal,
    );
    expect(await helper.cancelPurchaseInvoice(invoiceId, reason: 'تكرار'), 0);
    expect(await _countRows(db, 'inventory_movements'), 2);
  });

  test('purchase cancellation is blocked after a later sale', () async {
    final now = DateTime.now().toIso8601String();
    final purchaseId = await helper.createPurchaseInvoice(
      {
        'supplierId': 1,
        'date': now,
        'subtotal': 360.0,
        'discount': 0.0,
        'totalAmount': 360.0,
        'paymentType': 'cash',
        'createdAt': now,
        'updatedAt': now,
      },
      [
        {
          'productId': 2,
          'quantity': 4.0,
          'unitPrice': 90.0,
          'total': 360.0,
          'purchaseUnit': 'كيلو',
        },
      ],
    );
    final saleId = await helper.createSalesInvoiceWithItems(
      invoice: _invoice(paymentMethod: 'cash', customerId: null, total: 100),
      items: [
        _item(
          productId: 2,
          invoiceId: 0,
          saleUnit: 'كيلو',
          quantity: 1,
          unitPrice: 100,
          total: 100,
        ),
      ],
      stockReductions: {2: 1},
    );

    await expectLater(
      helper.cancelPurchaseInvoice(purchaseId, reason: 'إلغاء غير آمن'),
      throwsA(isA<StateError>()),
    );

    expect(await _productQuantity(db, productId: 2), 3);
    expect(await _countRows(db, 'inventory_movements'), 2);
    expect(await _countRows(db, 'purchase_invoice_items'), 1);
    expect(await _countRows(db, 'purchase_invoices'), 1);
    expect((await db.query('purchase_invoices')).single['status'], 'posted');
    expect(await _countRows(db, 'invoices'), 1);
    expect(
      await db.query('invoices').then((rows) => rows.single['id']),
      saleId,
    );
  });

  test(
    'failed purchase cancellation rolls back movement and invoice status',
    () async {
      final now = DateTime.now().toIso8601String();
      final purchaseId = await helper.createPurchaseInvoice(
        {
          'supplierId': 1,
          'date': now,
          'subtotal': 360.0,
          'discount': 0.0,
          'totalAmount': 360.0,
          'paymentType': 'cash',
          'createdAt': now,
          'updatedAt': now,
        },
        [
          {
            'productId': 2,
            'quantity': 4.0,
            'unitPrice': 90.0,
            'total': 360.0,
            'purchaseUnit': 'كيلو',
          },
        ],
      );
      await db.execute('''
CREATE TRIGGER reject_test_purchase_void
BEFORE UPDATE OF status ON purchase_invoices
WHEN NEW.status = 'voided'
BEGIN
  SELECT RAISE(ABORT, 'test purchase cancellation failure');
END
''');

      await expectLater(
        helper.cancelPurchaseInvoice(purchaseId, reason: 'فشل اختبار'),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _productQuantity(db, productId: 2), 4);
      expect(await _countRows(db, 'inventory_movements'), 1);
      expect((await db.query('purchase_invoices')).single['status'], 'posted');
    },
  );

  test('credit purchase cancellation reverses supplier balance once', () async {
    final now = DateTime.now().toIso8601String();
    final purchaseId = await helper.createPurchaseInvoice(
      {
        'supplierId': 1,
        'date': now,
        'subtotal': 90.0,
        'discount': 0.0,
        'totalAmount': 90.0,
        'paymentType': 'credit',
        'createdAt': now,
        'updatedAt': now,
      },
      [
        {
          'productId': 2,
          'quantity': 1.0,
          'unitPrice': 90.0,
          'total': 90.0,
          'purchaseUnit': 'كيلو',
        },
      ],
    );
    expect(await _supplierBalance(db), 90);

    expect(
      await helper.cancelPurchaseInvoice(purchaseId, reason: 'إلغاء اختبار'),
      1,
    );
    expect(await _supplierBalance(db), 0);
    expect(
      await helper.cancelPurchaseInvoice(purchaseId, reason: 'محاولة أخرى'),
      0,
    );
    expect(await _supplierBalance(db), 0);
    expect(await _productQuantity(db, productId: 2), 0);
    expect(await _countRows(db, 'inventory_movements'), 2);
  });

  test(
    'voided invoices remain reviewable but are excluded from summaries',
    () async {
      final saleId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'cash', customerId: null, total: 30),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );
      await helper.cancelSalesInvoiceWithEffects(
        saleId,
        reason: 'إلغاء اختبار',
      );
      final invoiceRepository = InvoiceRepository();
      expect(await invoiceRepository.getAllInvoices(), hasLength(1));
      expect(
        await invoiceRepository.getAllInvoices(includeVoided: false),
        isEmpty,
      );

      final now = DateTime.now().toIso8601String();
      final purchaseId = await helper.createPurchaseInvoice(
        {
          'supplierId': 1,
          'date': now,
          'subtotal': 90.0,
          'discount': 0.0,
          'totalAmount': 90.0,
          'paymentType': 'cash',
          'createdAt': now,
          'updatedAt': now,
        },
        [
          {
            'productId': 2,
            'quantity': 1.0,
            'unitPrice': 90.0,
            'total': 90.0,
            'purchaseUnit': 'كيلو',
          },
        ],
      );
      await helper.cancelPurchaseInvoice(purchaseId, reason: 'إلغاء اختبار');
      final purchaseRepository = PurchaseInvoiceRepository();
      expect(await purchaseRepository.getAllPurchaseInvoices(), hasLength(1));
      expect(
        await purchaseRepository.getAllPurchaseInvoices(includeVoided: false),
        isEmpty,
      );
    },
  );

  test(
    'legacy purchase cancellation is blocked without changing stock',
    () async {
      final now = DateTime.now().toIso8601String();
      final purchaseId = await db.insert('purchase_invoices', {
        'invoiceNumber': 'LEGACY-PUR-1',
        'supplierId': 1,
        'date': now,
        'subtotal': 90.0,
        'discount': 0.0,
        'totalAmount': 90.0,
        'paymentType': 'cash',
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('purchase_invoice_items', {
        'invoiceId': purchaseId,
        'productId': 2,
        'quantity': 1.0,
        'unitPrice': 90.0,
        'total': 90.0,
        'purchaseUnit': 'كيلو',
        'conversionFactor': 1.0,
        'storageQuantity': 1.0,
      });

      await expectLater(
        helper.cancelPurchaseInvoice(purchaseId, reason: 'مراجعة'),
        throwsA(isA<StateError>()),
      );

      expect(await _productQuantity(db, productId: 2), 0);
      expect(await _countRows(db, 'inventory_movements'), 0);
      expect((await db.query('purchase_invoices')).single['status'], 'posted');
      expect(await _countRows(db, 'purchase_invoice_items'), 1);
    },
  );

  test(
    'sales returns and damage adjustments are auditable movements',
    () async {
      final now = DateTime.now().toIso8601String();
      await helper.recordInventoryMovement(
        InventoryMovement(
          productId: 1,
          movementType: InventoryMovement.salesReturn,
          direction: InventoryMovement.inbound,
          quantity: 1,
          storageUnit: 'قطعة',
          sourceType: InventoryMovement.sourceSalesReturn,
          movementAt: now,
          recordedAt: now,
          reason: 'مرتجع اختبار',
          idempotencyKey: 'test-sales-return',
        ),
      );
      await helper.recordInventoryMovement(
        InventoryMovement(
          productId: 1,
          movementType: InventoryMovement.damage,
          direction: InventoryMovement.outbound,
          quantity: 2,
          storageUnit: 'قطعة',
          sourceType: InventoryMovement.sourceDamage,
          movementAt: now,
          recordedAt: now,
          reason: 'تالف اختبار',
          idempotencyKey: 'test-damage',
        ),
      );

      expect(await _productQuantity(db), 9);
      final movements = await db.query('inventory_movements', orderBy: 'id');
      expect(movements.map((row) => row['movementType']), [
        InventoryMovement.salesReturn,
        InventoryMovement.damage,
      ]);
    },
  );

  test('failed ledger insert rolls back the stock update', () async {
    await db.execute('''
CREATE TRIGGER reject_test_movement
BEFORE INSERT ON inventory_movements
WHEN NEW.idempotencyKey = 'reject-me'
BEGIN
  SELECT RAISE(ABORT, 'test insert failure');
END
''');
    final now = DateTime.now().toIso8601String();

    await expectLater(
      helper.recordInventoryMovement(
        InventoryMovement(
          productId: 1,
          movementType: InventoryMovement.adjustmentIn,
          direction: InventoryMovement.inbound,
          quantity: 5,
          storageUnit: 'قطعة',
          sourceType: InventoryMovement.manualAdjustment,
          movementAt: now,
          recordedAt: now,
          idempotencyKey: 'reject-me',
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect(await _productQuantity(db), 10);
    expect(await _countRows(db, 'inventory_movements'), 0);
  });

  test(
    'receipt reduces balance and may be allocated to the customer invoice',
    () async {
      final invoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 40),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );

      await helper.createReceiptVoucher(
        _voucher(invoiceId: invoiceId, amount: 15),
      );

      expect(await _customerBalance(db), 45);
      final vouchers = await helper.getReceiptVouchersForCustomer(1);
      expect(vouchers.single['invoiceId'], invoiceId);
      expect(vouchers.single['voucherNumber'], 'REC-0001');
    },
  );

  test('receipt may be left unallocated to a specific invoice', () async {
    await helper.createReceiptVoucher(
      ReceiptVoucher(
        voucherNumber: '',
        customerId: 1,
        date: '2026-10-01',
        amount: 10,
        createdAt: '2026-10-01',
        idempotencyKey: 'unallocated-receipt-once',
      ),
    );

    expect(await _customerBalance(db), 10);
    final vouchers = await helper.getReceiptVouchersForCustomer(1);
    expect(vouchers.single['invoiceId'], isNull);
  });

  test('receipt retry with the same idempotency key records once', () async {
    final voucher = ReceiptVoucher(
      voucherNumber: '',
      customerId: 1,
      date: '2026-10-02',
      amount: 10,
      createdAt: '2026-10-02',
      idempotencyKey: 'receipt-request-once',
    );

    final firstId = await helper.createReceiptVoucher(voucher);
    final retryId = await helper.createReceiptVoucher(voucher);

    expect(retryId, firstId);
    expect(await _customerBalance(db), 10);
    expect(await _countRows(db, 'receipt_vouchers'), 1);
    expect(await _countRows(db, 'customer_account_transactions'), 2);
  });

  test(
    'unallocated receipts remain independent when an invoice is cancelled',
    () async {
      final firstInvoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 40),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );
      await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 40),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );
      final unallocatedReceipt = ReceiptVoucher(
        voucherNumber: '',
        customerId: 1,
        date: '2026-10-03',
        amount: 10,
        createdAt: '2026-10-03',
        idempotencyKey: 'unallocated-before-cancellation',
      );
      await helper.createReceiptVoucher(unallocatedReceipt);
      expect(await _customerBalance(db), 90);

      await helper.cancelSalesInvoiceWithEffects(
        firstInvoiceId,
        reason: 'إلغاء فاتورة واحدة',
      );

      expect(await _customerBalance(db), 50);
      final receiptRows = await db.query(
        'customer_account_transactions',
        where: 'sourceType = ?',
        whereArgs: ['receipt_voucher'],
      );
      expect(receiptRows, hasLength(1));
      expect(receiptRows.single['amount'], -10);
      final reversalRows = await db.query(
        'customer_account_transactions',
        where: 'sourceType = ? AND sourceDocumentId = ?',
        whereArgs: ['sales_invoice_cancellation', firstInvoiceId],
      );
      expect(reversalRows, hasLength(1));
      expect(reversalRows.single['amount'], -40);
      expect(reversalRows.single['reversalOfTransactionId'], isNotNull);

      await helper.cancelSalesInvoiceWithEffects(
        firstInvoiceId,
        reason: 'إعادة المحاولة',
      );
      expect(await _customerBalance(db), 50);
      expect(await _countRows(db, 'customer_account_transactions'), 5);
    },
  );

  test('credit invoice without an account entry cannot be cancelled', () async {
    final invoiceId = await helper.createSalesInvoiceWithItems(
      invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 40),
      items: [_item(productId: 1, invoiceId: 0)],
      stockReductions: {1: 2},
    );
    await db.delete(
      'customer_account_transactions',
      where: 'sourceType = ? AND sourceDocumentId = ?',
      whereArgs: ['credit_sales_invoice', invoiceId],
    );
    final initialQuantity = await _productQuantity(db);
    final initialBalance = await _customerBalance(db);

    await expectLater(
      helper.cancelSalesInvoiceWithEffects(invoiceId, reason: 'مراجعة'),
      throwsA(isA<StateError>()),
    );

    expect(await _productQuantity(db), initialQuantity);
    expect(await _customerBalance(db), initialBalance);
    expect((await db.query('invoices')).single['status'], 'posted');
  });

  test(
    'legacy opening ledger snapshot does not change customer balance',
    () async {
      await db.insert('customers', {
        'id': 2,
        'currentBalance': 17.5,
        'updatedAt': '2026-10-01',
      });

      await DatabaseHelper.seedLegacyCustomerAccountBalances(db);

      expect(await _customerBalance(db), 20);
      final rows = await db.query(
        'customer_account_transactions',
        where: 'customerId = ? AND sourceType = ?',
        whereArgs: [2, 'legacy_opening_balance'],
      );
      expect(rows.single['amount'], 17.5);
      expect(rows.single['idempotencyKey'], 'legacy-opening:2');
    },
  );

  test(
    'customer ledger migration snapshots without changing legacy data',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'sahel_cash_ledger_migration_',
      );
      Database? legacyDb;
      try {
        legacyDb = await databaseFactoryFfi.openDatabase(
          '${tempDirectory.path}${Platform.pathSeparator}legacy.db',
        );
        await legacyDb.execute(
          'CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT)',
        );
        await legacyDb.execute('''
CREATE TABLE customers(
  id INTEGER PRIMARY KEY,
  currentBalance REAL DEFAULT 0
)
''');
        await legacyDb.insert('products', {'id': 7, 'name': 'قديم'});
        await legacyDb.insert('customers', {'id': 9, 'currentBalance': 42.5});

        await DatabaseHelper.migrateCustomerAccountLedger(legacyDb);

        final columns = await legacyDb.rawQuery('PRAGMA table_info(products)');
        expect(columns.any((column) => column['name'] == 'isActive'), isTrue);
        expect((await legacyDb.query('products')).single['isActive'], 1);
        expect(
          (await legacyDb.query('customers')).single['currentBalance'],
          42.5,
        );
        final opening = (await legacyDb.query(
          'customer_account_transactions',
        )).single;
        expect(opening['amount'], 42.5);
        expect(opening['transactionType'], 'opening_balance');
        expect(opening['reason'], 'رصيد مرحلي محفوظ دون إعادة بناء التاريخ');
      } finally {
        await legacyDb?.close();
        await tempDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'customer balance adjustment requires reason and records atomically',
    () async {
      await expectLater(
        helper.updateCustomerBalance(
          1,
          5,
          reason: '',
          idempotencyKey: 'adjustment-invalid',
        ),
        throwsArgumentError,
      );
      await helper.updateCustomerBalance(
        1,
        -3,
        reason: 'تسوية معتمدة',
        idempotencyKey: 'customer-adjustment-once',
      );
      await helper.updateCustomerBalance(
        1,
        -3,
        reason: 'تسوية معتمدة',
        idempotencyKey: 'customer-adjustment-once',
      );

      expect(await _customerBalance(db), 17);
      final rows = await db.query(
        'customer_account_transactions',
        where: 'transactionType = ?',
        whereArgs: ['adjustment'],
      );
      expect(rows.single['amount'], -3);
      expect(rows.single['reason'], 'تسوية معتمدة');
    },
  );

  test('receipt cannot exceed customer balance', () async {
    await expectLater(
      helper.createReceiptVoucher(
        ReceiptVoucher(
          voucherNumber: '',
          customerId: 1,
          date: '2026-10-01',
          amount: 21,
          createdAt: '2026-10-01',
          idempotencyKey: 'over-limit-receipt',
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await _customerBalance(db), 20);
    expect(await _countRows(db, 'receipt_vouchers'), 0);
  });

  test(
    'deleting an invoice with a linked receipt is rejected without side effects',
    () async {
      final invoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 40),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );
      await helper.createReceiptVoucher(
        _voucher(invoiceId: invoiceId, amount: 15),
      );

      await expectLater(
        helper.cancelSalesInvoiceWithEffects(invoiceId, reason: 'إلغاء اختبار'),
        throwsA(isA<StateError>()),
      );

      expect(await _productQuantity(db), 8);
      expect(await _customerBalance(db), 45);
      expect(await _countRows(db, 'invoices'), 1);
    },
  );

  test(
    'deleting unpaid credit invoice restores stock and reverses balance',
    () async {
      final invoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 30),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );

      await helper.cancelSalesInvoiceWithEffects(
        invoiceId,
        reason: 'إلغاء اختبار',
      );

      expect(await _productQuantity(db), 10);
      expect(await _customerBalance(db), 20);
      expect(await _countRows(db, 'invoices'), 1);
      expect(await _countRows(db, 'invoice_items'), 1);
      expect((await db.query('invoices')).single['status'], 'voided');
    },
  );

  test(
    'failed invoice deletion rolls back its reversal and stock update',
    () async {
      final invoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'cash', customerId: null, total: 30),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      );
      await db.execute('''
CREATE TRIGGER reject_test_invoice_cancel
BEFORE UPDATE OF status ON invoices
WHEN NEW.status = 'voided'
BEGIN
  SELECT RAISE(ABORT, 'test cancellation failure');
END
''');

      await expectLater(
        helper.cancelSalesInvoiceWithEffects(invoiceId, reason: 'إلغاء اختبار'),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _productQuantity(db), 8);
      expect(await _countRows(db, 'invoices'), 1);
      expect(await _countRows(db, 'invoice_items'), 1);
      expect(await _countRows(db, 'inventory_movements'), 1);
    },
  );

  test(
    'selling 500 grams and reversing restores half a kilogram only once',
    () async {
      await db.insert('products', {
        'id': 44,
        'name': 'اكياس شفاف 20*20',
        'quantity': 10.0,
        'storageUnit': 'كيلو',
        'conversionFactor': 1.0,
      });
      await db.insert('product_sale_units', {
        'productId': 44,
        'saleUnit': 'جرام',
        'conversionToStorage': 1.0,
      });
      const soldQuantity = 500.0;
      final stockReduction = calculateStorageQuantity(
        quantity: soldQuantity,
        saleUnit: 'جرام',
        storageUnit: 'كيلو',
        conversionToStorage: 1,
      );
      final invoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'cash', customerId: null, total: 60),
        items: [
          _item(
            productId: 44,
            invoiceId: 0,
            saleUnit: 'جرام',
            quantity: soldQuantity,
            unitPrice: 0.12,
            total: 60,
          ),
        ],
        stockReductions: {44: stockReduction},
      );

      expect(await _productQuantity(db, productId: 44), 9.5);

      await helper.cancelSalesInvoiceWithEffects(
        invoiceId,
        reason: 'إلغاء اختبار',
      );
      expect(await _productQuantity(db, productId: 44), 10);
      expect(await _countRows(db, 'inventory_movements'), 2);

      await helper.cancelSalesInvoiceWithEffects(
        invoiceId,
        reason: 'تكرار الإلغاء',
      );
      expect(await _productQuantity(db, productId: 44), 10);
      expect(await _countRows(db, 'inventory_movements'), 2);
      expect(await _countRows(db, 'invoices'), 1);
      expect((await db.query('invoice_items')).length, 1);
    },
  );

  test('reversing a sale of one kilogram restores one kilogram', () async {
    await db.insert('products', {
      'id': 44,
      'name': 'اكياس شفاف 20*20',
      'quantity': 10.0,
      'storageUnit': 'كيلو',
      'conversionFactor': 1.0,
    });
    final stockReduction = calculateStorageQuantity(
      quantity: 1,
      saleUnit: 'كيلو',
      storageUnit: 'كيلو',
      conversionToStorage: 1000,
    );
    final invoiceId = await helper.createSalesInvoiceWithItems(
      invoice: _invoice(paymentMethod: 'cash', customerId: null, total: 100),
      items: [
        _item(
          productId: 44,
          invoiceId: 0,
          saleUnit: 'كيلو',
          quantity: 1,
          unitPrice: 100,
          total: 100,
        ),
      ],
      stockReductions: {44: stockReduction},
    );

    expect(await _productQuantity(db, productId: 44), 9);
    await helper.cancelSalesInvoiceWithEffects(
      invoiceId,
      reason: 'إلغاء اختبار',
    );
    expect(await _productQuantity(db, productId: 44), 10);
    expect(await _countRows(db, 'invoices'), 1);
  });

  test('reversal uses conversion factor for non-weight sale units', () async {
    await db.insert('products', {
      'id': 44,
      'name': 'اختبار',
      'quantity': 200.0,
      'storageUnit': 'قطعة',
      'conversionFactor': 1.0,
    });
    await db.insert('product_sale_units', {
      'productId': 44,
      'saleUnit': 'عامود',
      'conversionToStorage': 50.0,
    });
    final stockReduction = calculateStorageQuantity(
      quantity: 2,
      saleUnit: 'عامود',
      storageUnit: 'قطعة',
      conversionToStorage: 50,
    );
    final invoiceId = await helper.createSalesInvoiceWithItems(
      invoice: _invoice(paymentMethod: 'cash', customerId: null, total: 100),
      items: [
        _item(
          productId: 44,
          invoiceId: 0,
          saleUnit: 'عامود',
          quantity: 2,
          unitPrice: 50,
          total: 100,
        ),
      ],
      stockReductions: {44: stockReduction},
    );

    expect(await _productQuantity(db, productId: 44), 100);
    await helper.cancelSalesInvoiceWithEffects(
      invoiceId,
      reason: 'إلغاء اختبار',
    );
    expect(await _productQuantity(db, productId: 44), 200);
    expect(await _countRows(db, 'invoices'), 1);
  });

  test('credit sale without a customer is rejected', () async {
    await expectLater(
      helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: null, total: 30),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 2},
      ),
      throwsArgumentError,
    );
    expect(await _productQuantity(db), 10);
    expect(await _countRows(db, 'invoices'), 0);
  });
}

Invoice _invoice({
  required String paymentMethod,
  required int? customerId,
  required double total,
}) {
  return Invoice(
    invoiceNumber: 'TEST-${DateTime.now().microsecondsSinceEpoch}',
    date: '2026-10-01',
    total: total,
    paymentMethod: paymentMethod,
    customerId: customerId,
  );
}

InvoiceItem _item({
  required int productId,
  required int invoiceId,
  String saleUnit = 'قطعة',
  double quantity = 2,
  double unitPrice = 15,
  double total = 30,
}) {
  return InvoiceItem(
    invoiceId: invoiceId,
    productId: productId,
    productName: 'اختبار',
    saleUnit: saleUnit,
    quantity: quantity,
    unitPrice: unitPrice,
    total: total,
    isWholesale: false,
  );
}

ReceiptVoucher _voucher({required int invoiceId, required double amount}) {
  final now = DateTime.now().toIso8601String();
  return ReceiptVoucher(
    voucherNumber: '',
    customerId: 1,
    invoiceId: invoiceId,
    date: now,
    amount: amount,
    createdAt: now,
    idempotencyKey: 'receipt:$invoiceId:$now:$amount',
  );
}

Future<double> _productQuantity(Database db, {int productId = 1}) async {
  final rows = await db.query(
    'products',
    columns: ['quantity'],
    where: 'id = ?',
    whereArgs: [productId],
  );
  return (rows.single['quantity'] as num).toDouble();
}

Future<double> _customerBalance(Database db) async {
  return (await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [1],
      )).single['currentBalance']
      as double;
}

Future<double> _supplierBalance(Database db) async {
  return (await db.query('suppliers')).single['currentBalance'] as double;
}

Future<int> _countRows(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return rows.single['count'] as int;
}
