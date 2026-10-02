import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/purchase_invoice_unit_helper.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';
import '../models/product_sale_unit_model.dart';
import '../models/receipt_voucher_model.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  @visibleForTesting
  static void setDatabaseForTesting(Database? testDatabase) {
    _database = testDatabase;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Use application documents directory for permanent storage
    final appDocDir = await getApplicationDocumentsDirectory();
    final newPath = join(appDocDir.path, 'sahel_cash.db');

    // Old path (inside .dart_tool - not safe)
    final oldPath = join(
      Directory.current.path,
      '.dart_tool',
      'sqflite_common_ffi',
      'databases',
      'sahel_cash.db',
    );

    // Check if old database exists and migrate it
    final oldFile = File(oldPath);
    final newFile = File(newPath);

    if (await oldFile.exists() && !await newFile.exists()) {
      // Copy old database to new permanent location
      try {
        await oldFile.copy(newPath);
      } catch (e) {
        // If migration fails, continue with new database
      }
    }

    return await openDatabase(
      newPath,
      version: 14,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE products(
id INTEGER PRIMARY KEY AUTOINCREMENT,
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
purchaseUnit TEXT,
saleUnit TEXT,
conversionFactor REAL,
unitsPerPurchaseUnit INTEGER,
unit TEXT,
unitsPerPackage INTEGER
)
''');

    await db.execute('''
CREATE TABLE product_sale_units(
id INTEGER PRIMARY KEY AUTOINCREMENT,
productId INTEGER NOT NULL,
saleUnit TEXT NOT NULL,
retailPrice REAL NOT NULL,
wholesalePrice REAL,
conversionToStorage REAL NOT NULL,
allowSellingByAmount INTEGER NOT NULL DEFAULT 0,
FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
UNIQUE(productId, saleUnit)
)
''');

    await db.execute('''
CREATE TABLE invoices(
id INTEGER PRIMARY KEY AUTOINCREMENT,
invoiceNumber TEXT UNIQUE NOT NULL,
date TEXT NOT NULL,
total REAL NOT NULL,
paymentMethod TEXT NOT NULL DEFAULT 'cash',
customerId INTEGER NULL,
notes TEXT NULL
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
isWholesale INTEGER NOT NULL DEFAULT 0,
FOREIGN KEY (invoiceId) REFERENCES invoices(id),
FOREIGN KEY (productId) REFERENCES products(id)
)
''');

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
  FOREIGN KEY (supplierId) REFERENCES suppliers(id)
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
  storageQuantity REAL NOT NULL DEFAULT 0,
  FOREIGN KEY (invoiceId) REFERENCES purchase_invoices(id),
  FOREIGN KEY (productId) REFERENCES products(id)
)
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE products ADD COLUMN category TEXT");
      await db.execute("ALTER TABLE products ADD COLUMN brand TEXT");
      await db.execute("ALTER TABLE products ADD COLUMN description TEXT");
      await db.execute("ALTER TABLE products ADD COLUMN imagePath TEXT");
      await db.execute("ALTER TABLE products ADD COLUMN unit TEXT");
      await db.execute(
        "ALTER TABLE products ADD COLUMN unitsPerPackage INTEGER DEFAULT 1",
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE products ADD COLUMN supplier TEXT DEFAULT ''",
      );
    }

    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE products ADD COLUMN purchaseUnit TEXT DEFAULT 'قطعة'",
      );
      await db.execute(
        "ALTER TABLE products ADD COLUMN saleUnit TEXT DEFAULT 'قطعة'",
      );
      await db.execute(
        "ALTER TABLE products ADD COLUMN conversionFactor REAL DEFAULT 1",
      );
    }

    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE products ADD COLUMN storageUnit TEXT DEFAULT 'قطعة'",
      );
    }

    if (oldVersion < 6) {
      await db.execute('''
CREATE TABLE product_sale_units(
id INTEGER PRIMARY KEY AUTOINCREMENT,
productId INTEGER NOT NULL,
saleUnit TEXT NOT NULL,
retailPrice REAL NOT NULL,
wholesalePrice REAL,
conversionToStorage REAL NOT NULL,
allowSellingByAmount INTEGER NOT NULL DEFAULT 0,
FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
UNIQUE(productId, saleUnit)
)
''');
    }

    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE products ADD COLUMN unitsPerPurchaseUnit INTEGER DEFAULT 1",
      );
    }

    if (oldVersion < 8) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS invoices(
id INTEGER PRIMARY KEY AUTOINCREMENT,
invoiceNumber TEXT UNIQUE NOT NULL,
date TEXT NOT NULL,
total REAL NOT NULL,
paymentMethod TEXT NOT NULL DEFAULT 'cash',
customerId INTEGER NULL,
notes TEXT NULL
)
''');

      await db.execute('''
CREATE TABLE IF NOT EXISTS invoice_items(
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
    }

    if (oldVersion < 9) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS customers(
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
    }

    if (oldVersion < 10) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS suppliers(
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
    }

    if (oldVersion < 11) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS purchase_invoices(
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
  FOREIGN KEY (supplierId) REFERENCES suppliers(id)
)
''');

      await db.execute('''
CREATE TABLE IF NOT EXISTS purchase_invoice_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoiceId INTEGER NOT NULL,
  productId INTEGER NOT NULL,
  quantity REAL NOT NULL DEFAULT 0,
  unitPrice REAL NOT NULL DEFAULT 0,
  total REAL NOT NULL DEFAULT 0,
  FOREIGN KEY (invoiceId) REFERENCES purchase_invoices(id),
  FOREIGN KEY (productId) REFERENCES products(id)
)
''');
    }

    if (oldVersion < 12) {
      await db.execute(
        "ALTER TABLE purchase_invoice_items ADD COLUMN purchaseUnit TEXT NOT NULL DEFAULT 'قطعة'",
      );
      await db.execute(
        'ALTER TABLE purchase_invoice_items ADD COLUMN conversionFactor REAL NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE purchase_invoice_items ADD COLUMN storageQuantity REAL NOT NULL DEFAULT 0',
      );
      await db.execute('''
UPDATE purchase_invoice_items
SET storageQuantity = quantity
''');
    }

    if (oldVersion < 13) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS receipt_vouchers(
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
    }

    if (oldVersion < 14) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS expenses(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount > 0),
  date TEXT NOT NULL,
  notes TEXT,
  createdAt TEXT NOT NULL
)
''');
    }
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;

    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> createExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return db.insert('expenses', expense);
  }

  Future<int> updateExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return db.update(
      'expenses',
      expense,
      where: 'id = ?',
      whereArgs: [expense['id']],
    );
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return db.query('expenses', orderBy: 'date DESC, id DESC');
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getProducts() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      orderBy: 'id DESC',
    );

    return List.generate(maps.length, (index) => Product.fromMap(maps[index]));
  }

  Future<List<Product>> searchProducts({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;

    List<Map<String, dynamic>> maps;

    if (query == null || query.isEmpty) {
      return [];
    }

    final normalizedQuery = '%${query.toLowerCase()}%';

    maps = await db.query(
      'products',
      where: '''
        LOWER(name) LIKE ? 
        OR LOWER(sku) LIKE ? 
        OR LOWER(barcode) LIKE ?
      ''',
      whereArgs: [normalizedQuery, normalizedQuery, normalizedQuery],
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (index) => Product.fromMap(maps[index]));
  }

  Future<List<Product>> getProductsWithImages({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'imagePath IS NOT NULL AND LENGTH(TRIM(imagePath)) > 0',
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (index) => Product.fromMap(maps[index]));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;

    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;

    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearProducts() async {
    final db = await database;

    await db.delete('products');
  }

  // Backup function to create a copy of the database
  Future<String> backupDatabase() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dbPath = join(appDocDir.path, 'sahel_cash.db');

    final sourceFile = File(dbPath);
    if (!await sourceFile.exists()) {
      throw Exception('Database file not found');
    }

    // Create backup with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = join(appDocDir.path, 'sahel_cash_backup_$timestamp.db');

    await sourceFile.copy(backupPath);

    return backupPath;
  }

  // Product Sale Units CRUD operations

  Future<int> insertSaleUnit(ProductSaleUnit saleUnit) async {
    final db = await database;

    return await db.insert(
      'product_sale_units',
      saleUnit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ProductSaleUnit>> getSaleUnits(int productId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'product_sale_units',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );

    return List.generate(
      maps.length,
      (index) => ProductSaleUnit.fromMap(maps[index]),
    );
  }

  Future<int> updateSaleUnit(ProductSaleUnit saleUnit) async {
    final db = await database;

    return await db.update(
      'product_sale_units',
      saleUnit.toMap(),
      where: 'id = ?',
      whereArgs: [saleUnit.id],
    );
  }

  Future<int> deleteSaleUnit(int id) async {
    final db = await database;

    return await db.delete(
      'product_sale_units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSaleUnitsByProductId(int productId) async {
    final db = await database;

    return await db.delete(
      'product_sale_units',
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  // Customer CRUD operations

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;

    return await db.insert(
      'customers',
      customer,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;

    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final db = await database;

    final normalizedQuery = '%${query.toLowerCase()}%';

    return await db.query(
      'customers',
      where: '''
        LOWER(name) LIKE ? 
        OR LOWER(phone) LIKE ?
      ''',
      whereArgs: [normalizedQuery, normalizedQuery],
      orderBy: 'name ASC',
    );
  }

  Future<int> updateCustomer(Map<String, dynamic> customer) async {
    final db = await database;

    return await db.update(
      'customers',
      customer,
      where: 'id = ?',
      whereArgs: [customer['id']],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;

    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCustomerBalance(int customerId, double amount) async {
    final db = await database;

    return await db.rawUpdate(
      'UPDATE customers SET currentBalance = COALESCE(currentBalance, 0) + ?, updatedAt = ? WHERE id = ?',
      [amount, DateTime.now().toIso8601String(), customerId],
    );
  }

  Future<int> createSalesInvoiceWithItems({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required Map<int, double> stockReductions,
  }) async {
    if (items.isEmpty) throw ArgumentError('Invoice must contain items');
    if (invoice.paymentMethod == 'credit' && invoice.customerId == null) {
      throw ArgumentError('Credit invoices require a customer');
    }
    if (invoice.paymentMethod != 'cash' && invoice.paymentMethod != 'credit') {
      throw ArgumentError('Unsupported invoice payment method');
    }

    final db = await database;
    return db.transaction((txn) async {
      if (invoice.customerId != null) {
        final customers = await txn.query(
          'customers',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [invoice.customerId],
          limit: 1,
        );
        if (customers.isEmpty) {
          throw StateError('Customer ${invoice.customerId} not found');
        }
      }

      for (final entry in stockReductions.entries) {
        if (entry.value <= 0) {
          throw StateError('Invalid stock reduction for product ${entry.key}');
        }
        final updated = await txn.rawUpdate(
          'UPDATE products SET quantity = COALESCE(quantity, 0) - ? WHERE id = ? AND COALESCE(quantity, 0) >= ?',
          [entry.value, entry.key, entry.value],
        );
        if (updated != 1) {
          throw StateError(
            'Insufficient stock or missing product ${entry.key}',
          );
        }
      }

      final invoiceId = await txn.insert('invoices', invoice.toMap());
      for (final item in items) {
        await txn.insert('invoice_items', {
          ...item.toMap(),
          'invoiceId': invoiceId,
        });
      }

      if (invoice.paymentMethod == 'credit') {
        final updated = await txn.rawUpdate(
          'UPDATE customers SET currentBalance = COALESCE(currentBalance, 0) + ?, updatedAt = ? WHERE id = ?',
          [invoice.total, DateTime.now().toIso8601String(), invoice.customerId],
        );
        if (updated != 1) {
          throw StateError('Customer ${invoice.customerId} not found');
        }
      }

      return invoiceId;
    });
  }

  Future<int> createReceiptVoucher(ReceiptVoucher voucher) async {
    if (voucher.amount <= 0) {
      throw ArgumentError('Receipt amount must be greater than zero');
    }

    final db = await database;
    return db.transaction((txn) async {
      final customers = await txn.query(
        'customers',
        columns: ['currentBalance'],
        where: 'id = ?',
        whereArgs: [voucher.customerId],
        limit: 1,
      );
      if (customers.isEmpty) {
        throw StateError('Customer ${voucher.customerId} not found');
      }
      final currentBalance =
          (customers.first['currentBalance'] as num?)?.toDouble() ?? 0;
      if (voucher.amount > currentBalance) {
        throw StateError('Receipt amount exceeds customer balance');
      }

      if (voucher.invoiceId != null) {
        final invoices = await txn.query(
          'invoices',
          columns: ['total', 'customerId', 'paymentMethod'],
          where: 'id = ?',
          whereArgs: [voucher.invoiceId],
          limit: 1,
        );
        if (invoices.isEmpty ||
            invoices.first['customerId'] != voucher.customerId ||
            invoices.first['paymentMethod'] != 'credit') {
          throw StateError('Receipt invoice does not belong to this customer');
        }
        final allocated = await txn.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) AS amount FROM receipt_vouchers WHERE invoiceId = ?',
          [voucher.invoiceId],
        );
        final alreadyReceived =
            (allocated.first['amount'] as num?)?.toDouble() ?? 0;
        final invoiceTotal = (invoices.first['total'] as num?)?.toDouble() ?? 0;
        if (alreadyReceived + voucher.amount > invoiceTotal) {
          throw StateError('Receipt amount exceeds invoice balance');
        }
      }

      final sequence = await txn.rawQuery('''
