import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Creates a completely isolated test database for conversionToStorage testing
/// Does NOT copy from production database
/// Creates schema manually using sqflite_common_ffi only (no Flutter imports)
void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Generate unique timestamp for isolation
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final testDb = 'C:\\Projects\\sahel_cash\\test_isolated_$timestamp.db';

  print('=== Creating isolated test database ===');
  print('Path: $testDb');
  print('Timestamp: $timestamp\n');

  // Create new empty database (no copy from production)
  final db = await openDatabase(
    testDb,
    version: 25,
    onCreate: (db, version) async {
      print('Creating fresh database schema at version $version');

      // Products table
      await db.execute('''
CREATE TABLE products(
id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT NOT NULL,
barcode TEXT,
category TEXT,
brand TEXT,
description TEXT,
imagePath TEXT,
buyPrice REAL DEFAULT 0,
sellPrice REAL DEFAULT 0,
quantity REAL DEFAULT 0,
purchaseUnit TEXT DEFAULT 'قطعة',
saleUnit TEXT DEFAULT 'قطعة',
storageUnit TEXT DEFAULT 'قطعة',
conversionFactor REAL DEFAULT 1,
unitsPerPurchaseUnit INTEGER DEFAULT 1,
supplier TEXT DEFAULT '',
unitsPerPackage INTEGER DEFAULT 1,
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
customerId INTEGER NULL,
notes TEXT NULL,
status TEXT NOT NULL DEFAULT 'posted',
cancelledAt TEXT NULL,
cancellationReason TEXT NULL,
cashierId INTEGER NULL,
cashierName TEXT NULL,
discount REAL DEFAULT 0.0,
discountType TEXT NULL,
paidAmount REAL DEFAULT 0.0,
changeAmount REAL DEFAULT 0.0
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

      // Customers table
      await db.execute('''
CREATE TABLE customers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  initialBalance REAL DEFAULT 0,
  currentBalance REAL DEFAULT 0,
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');

      // Suppliers table
      await db.execute('''
CREATE TABLE suppliers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  initialBalance REAL DEFAULT 0,
  currentBalance REAL DEFAULT 0,
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');

      // Purchase invoices table
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
  cancellationReason TEXT,
  FOREIGN KEY (supplierId) REFERENCES suppliers(id)
)
''');

      // Purchase invoice items table
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
  storageQuantity REAL NOT NULL DEFAULT 0,
  FOREIGN KEY (invoiceId) REFERENCES purchase_invoices(id),
  FOREIGN KEY (productId) REFERENCES products(id)
)
''');

      // Receipt vouchers table
      await db.execute('''
CREATE TABLE receipt_vouchers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  voucherNumber TEXT NOT NULL UNIQUE,
  customerId INTEGER NOT NULL,
  invoiceId INTEGER,
  date TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount > 0),
  paymentMethod TEXT NOT NULL DEFAULT 'cash',
  notes TEXT,
  createdAt TEXT NOT NULL,
  FOREIGN KEY (customerId) REFERENCES customers(id),
  FOREIGN KEY (invoiceId) REFERENCES invoices(id) ON DELETE SET NULL
)
''');

      // Expenses table
      await db.execute('''
CREATE TABLE expenses(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount > 0),
  date TEXT NOT NULL,
  notes TEXT,
  createdAt TEXT NOT NULL
)
''');

      // Users table
      await db.execute('''
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  fullName TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'cashier',
  canAccessReports INTEGER NOT NULL DEFAULT 0,
  canAccessProfits INTEGER NOT NULL DEFAULT 0,
  canAccessSettings INTEGER NOT NULL DEFAULT 0,
  canDiscount INTEGER NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');

      // Inventory movements table
      await db.execute('''
CREATE TABLE IF NOT EXISTS inventory_movements(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  productId INTEGER NOT NULL,
  warehouseId INTEGER,
  movementType TEXT NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('in', 'out')),
  quantity REAL NOT NULL CHECK(quantity > 0),
  storageUnit TEXT NOT NULL,
  unitCost REAL,
  totalCost REAL,
  costStatus TEXT NOT NULL DEFAULT 'unknown',
  sourceType TEXT NOT NULL,
  sourceDocumentId INTEGER,
  sourceLineId INTEGER,
  movementAt TEXT NOT NULL,
  recordedAt TEXT NOT NULL,
  createdByUserId INTEGER,
  reason TEXT,
  notes TEXT,
  reversalOfMovementId INTEGER,
  idempotencyKey TEXT NOT NULL UNIQUE,
  trackingStatus TEXT NOT NULL DEFAULT 'tracked'
)
''');

      // Customer account transactions table
      await db.execute('''
CREATE TABLE IF NOT EXISTS customer_account_transactions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customerId INTEGER NOT NULL,
  transactionType TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount != 0),
  sourceType TEXT NOT NULL,
  sourceDocumentId INTEGER,
  invoiceId INTEGER,
  occurredAt TEXT NOT NULL,
  recordedAt TEXT NOT NULL,
  reason TEXT,
  notes TEXT,
  reversalOfTransactionId INTEGER,
  idempotencyKey TEXT NOT NULL UNIQUE,
  FOREIGN KEY(customerId) REFERENCES customers(id)
)
''');

      print('✅ Schema created successfully');
    },
  );

  print('Database version: 25');

  // Insert test data for الشوال (Product ID 17)
  print('\n=== Inserting test data for الشوال ===');

  final productId = 17;
  final now = DateTime.now().toIso8601String();

  // Insert product
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
  print('✅ Product inserted: شوال (ID: $productId)');

  // Insert sale units
  await db.insert('product_sale_units', {
    'productId': productId,
    'saleUnit': 'كيلو',
    'retailPrice': 60.0,
    'wholesalePrice': null,
    'conversionToStorage': 1.0,
    'allowSellingByAmount': 1,
  });
  print('✅ Sale unit added: كيلو (conversionToStorage: 1.0)');

  await db.insert('product_sale_units', {
    'productId': productId,
    'saleUnit': 'قطعة ثقيلة',
    'retailPrice': 17.0,
    'wholesalePrice': null,
    'conversionToStorage': 0.2,
    'allowSellingByAmount': 0,
  });
  print('✅ Sale unit added: قطعة ثقيلة (conversionToStorage: 0.2)');

  await db.insert('product_sale_units', {
    'productId': productId,
    'saleUnit': 'قطعة خفيفة',
    'retailPrice': 15.0,
    'wholesalePrice': null,
    'conversionToStorage': 0.1666666667,
    'allowSellingByAmount': 0,
  });
  print('✅ Sale unit added: قطعة خفيفة (conversionToStorage: 0.1666666667)');

  await db.close();

  print('\n=== Test database ready ===');
  print('Path: $testDb');
  print('Schema: FULL (version 25 with all tables and columns)');
  print('Production database: NOT COPIED');
  print('Isolation: COMPLETE');
  print('\nUse this path in test scripts: $testDb');
}
