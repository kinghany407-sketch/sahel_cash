import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/product_model.dart';
import '../models/product_sale_unit_model.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

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
      version: 8,
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
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;

    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

    return List.generate(maps.length, (index) => ProductSaleUnit.fromMap(maps[index]));
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

    return await db.delete('product_sale_units', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSaleUnitsByProductId(int productId) async {
    final db = await database;

    return await db.delete('product_sale_units', where: 'productId = ?', whereArgs: [productId]);
  }
}