SELECT COALESCE((SELECT seq FROM sqlite_sequence WHERE name = 'receipt_vouchers'), 0) + 1 AS nextNumber
''');
      final nextNumber = (sequence.first['nextNumber'] as int?) ?? 1;
      final voucherNumber = 'REC-${nextNumber.toString().padLeft(4, '0')}';
      final voucherId = await txn.insert('receipt_vouchers', {
        ...voucher.toMap(),
        'voucherNumber': voucherNumber,
      });

      final updated = await txn.rawUpdate(
        'UPDATE customers SET currentBalance = COALESCE(currentBalance, 0) - ?, updatedAt = ? WHERE id = ? AND COALESCE(currentBalance, 0) >= ?',
        [
          voucher.amount,
          DateTime.now().toIso8601String(),
          voucher.customerId,
          voucher.amount,
        ],
      );
      if (updated != 1) {
        throw StateError('Customer balance changed before receipt was saved');
      }
      return voucherId;
    });
  }

  Future<void> deleteSalesInvoiceWithEffects(int invoiceId) async {
    final db = await database;
    await db.transaction((txn) async {
      final invoices = await txn.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (invoices.isEmpty) return;
      final invoice = invoices.first;

      if (invoice['paymentMethod'] == 'credit') {
        final linkedReceipts = await txn.query(
          'receipt_vouchers',
          columns: ['id'],
          where: 'invoiceId = ?',
          whereArgs: [invoiceId],
          limit: 1,
        );
        if (linkedReceipts.isNotEmpty) {
          throw StateError('Invoice has linked receipt vouchers');
        }
        final customerId = invoice['customerId'] as int?;
        if (customerId == null) {
          throw StateError('Credit invoice has no customer');
        }
        final balances = await txn.query(
          'customers',
          columns: ['currentBalance'],
          where: 'id = ?',
          whereArgs: [customerId],
          limit: 1,
        );
        final balance = balances.isEmpty
            ? 0.0
            : (balances.first['currentBalance'] as num?)?.toDouble() ?? 0;
        final invoiceTotal = (invoice['total'] as num?)?.toDouble() ?? 0;
        if (balance < invoiceTotal) {
          throw StateError(
            'Cannot remove invoice because customer payments must be resolved first',
          );
        }
      }

      final items = await txn.query(
        'invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [invoiceId],
      );
      for (final item in items) {
        final productId = item['productId'] as int;
        final products = await txn.query(
          'products',
          columns: ['storageUnit', 'conversionFactor'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (products.isEmpty) {
          throw StateError(
            'Product $productId not found while restoring stock',
          );
        }
        final product = products.first;
        final storageUnit = (product['storageUnit'] as String? ?? '')
            .trim()
            .toLowerCase();
        final saleUnit = (item['saleUnit'] as String? ?? '')
            .trim()
            .toLowerCase();
        var conversionToStorage = 1.0;
        if (saleUnit != storageUnit) {
          final saleUnits = await txn.query(
            'product_sale_units',
            columns: ['conversionToStorage'],
            where: 'productId = ? AND LOWER(TRIM(saleUnit)) = ?',
            whereArgs: [productId, saleUnit],
            limit: 1,
          );
          if (saleUnits.isNotEmpty) {
            conversionToStorage =
                (saleUnits.first['conversionToStorage'] as num).toDouble();
          } else {
            conversionToStorage =
                (product['conversionFactor'] as num?)?.toDouble() ?? 1;
          }
        }
        final restoredQuantity =
            (item['quantity'] as num).toDouble() * conversionToStorage;
        await txn.rawUpdate(
          'UPDATE products SET quantity = COALESCE(quantity, 0) + ? WHERE id = ?',
          [restoredQuantity, productId],
        );
      }

      if (invoice['paymentMethod'] == 'credit') {
        final customerId = invoice['customerId'] as int;
        final invoiceTotal = (invoice['total'] as num?)?.toDouble() ?? 0;
        await txn.rawUpdate(
          'UPDATE customers SET currentBalance = COALESCE(currentBalance, 0) - ?, updatedAt = ? WHERE id = ?',
          [invoiceTotal, DateTime.now().toIso8601String(), customerId],
        );
      }

      await txn.delete(
        'invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [invoiceId],
      );
      await txn.delete('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    });
  }

  Future<List<Map<String, dynamic>>> getReceiptVouchersForCustomer(
    int customerId,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
SELECT rv.*, i.invoiceNumber
FROM receipt_vouchers rv
LEFT JOIN invoices i ON i.id = rv.invoiceId
WHERE rv.customerId = ?
ORDER BY rv.date DESC, rv.id DESC
''',
      [customerId],
    );
  }

  // Supplier CRUD operations

  Future<int> insertSupplier(Map<String, dynamic> supplier) async {
    final db = await database;

    return await db.insert(
      'suppliers',
      supplier,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await database;

    return await db.query('suppliers', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getSupplierById(int id) async {
    final db = await database;
    final maps = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> searchSuppliers(String query) async {
    final db = await database;
    final normalizedQuery = '%${query.toLowerCase()}%';

    return await db.query(
      'suppliers',
      where: 'LOWER(name) LIKE ? OR LOWER(phone) LIKE ?',
      whereArgs: [normalizedQuery, normalizedQuery],
      orderBy: 'name ASC',
    );
  }

  Future<int> updateSupplier(Map<String, dynamic> supplier) async {
    final db = await database;

    return await db.update(
      'suppliers',
      supplier,
      where: 'id = ?',
      whereArgs: [supplier['id']],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;

    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getNextPurchaseInvoiceNumber() async {
    final db = await database;
    final result = await db.rawQuery('''
SELECT COALESCE((SELECT seq FROM sqlite_sequence WHERE name = 'purchase_invoices'), 0) + 1 AS nextNumber
''');
    final nextNumber = (result.first['nextNumber'] as int?) ?? 1;
    return 'PUR-${nextNumber.toString().padLeft(4, '0')}';
  }

  Future<int> createPurchaseInvoice(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;

    return db.transaction((txn) async {
      final sequenceResult = await txn.rawQuery('''
SELECT COALESCE((SELECT seq FROM sqlite_sequence WHERE name = 'purchase_invoices'), 0) + 1 AS nextNumber
''');
      final nextNumber = (sequenceResult.first['nextNumber'] as int?) ?? 1;
      final invoiceNumber = 'PUR-${nextNumber.toString().padLeft(4, '0')}';
      final invoiceId = await txn.insert('purchase_invoices', {
        ...invoice,
        'invoiceNumber': invoiceNumber,
      });

      for (final item in items) {
        final products = await txn.query(
          'products',
          columns: ['purchaseUnit', 'storageUnit', 'unitsPerPurchaseUnit'],
          where: 'id = ?',
          whereArgs: [item['productId']],
          limit: 1,
        );
        if (products.isEmpty) {
          throw StateError('Product ${item['productId']} not found');
        }
        final product = products.first;
        final productPurchaseUnit =
            product['purchaseUnit'] as String? ?? 'قطعة';
        final productStorageUnit =
            product['storageUnit'] as String? ?? productPurchaseUnit;
        final selectedUnit =
            item['purchaseUnit'] as String? ?? productPurchaseUnit;
        final unitsPerPurchaseUnit =
            (product['unitsPerPurchaseUnit'] as num?)?.toDouble() ?? 1;
        final double conversionFactor;
        try {
          conversionFactor =
              PurchaseInvoiceUnitHelper.conversionFactorToStorage(
                invoiceUnit: selectedUnit,
                purchaseUnit: productPurchaseUnit,
                storageUnit: productStorageUnit,
                unitsPerPurchaseUnit: unitsPerPurchaseUnit,
              );
        } on ArgumentError {
          throw StateError(
            'Invoice unit $selectedUnit is invalid for product ${item['productId']}',
          );
        }
        final storageQuantity =
            (item['quantity'] as num).toDouble() * conversionFactor;

        await txn.insert('purchase_invoice_items', {
          ...item,
          'invoiceId': invoiceId,
          'purchaseUnit': selectedUnit,
          'conversionFactor': conversionFactor,
          'storageQuantity': storageQuantity,
        });
        final changedProducts = await txn.rawUpdate(
          'UPDATE products SET quantity = COALESCE(quantity, 0) + ? WHERE id = ?',
          [storageQuantity, item['productId']],
        );
        if (changedProducts == 0) {
          throw StateError('Product ${item['productId']} not found');
        }
      }

      if (invoice['paymentType'] == 'credit') {
        final changedSuppliers = await txn.rawUpdate(
          'UPDATE suppliers SET currentBalance = COALESCE(currentBalance, 0) + ?, updatedAt = ? WHERE id = ?',
          [invoice['totalAmount'], invoice['updatedAt'], invoice['supplierId']],
        );
        if (changedSuppliers == 0) {
          throw StateError('Supplier ${invoice['supplierId']} not found');
        }
      }

      return invoiceId;
    });
  }

  Future<List<Map<String, dynamic>>> getPurchaseInvoices({
    String? query,
    int? supplierId,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final arguments = <Object>[];

    if (query != null && query.isNotEmpty) {
      conditions.add(
        '(LOWER(pi.invoiceNumber) LIKE ? OR LOWER(s.name) LIKE ?)',
      );
      final normalizedQuery = '%${query.toLowerCase()}%';
      arguments
        ..add(normalizedQuery)
        ..add(normalizedQuery);
    }
    if (supplierId != null) {
      conditions.add('pi.supplierId = ?');
      arguments.add(supplierId);
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('''
SELECT pi.*, s.name AS supplierName
FROM purchase_invoices pi
LEFT JOIN suppliers s ON s.id = pi.supplierId
$whereClause
ORDER BY pi.id DESC
''', arguments);
  }

  Future<Map<String, dynamic>?> getPurchaseInvoice(int id) async {
    final db = await database;
    final invoices = await db.rawQuery(
      '''
SELECT pi.*, s.name AS supplierName
FROM purchase_invoices pi
LEFT JOIN suppliers s ON s.id = pi.supplierId
WHERE pi.id = ?
LIMIT 1
''',
      [id],
    );
    if (invoices.isEmpty) return null;

    final items = await db.rawQuery(
      '''
SELECT pii.*, p.name AS productName
FROM purchase_invoice_items pii
LEFT JOIN products p ON p.id = pii.productId
WHERE pii.invoiceId = ?
ORDER BY pii.id ASC
''',
      [id],
    );
    return {...invoices.first, 'items': items};
  }

  Future<int> deletePurchaseInvoice(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      final invoices = await txn.query(
        'purchase_invoices',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (invoices.isEmpty) return 0;

      final invoice = invoices.first;
      final items = await txn.query(
        'purchase_invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [id],
      );
      for (final item in items) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = COALESCE(quantity, 0) - ? WHERE id = ?',
          [item['storageQuantity'] ?? item['quantity'], item['productId']],
        );
      }

      if (invoice['paymentType'] == 'credit') {
        await txn.rawUpdate(
          'UPDATE suppliers SET currentBalance = COALESCE(currentBalance, 0) - ?, updatedAt = ? WHERE id = ?',
          [
            invoice['totalAmount'],
            DateTime.now().toIso8601String(),
            invoice['supplierId'],
          ],
        );
      }

      await txn.delete(
        'purchase_invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [id],
      );
      return txn.delete('purchase_invoices', where: 'id = ?', whereArgs: [id]);
    });
  }
}
