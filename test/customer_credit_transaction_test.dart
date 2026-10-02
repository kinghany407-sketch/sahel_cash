import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/models/invoice_item_model.dart';
import 'package:sahel_cash/models/invoice_model.dart';
import 'package:sahel_cash/models/receipt_voucher_model.dart';

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
  quantity REAL,
  storageUnit TEXT,
  conversionFactor REAL
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
    },
  );

  test(
    'receipt reduces balance and may be allocated to the customer invoice',
    () async {
      final invoiceId = await helper.createSalesInvoiceWithItems(
        invoice: _invoice(paymentMethod: 'credit', customerId: 1, total: 40),
        items: [_item(productId: 1, invoiceId: 0)],
        stockReductions: {1: 1},
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
      ),
    );

    expect(await _customerBalance(db), 10);
    final vouchers = await helper.getReceiptVouchersForCustomer(1);
    expect(vouchers.single['invoiceId'], isNull);
  });

  test('receipt cannot exceed customer balance', () async {
    await expectLater(
      helper.createReceiptVoucher(
        ReceiptVoucher(
          voucherNumber: '',
          customerId: 1,
          date: '2026-10-01',
          amount: 21,
          createdAt: '2026-10-01',
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
        stockReductions: {1: 1},
      );
      await helper.createReceiptVoucher(
        _voucher(invoiceId: invoiceId, amount: 15),
      );

      await expectLater(
        helper.deleteSalesInvoiceWithEffects(invoiceId),
        throwsA(isA<StateError>()),
      );

      expect(await _productQuantity(db), 9);
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

      await helper.deleteSalesInvoiceWithEffects(invoiceId);

      expect(await _productQuantity(db), 10);
      expect(await _customerBalance(db), 20);
      expect(await _countRows(db, 'invoices'), 0);
      expect(await _countRows(db, 'invoice_items'), 0);
    },
  );

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

InvoiceItem _item({required int productId, required int invoiceId}) {
  return InvoiceItem(
    invoiceId: invoiceId,
    productId: productId,
    productName: 'اختبار',
    saleUnit: 'قطعة',
    quantity: 2,
    unitPrice: 15,
    total: 30,
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
  );
}

Future<double> _productQuantity(Database db) async {
  return (await db.query('products')).single['quantity'] as double;
}

Future<double> _customerBalance(Database db) async {
  return (await db.query('customers')).single['currentBalance'] as double;
}

Future<int> _countRows(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return rows.single['count'] as int;
}
