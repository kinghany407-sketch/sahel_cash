import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:win32/win32.dart';

import '../helpers/purchase_invoice_unit_helper.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/inventory_movement_model.dart';
import '../models/product_model.dart';
import '../models/product_sale_unit_model.dart';
import '../models/receipt_voucher_model.dart';
import '../utils/stock_quantity_converter.dart';
import '../utils/unit_name_normalizer.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const int currentDatabaseVersion = 26;

  static Database? _database;
  static String? _databasePathForTesting;
  @visibleForTesting
  static Future<void> Function()? beforeRestoreReplaceForTesting;
  @visibleForTesting
  static Future<void> Function()? afterRestoreReplaceForTesting;
  static bool _maintenanceInProgress = false;
  static int _temporaryFileCounter = 0;

  @visibleForTesting
  static void setDatabaseForTesting(Database? testDatabase) {
    _database = testDatabase;
  }

  @visibleForTesting
  static void setDatabasePathForTesting(String? path) {
    _databasePathForTesting = path;
  }

  Future<Database> get database async {
    if (_maintenanceInProgress) {
      throw StateError('Database maintenance is in progress');
    }
    if (_database != null) return _database!;

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final newPath = await getDatabasePath();

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

    final db = await openDatabase(
      newPath,
      version: currentDatabaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureUsersTable(db);
    return db;
  }

  Future<String> getDatabasePath() async {
    if (_databasePathForTesting != null) {
      return _databasePathForTesting!;
    }
    final testPath = Platform.environment['SAHEL_CASH_DB_PATH'];
    if (testPath != null && testPath.trim().isNotEmpty) {
      return testPath;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    return join(appDocDir.path, 'sahel_cash.db');
  }

  static Future<void> createEmptyDistributionDatabase(String path) async {
    final output = File(path).absolute;
    _reserveNewDistributionFile(output.path);

    final db = await openDatabase(
      output.path,
      version: currentDatabaseVersion,
      onCreate: instance._onCreate,
      singleInstance: false,
    );
    try {
      final version = await db.rawQuery('PRAGMA user_version');
      if ((version.single['user_version'] as num).toInt() !=
          currentDatabaseVersion) {
        throw StateError('Distribution database was not created at version 25');
      }
    } finally {
      await db.close();
    }
  }

  static void _reserveNewDistributionFile(String path) {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Exclusive distribution database creation is supported on Windows',
      );
    }

    final nativePath = path.toNativeUtf16();
    try {
      final handle = CreateFile(
        nativePath,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        CREATE_NEW,
        FILE_ATTRIBUTE_NORMAL,
        0,
      );
      if (handle == INVALID_HANDLE_VALUE) {
        final errorCode = GetLastError();
        throw FileSystemException(
          'Unable to reserve distribution database path (Windows error $errorCode)',
          path,
        );
      }
      if (CloseHandle(handle) == 0) {
        final errorCode = GetLastError();
        throw FileSystemException(
          'Unable to close distribution database reservation (Windows error $errorCode)',
          path,
        );
      }
    } finally {
      calloc.free(nativePath);
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<String> backupDatabase({String? destinationPath}) async {
    if (_maintenanceInProgress) {
      throw StateError('Database maintenance is in progress');
    }

    final sourcePath = await getDatabasePath();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Database file not found', sourcePath);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final output = File(
      destinationPath ??
          join(sourceFile.parent.path, 'sahel_cash_backup_$timestamp.db'),
    ).absolute;
    if (_pathsAreEqual(sourceFile.path, output.path)) {
      throw ArgumentError(
        'Backup destination must differ from the live database',
      );
    }
    if (await output.exists()) {
      throw FileSystemException(
        'Backup destination already exists',
        output.path,
      );
    }
    if (!await output.parent.exists()) {
      throw FileSystemException(
        'Backup destination directory does not exist',
        output.parent.path,
      );
    }

    final temporary = File(_temporaryFilePath(output.path, 'backup'));
    try {
      final db = await database;
      await db.execute('VACUUM INTO ?', [temporary.path]);
      await _validateDatabaseFile(
        temporary.path,
        expectedVersion: currentDatabaseVersion,
      );
      if (await output.exists()) {
        throw FileSystemException(
          'Backup destination already exists',
          output.path,
        );
      }
      await temporary.rename(output.path);
      return output.path;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<String> restoreDatabase(String selectedBackupPath) async {
    final databasePath = File(await getDatabasePath()).absolute.path;
    final selectedFile = File(selectedBackupPath).absolute;
    if (_pathsAreEqual(databasePath, selectedFile.path)) {
      throw ArgumentError('Cannot restore the live database from itself');
    }
    if (!await selectedFile.exists()) {
      throw FileSystemException(
        'Selected backup file does not exist',
        selectedFile.path,
      );
    }

    final stagedFile = File(_temporaryFilePath(databasePath, 'restore'));
    final safetyFile = File(_safetyBackupFilePath(databasePath));
    var maintenanceStarted = false;
    var databaseReplaced = false;

    try {
      await selectedFile.copy(stagedFile.path);
      await _validateDatabaseFile(
        stagedFile.path,
        expectedVersion: currentDatabaseVersion,
      );

      if (_maintenanceInProgress) {
        throw StateError('Another database maintenance operation is active');
      }
      _maintenanceInProgress = true;
      maintenanceStarted = true;

      final currentDatabase = _database ?? await _initDatabase();
      _database = currentDatabase;
      await currentDatabase.transaction<void>((_) async {}, exclusive: true);
      await currentDatabase.execute('VACUUM INTO ?', [safetyFile.path]);
      await _validateDatabaseFile(
        safetyFile.path,
        expectedVersion: currentDatabaseVersion,
      );

      await currentDatabase.close();
      _database = null;

      await beforeRestoreReplaceForTesting?.call();
      await _replaceFileAtomically(stagedFile, File(databasePath));
      databaseReplaced = true;
      await afterRestoreReplaceForTesting?.call();
      await _validateDatabaseFile(
        databasePath,
        expectedVersion: currentDatabaseVersion,
      );
      return safetyFile.path;
    } catch (error) {
      if (databaseReplaced && await safetyFile.exists()) {
        final rollbackFile = File(_temporaryFilePath(databasePath, 'rollback'));
        try {
          await safetyFile.copy(rollbackFile.path);
          await _replaceFileAtomically(rollbackFile, File(databasePath));
        } catch (rollbackError) {
          throw StateError(
            'Restore failed ($error), and restoring the safety copy failed '
            '($rollbackError). Safety copy: ${safetyFile.path}',
          );
        } finally {
          if (await rollbackFile.exists()) {
            await rollbackFile.delete();
          }
        }
      }
      rethrow;
    } finally {
      if (maintenanceStarted) _maintenanceInProgress = false;
      if (await stagedFile.exists()) {
        await stagedFile.delete();
      }
    }
  }

  static Future<void> _validateDatabaseFile(
    String path, {
    required int expectedVersion,
  }) async {
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw FormatException('Database file is empty or missing', path);
    }

    Database? validationDatabase;
    try {
      validationDatabase = await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
      );
      final versionRows = await validationDatabase.rawQuery(
        'PRAGMA user_version',
      );
      final version = (versionRows.single['user_version'] as num).toInt();
      if (version != expectedVersion) {
        throw FormatException(
          'Database version $version is incompatible; expected $expectedVersion',
          path,
        );
      }

      final integrityRows = await validationDatabase.rawQuery(
        'PRAGMA integrity_check',
      );
      if (integrityRows.length != 1 ||
          integrityRows.single.values.single != 'ok') {
        throw FormatException('SQLite integrity check failed', path);
      }
    } finally {
      await validationDatabase?.close();
    }
  }

  static String _temporaryFilePath(String targetPath, String purpose) {
    final target = File(targetPath).absolute;
    while (true) {
      final sequence = _temporaryFileCounter++;
      final candidate = File(
        join(
          target.parent.path,
          '.${basename(target.path)}.$purpose.'
          '${DateTime.now().microsecondsSinceEpoch}.$sequence.tmp',
        ),
      );
      if (!candidate.existsSync()) return candidate.path;
    }
  }

  static String _safetyBackupFilePath(String databasePath) {
    final databaseFile = File(databasePath).absolute;
    while (true) {
      final sequence = _temporaryFileCounter++;
      final candidate = File(
        join(
          databaseFile.parent.path,
          'sahel_cash_before-restore_'
          '${DateTime.now().microsecondsSinceEpoch}.$sequence.db',
        ),
      );
      if (!candidate.existsSync()) return candidate.path;
    }
  }

  static bool _pathsAreEqual(String first, String second) {
    final normalizedFirst = normalize(File(first).absolute.path);
    final normalizedSecond = normalize(File(second).absolute.path);
    return Platform.isWindows
        ? normalizedFirst.toLowerCase() == normalizedSecond.toLowerCase()
        : normalizedFirst == normalizedSecond;
  }

  static Future<void> _replaceFileAtomically(
    File source,
    File destination,
  ) async {
    if (Platform.isWindows) {
      final nativeSource = source.absolute.path.toNativeUtf16();
      final nativeDestination = destination.absolute.path.toNativeUtf16();
      try {
        final moved = MoveFileEx(
          nativeSource,
          nativeDestination,
          MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
        );
        if (moved == 0) {
          final errorCode = GetLastError();
          throw FileSystemException(
            'Atomic database replacement failed (Windows error $errorCode)',
            '${source.path} -> ${destination.path}',
          );
        }
      } finally {
        calloc
          ..free(nativeSource)
          ..free(nativeDestination);
      }
      return;
    }

    await source.rename(destination.path);
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
unitsPerPackage INTEGER,
isActive INTEGER NOT NULL DEFAULT 1
)
''');

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
cancellationReason TEXT NULL
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
  status TEXT NOT NULL DEFAULT 'posted',
  cancelledAt TEXT,
  cancellationReason TEXT,
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

    await createInventoryMovementsTable(db);
    await createCustomerAccountTransactionsTable(db);
    await _ensureUsersTable(db);
    await migrateUnitMasterTable(db);
  }

  @visibleForTesting
  static Future<void> createInventoryMovementsTable(DatabaseExecutor db) async {
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
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_movements_reversal_once
ON inventory_movements(reversalOfMovementId)
WHERE reversalOfMovementId IS NOT NULL
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_date
ON inventory_movements(productId, movementAt, id)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_inventory_movements_source
ON inventory_movements(sourceType, sourceDocumentId, sourceLineId)
''');
  }

  @visibleForTesting
  static Future<void> createCustomerAccountTransactionsTable(
    DatabaseExecutor db,
  ) async {
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
    await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_transactions_reversal_once
ON customer_account_transactions(reversalOfTransactionId)
WHERE reversalOfTransactionId IS NOT NULL
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_customer_transactions_customer_date
ON customer_account_transactions(customerId, occurredAt, id)
''');
    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_customer_transactions_source
ON customer_account_transactions(sourceType, sourceDocumentId)
''');
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final result = await db.rawQuery("PRAGMA table_info($table)");
    for (final row in result) {
      if (row['name'] == column) {
        return true;
      }
    }
    return false;
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    if (await _columnExists(db, table, column)) {
      return; // Column already exists, skip
    }
    await db.execute("ALTER TABLE $table ADD COLUMN $column $definition");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _safeAddColumn(db, 'products', 'category', 'TEXT');
      await _safeAddColumn(db, 'products', 'brand', 'TEXT');
      await _safeAddColumn(db, 'products', 'description', 'TEXT');
      await _safeAddColumn(db, 'products', 'imagePath', 'TEXT');
      await _safeAddColumn(db, 'products', 'unit', 'TEXT');
      await _safeAddColumn(
        db,
        'products',
        'unitsPerPackage',
        'INTEGER DEFAULT 1',
      );
    }

    if (oldVersion < 3) {
      await _safeAddColumn(db, 'products', 'supplier', "TEXT DEFAULT ''");
    }

    if (oldVersion < 4) {
      await _safeAddColumn(
        db,
        'products',
        'purchaseUnit',
        "TEXT DEFAULT 'قطعة'",
      );
      await _safeAddColumn(db, 'products', 'saleUnit', "TEXT DEFAULT 'قطعة'");
      await _safeAddColumn(
        db,
        'products',
        'conversionFactor',
        'REAL DEFAULT 1',
      );
    }

    if (oldVersion < 5) {
      await _safeAddColumn(
        db,
        'products',
        'storageUnit',
        "TEXT DEFAULT 'قطعة'",
      );
    }

    if (oldVersion < 6) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS product_sale_units(
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
    }

    if (oldVersion < 7) {
      await _safeAddColumn(
        db,
        'products',
        'unitsPerPurchaseUnit',
        'INTEGER DEFAULT 1',
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
      await _safeAddColumn(
        db,
        'purchase_invoice_items',
        'purchaseUnit',
        "TEXT NOT NULL DEFAULT 'قطعة'",
      );
      await _safeAddColumn(
        db,
        'purchase_invoice_items',
        'conversionFactor',
        'REAL NOT NULL DEFAULT 1',
      );
      await _safeAddColumn(
        db,
        'purchase_invoice_items',
        'storageQuantity',
        'REAL NOT NULL DEFAULT 0',
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

    if (oldVersion < 15) {
      await _safeAddColumn(db, 'invoices', 'cashierId', 'INTEGER NULL');
      await _safeAddColumn(db, 'invoices', 'cashierName', 'TEXT NULL');
    }

    if (oldVersion < 16) {
      await _safeAddColumn(db, 'invoices', 'discount', 'REAL DEFAULT 0.0');
      await _safeAddColumn(db, 'invoices', 'discountType', 'TEXT NULL');
    }

    if (oldVersion < 17) {
      await _safeAddColumn(db, 'invoices', 'paidAmount', 'REAL DEFAULT 0.0');
      await _safeAddColumn(db, 'invoices', 'changeAmount', 'REAL DEFAULT 0.0');
    }

    if (oldVersion < 19) {
      await _ensureUsersTable(db);
    }

    if (oldVersion < 20) {
      await _safeAddColumn(
        db,
        'users',
        'canAccessReports',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _safeAddColumn(
        db,
        'users',
        'canAccessProfits',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _safeAddColumn(
        db,
        'users',
        'canAccessSettings',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _safeAddColumn(
        db,
        'users',
        'canDiscount',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (oldVersion < 21) {
      await migrateSaleUnitRetailPrice(db);
    }

    if (oldVersion < 22) {
      await migrateUnitMasterTable(db);
    }

    if (oldVersion < 23) {
      await _safeAddColumn(
        db,
        'invoice_items',
        'conversionToStorage',
        'REAL DEFAULT NULL',
      );
    }

    if (oldVersion < 24) {
      for (final table in ['invoices', 'purchase_invoices']) {
        await _safeAddColumn(
          db,
          table,
          'status',
          "TEXT NOT NULL DEFAULT 'posted'",
        );
        await _safeAddColumn(db, table, 'cancelledAt', 'TEXT');
        await _safeAddColumn(db, table, 'cancellationReason', 'TEXT');
      }
    }

    if (oldVersion < 25) {
      await migrateCustomerAccountLedger(db);
    }
  }

  @visibleForTesting
  Future<void> onUpgradeForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) => _onUpgrade(db, oldVersion, newVersion);

  @visibleForTesting
  static Future<void> migrateCustomerAccountLedger(DatabaseExecutor db) async {
    final productColumns = await db.rawQuery('PRAGMA table_info(products)');
    if (!productColumns.any((column) => column['name'] == 'isActive')) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1',
      );
    }
    await createCustomerAccountTransactionsTable(db);
    await seedLegacyCustomerAccountBalances(db);
  }

  @visibleForTesting
  static Future<void> seedLegacyCustomerAccountBalances(
    DatabaseExecutor db,
  ) async {
    final now = DateTime.now().toIso8601String();
    await db.rawInsert(
      '''
INSERT OR IGNORE INTO customer_account_transactions(
  customerId, transactionType, amount, sourceType, sourceDocumentId,
  occurredAt, recordedAt, reason, idempotencyKey
)
SELECT id, 'opening_balance', currentBalance, 'legacy_opening_balance', id,
  ?, ?, 'رصيد مرحلي محفوظ دون إعادة بناء التاريخ',
  'legacy-opening:' || id
FROM customers
WHERE ABS(COALESCE(currentBalance, 0)) > 0.0000001
''',
      [now, now],
    );
  }

  @visibleForTesting
  static Future<void> migrateUnitMasterTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS units(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  normalizedName TEXT NOT NULL UNIQUE
)
''');

    Future<void> importNames(Iterable<String?> names) async {
      for (final name in names) {
        final value = name?.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (value == null || value.isEmpty) continue;
        await db.insert('units', {
          'name': value,
          'normalizedName': UnitNameNormalizer.normalize(value),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    await importNames(UnitNameNormalizer.defaultUnits);

    final products = await db.query(
      'products',
      columns: ['storageUnit', 'purchaseUnit', 'saleUnit'],
    );
    for (final product in products) {
      await importNames([
        product['storageUnit'] as String?,
        product['purchaseUnit'] as String?,
        product['saleUnit'] as String?,
      ]);
    }

    for (final tableAndColumn in [
      ('product_sale_units', 'saleUnit'),
      ('invoice_items', 'saleUnit'),
      ('purchase_invoice_items', 'purchaseUnit'),
    ]) {
      final rows = await db.query(
        tableAndColumn.$1,
        columns: [tableAndColumn.$2],
      );
      await importNames(rows.map((row) => row[tableAndColumn.$2] as String?));
    }
  }

  Future<List<String>> getUnits() async {
    final db = await database;
    final rows = await db.query(
      'units',
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE, name',
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<void> insertUnit(String name) async {
    final normalizedName = UnitNameNormalizer.normalize(name);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Unit name cannot be empty');
    }

    final db = await database;
    final existing = await db.query(
      'units',
      columns: ['id'],
      where: 'normalizedName = ?',
      whereArgs: [normalizedName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw StateError('هذه الوحدة موجودة بالفعل');
    }

    await db.insert('units', {
      'name': name.trim().replaceAll(RegExp(r'\s+'), ' '),
      'normalizedName': normalizedName,
    });
  }

  Future<void> renameUnit(String oldName, String newName) async {
    final normalizedOldName = UnitNameNormalizer.normalize(oldName);
    final normalizedNewName = UnitNameNormalizer.normalize(newName);
    if (normalizedNewName.isEmpty) {
      throw ArgumentError.value(
        newName,
        'newName',
        'Unit name cannot be empty',
      );
    }

    final db = await database;
    final rows = await db.query(
      'units',
      columns: ['id', 'name'],
      where: 'normalizedName = ?',
      whereArgs: [normalizedOldName],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('الوحدة غير موجودة');

    final unitId = rows.first['id'] as int;
    final canonicalOldName = rows.first['name'] as String;
    if (normalizedOldName == normalizedNewName) return;
    if (await _unitNameExists(db, normalizedNewName, exceptId: unitId)) {
      throw StateError('هذه الوحدة موجودة بالفعل');
    }
    if (await _isUnitInUse(db, canonicalOldName)) {
      throw StateError(
        'لا يمكن إعادة تسمية وحدة مرتبطة ببيانات أصناف أو فواتير',
      );
    }

    await db.update(
      'units',
      {
        'name': newName.trim().replaceAll(RegExp(r'\s+'), ' '),
        'normalizedName': normalizedNewName,
      },
      where: 'id = ?',
      whereArgs: [unitId],
    );
  }

  Future<void> deleteUnit(String name) async {
    final normalizedName = UnitNameNormalizer.normalize(name);
    final db = await database;
    final rows = await db.query(
      'units',
      columns: ['id', 'name'],
      where: 'normalizedName = ?',
      whereArgs: [normalizedName],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final canonicalName = rows.first['name'] as String;
    if (await _isUnitInUse(db, canonicalName)) {
      throw StateError('لا يمكن حذف وحدة مرتبطة ببيانات أصناف أو فواتير');
    }
    await db.delete('units', where: 'id = ?', whereArgs: [rows.first['id']]);
  }

  Future<bool> _unitNameExists(
    DatabaseExecutor db,
    String normalizedName, {
    required int exceptId,
  }) async {
    final rows = await db.query(
      'units',
      columns: ['id'],
      where: 'normalizedName = ? AND id != ?',
      whereArgs: [normalizedName, exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _isUnitInUse(DatabaseExecutor db, String name) async {
    final normalizedName = UnitNameNormalizer.normalize(name);
    final references = <(String, String)>[
      ('products', 'storageUnit'),
      ('products', 'purchaseUnit'),
      ('products', 'saleUnit'),
      ('product_sale_units', 'saleUnit'),
      ('invoice_items', 'saleUnit'),
      ('purchase_invoice_items', 'purchaseUnit'),
    ];

    for (final (table, column) in references) {
      final rows = await db.query(table, columns: [column]);
      if (rows.any(
        (row) =>
            row[column] is String &&
            UnitNameNormalizer.normalize(row[column] as String) ==
                normalizedName,
      )) {
        return true;
      }
    }
    return false;
  }

  @visibleForTesting
  static Future<void> migrateSaleUnitRetailPrice(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(product_sale_units)');
    if (columns.isEmpty) {
      throw StateError('product_sale_units table is missing');
    }

    final retailPriceColumn = columns.firstWhere(
      (column) => column['name'] == 'retailPrice',
      orElse: () => <String, Object?>{},
    );
    if (retailPriceColumn.isEmpty) {
      throw StateError('retailPrice column is missing from product_sale_units');
    }
    if ((retailPriceColumn['notnull'] as num).toInt() == 0) return;

    final sequenceRows = await db.rawQuery(
      "SELECT seq FROM sqlite_sequence WHERE name = 'product_sale_units'",
    );
    final previousSequence = sequenceRows.isEmpty
        ? 0
        : (sequenceRows.first['seq'] as num).toInt();

    await db.execute('''
CREATE TABLE product_sale_units_nullable(
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
    await db.execute('''
INSERT INTO product_sale_units_nullable
  (id, productId, saleUnit, retailPrice, wholesalePrice, conversionToStorage, allowSellingByAmount)
SELECT id, productId, saleUnit, retailPrice, wholesalePrice, conversionToStorage, allowSellingByAmount
FROM product_sale_units
''');
    await db.execute('DROP TABLE product_sale_units');
    await db.execute(
      'ALTER TABLE product_sale_units_nullable RENAME TO product_sale_units',
    );

    if (previousSequence > 0) {
      final migratedSequenceRows = await db.rawQuery(
        "SELECT seq FROM sqlite_sequence WHERE name = 'product_sale_units'",
      );
      final migratedSequence = migratedSequenceRows.isEmpty
          ? 0
          : (migratedSequenceRows.first['seq'] as num).toInt();
      if (previousSequence > migratedSequence) {
        final updated = await db.rawUpdate(
          "UPDATE sqlite_sequence SET seq = ? WHERE name = 'product_sale_units'",
          [previousSequence],
        );
        if (updated == 0) {
          await db.rawInsert(
            "INSERT INTO sqlite_sequence (name, seq) VALUES ('product_sale_units', ?)",
            [previousSequence],
          );
        }
      }
    }
  }

  Future<void> _ensureUsersTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  fullName TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'cashier',
  isActive INTEGER NOT NULL DEFAULT 1,
  canAccessReports INTEGER NOT NULL DEFAULT 0,
  canAccessProfits INTEGER NOT NULL DEFAULT 0,
  canAccessSettings INTEGER NOT NULL DEFAULT 0,
  canDiscount INTEGER NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;

    if (!product.quantity.isFinite || product.quantity < 0) {
      throw ArgumentError.value(product.quantity, 'quantity');
    }

    return db.transaction((txn) async {
      final values = product.toMap()..['quantity'] = 0.0;
      final productId = await txn.insert('products', values);
      if (product.quantity > 0) {
        final now = DateTime.now().toIso8601String();
        await _recordInventoryMovement(
          txn,
          InventoryMovement(
            productId: productId,
            movementType: InventoryMovement.openingBalance,
            direction: InventoryMovement.inbound,
            quantity: product.quantity,
            storageUnit: product.storageUnit,
            costStatus: InventoryMovement.costUnknown,
            sourceType: InventoryMovement.sourceOpeningBalance,
            movementAt: now,
            recordedAt: now,
            reason: 'رصيد افتتاحي عند إنشاء الصنف',
            idempotencyKey:
                'opening-product:$productId:${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
      }
      return productId;
    });
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

  Future<List<Product>> getActiveProducts() async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'isActive = 1',
      orderBy: 'id DESC',
    );
    return maps.map(Product.fromMap).toList();
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
        isActive = 1 AND (
          LOWER(name) LIKE ?
          OR LOWER(sku) LIKE ?
          OR LOWER(barcode) LIKE ?
        )
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
      where:
          'isActive = 1 AND imagePath IS NOT NULL AND LENGTH(TRIM(imagePath)) > 0',
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (index) => Product.fromMap(maps[index]));
  }

  Future<int> updateProduct(
    Product product, {
    String? inventoryChangeReason,
  }) async {
    final db = await database;

    if (product.id == null ||
        !product.quantity.isFinite ||
        product.quantity < 0) {
      throw ArgumentError('Invalid product inventory update');
    }

    return db.transaction((txn) async {
      final currentRows = await txn.query(
        'products',
        columns: ['quantity', 'storageUnit'],
        where: 'id = ?',
        whereArgs: [product.id],
        limit: 1,
      );
      if (currentRows.isEmpty) {
        throw StateError('Product ${product.id} not found');
      }
      final current = currentRows.single;
      final currentQuantity = (current['quantity'] as num?)?.toDouble() ?? 0;
      final currentUnit = current['storageUnit'] as String? ?? '';
      final unitChanged =
          currentUnit.trim().toLowerCase() !=
          product.storageUnit.trim().toLowerCase();
      final quantityChanged =
          (product.quantity - currentQuantity).abs() > 0.0000001;
      if (unitChanged && quantityChanged) {
        throw StateError(
          'Change the storage unit and stock quantity in separate reviewed '
          'operations.',
        );
      }
      if (unitChanged) {
        final movementCount = await txn.rawQuery(
          'SELECT COUNT(*) AS count FROM inventory_movements WHERE productId = ?',
          [product.id],
        );
        if ((movementCount.single['count'] as int) > 0) {
          throw StateError(
            'Storage unit cannot change after inventory movements exist.',
          );
        }
      }
      if (quantityChanged && (inventoryChangeReason?.trim().isEmpty ?? true)) {
        throw StateError('A reason is required for inventory quantity changes');
      }

      final values = product.toMap()..['quantity'] = currentQuantity;
      final updated = await txn.update(
        'products',
        values,
        where: 'id = ?',
        whereArgs: [product.id],
      );
      if (updated != 1) {
        throw StateError('Product ${product.id} not found');
      }

      if (quantityChanged) {
        final difference = product.quantity - currentQuantity;
        final now = DateTime.now().toIso8601String();
        final reason = inventoryChangeReason!.trim();
        final isInbound = difference > 0;
        await _recordInventoryMovement(
          txn,
          InventoryMovement(
            productId: product.id!,
            movementType: isInbound
                ? InventoryMovement.adjustmentIn
                : (reason.contains('تالف')
                      ? InventoryMovement.damage
                      : InventoryMovement.adjustmentOut),
            direction: isInbound
                ? InventoryMovement.inbound
                : InventoryMovement.outbound,
            quantity: difference.abs(),
            storageUnit: product.storageUnit,
            costStatus: InventoryMovement.costUnknown,
            sourceType: InventoryMovement.sourceStockAdjustment,
            movementAt: now,
            recordedAt: now,
            reason: reason,
            idempotencyKey:
                'product-adjustment:${product.id}:${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
      }
      return updated;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.update(
      'products',
      {'isActive': 0},
      where: 'id = ? AND isActive != 0',
      whereArgs: [id],
    );
  }

  Future<int> restoreProduct(int id) async {
    final db = await database;
    return db.update(
      'products',
      {'isActive': 1},
      where: 'id = ? AND isActive = 0',
      whereArgs: [id],
    );
  }

  Future<void> clearProducts() async {
    final db = await database;
    await db.update('products', {'isActive': 0}, where: 'isActive != 0');
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
    return db.transaction((txn) async {
      final openingBalance =
          (customer['currentBalance'] as num?)?.toDouble() ?? 0;
      final values = Map<String, dynamic>.from(customer)
        ..['currentBalance'] = 0.0;
      final customerId = await txn.insert('customers', values);
      if (openingBalance != 0) {
        final now = DateTime.now().toIso8601String();
        await _recordCustomerAccountTransaction(
          txn,
          customerId: customerId,
          transactionType: 'opening_balance',
          amount: openingBalance,
          sourceType: 'customer_opening_balance',
          occurredAt: now,
          recordedAt: now,
          reason: 'الرصيد الافتتاحي عند إنشاء العميل',
          idempotencyKey: 'customer-opening:$customerId',
        );
      }
      return customerId;
    });
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return db.rawQuery('''
SELECT c.*,
  COALESCE((
    SELECT SUM(cat.amount)
    FROM customer_account_transactions cat
    WHERE cat.customerId = c.id
  ), 0) AS currentBalance
FROM customers c
ORDER BY c.name ASC
''');
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await database;

    final maps = await db.rawQuery(
      '''
SELECT c.*,
  COALESCE((
    SELECT SUM(cat.amount)
    FROM customer_account_transactions cat
    WHERE cat.customerId = c.id
  ), 0) AS currentBalance
FROM customers c
WHERE c.id = ?
LIMIT 1
''',
      [id],
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final db = await database;

    final normalizedQuery = '%${query.toLowerCase()}%';

    return db.rawQuery(
      '''
SELECT c.*,
  COALESCE((
    SELECT SUM(cat.amount)
    FROM customer_account_transactions cat
    WHERE cat.customerId = c.id
  ), 0) AS currentBalance
FROM customers c
WHERE LOWER(c.name) LIKE ? OR LOWER(c.phone) LIKE ?
ORDER BY c.name ASC
''',
      [normalizedQuery, normalizedQuery],
    );
  }

  Future<int> updateCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'customers',
        columns: ['initialBalance', 'currentBalance'],
        where: 'id = ?',
        whereArgs: [customer['id']],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      final values = Map<String, dynamic>.from(customer)
        ..['initialBalance'] = rows.single['initialBalance']
        ..['currentBalance'] = rows.single['currentBalance'];
      return txn.update(
        'customers',
        values,
        where: 'id = ?',
        whereArgs: [customer['id']],
      );
    });
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final references = await txn.rawQuery(
        '''
SELECT
  (SELECT COUNT(*) FROM invoices WHERE customerId = ?) +
  (SELECT COUNT(*) FROM receipt_vouchers WHERE customerId = ?) +
  (SELECT COUNT(*) FROM customer_account_transactions WHERE customerId = ?)
  AS count
''',
        [id, id, id],
      );
      final referenceCount = references.single['count'] as int;
      if (referenceCount > 0) {
        throw StateError(
          'لا يمكن حذف عميل لديه فواتير أو سندات أو حركات حساب محفوظة',
        );
      }
      return txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> updateCustomerBalance(
    int customerId,
    double amount, {
    required String reason,
    required String idempotencyKey,
  }) async {
    if (!amount.isFinite ||
        amount == 0 ||
        reason.trim().isEmpty ||
        idempotencyKey.trim().isEmpty) {
      throw ArgumentError('A non-zero adjustment and reason are required');
    }
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      return _recordCustomerAccountTransaction(
        txn,
        customerId: customerId,
        transactionType: 'adjustment',
        amount: amount,
        sourceType: 'customer_adjustment',
        occurredAt: now,
        recordedAt: now,
        reason: reason.trim(),
        idempotencyKey: idempotencyKey,
      );
    });
  }

  Future<int> _recordCustomerAccountTransaction(
    DatabaseExecutor txn, {
    required int customerId,
    required String transactionType,
    required double amount,
    required String sourceType,
    int? sourceDocumentId,
    int? invoiceId,
    required String occurredAt,
    required String recordedAt,
    String? reason,
    String? notes,
    int? reversalOfTransactionId,
    required String idempotencyKey,
  }) async {
    if (customerId <= 0 ||
        !amount.isFinite ||
        amount == 0 ||
        transactionType.trim().isEmpty ||
        sourceType.trim().isEmpty ||
        idempotencyKey.trim().isEmpty) {
      throw ArgumentError('Invalid customer account transaction');
    }

    final existing = await txn.query(
      'customer_account_transactions',
      where: 'idempotencyKey = ?',
      whereArgs: [idempotencyKey],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final row = existing.single;
      final sameRequest =
          row['customerId'] == customerId &&
          row['transactionType'] == transactionType &&
          (row['amount'] as num).toDouble() == amount &&
          row['sourceType'] == sourceType &&
          row['sourceDocumentId'] == sourceDocumentId &&
          row['invoiceId'] == invoiceId &&
          row['reversalOfTransactionId'] == reversalOfTransactionId;
      if (!sameRequest) {
        throw StateError('Customer transaction idempotency key was reused');
      }
      return row['id'] as int;
    }

    final customers = await txn.query(
      'customers',
      columns: ['currentBalance'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (customers.isEmpty) {
      throw StateError('Customer $customerId not found');
    }
    final ledgerRows = await txn.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS balance FROM customer_account_transactions WHERE customerId = ?',
      [customerId],
    );
    final ledgerBalance = (ledgerRows.single['balance'] as num).toDouble();
    final storedBalance =
        (customers.single['currentBalance'] as num?)?.toDouble() ?? 0;
    if ((storedBalance - ledgerBalance).abs() > 0.0000001) {
      throw StateError(
        'Customer balance does not match the account ledger; review is required',
      );
    }
    final updated = await txn.update(
      'customers',
      {'currentBalance': ledgerBalance + amount, 'updatedAt': recordedAt},
      where: 'id = ?',
      whereArgs: [customerId],
    );
    if (updated != 1) {
      throw StateError('Customer $customerId not found');
    }
    return txn.insert('customer_account_transactions', {
      'customerId': customerId,
      'transactionType': transactionType,
      'amount': amount,
      'sourceType': sourceType,
      'sourceDocumentId': sourceDocumentId,
      'invoiceId': invoiceId,
      'occurredAt': occurredAt,
      'recordedAt': recordedAt,
      'reason': reason,
      'notes': notes,
      'reversalOfTransactionId': reversalOfTransactionId,
      'idempotencyKey': idempotencyKey,
    });
  }

  Future<int> recordInventoryMovement(
    InventoryMovement movement, {
    bool allowNegativeStock = false,
  }) async {
    final db = await database;
    return db.transaction(
      (txn) => _recordInventoryMovement(
        txn,
        movement,
        allowNegativeStock: allowNegativeStock,
      ),
    );
  }

  Future<int> reverseInventoryMovement(
    int movementId, {
    required String idempotencyKey,
    required String recordedAt,
    int? createdByUserId,
    String? reason,
    String? notes,
    bool allowNegativeStock = false,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      return _reverseInventoryMovement(
        txn,
        movementId,
        idempotencyKey: idempotencyKey,
        recordedAt: recordedAt,
        createdByUserId: createdByUserId,
        reason: reason,
        notes: notes,
        allowNegativeStock: allowNegativeStock,
      );
    });
  }

  Future<int> _reverseInventoryMovement(
    DatabaseExecutor txn,
    int movementId, {
    required String idempotencyKey,
    required String recordedAt,
    int? createdByUserId,
    String? reason,
    String? notes,
    bool allowNegativeStock = false,
  }) async {
    final originals = await txn.query(
      'inventory_movements',
      where: 'id = ?',
      whereArgs: [movementId],
      limit: 1,
    );
    if (originals.isEmpty) {
      throw StateError('Inventory movement $movementId not found');
    }

    final original = InventoryMovement.fromMap(originals.single);
    if (original.movementType == InventoryMovement.reversal ||
        original.reversalOfMovementId != null) {
      throw StateError('A reversal movement cannot be reversed');
    }
    final existingReversals = await txn.query(
      'inventory_movements',
      where: 'reversalOfMovementId = ?',
      whereArgs: [movementId],
      limit: 1,
    );
    if (existingReversals.isNotEmpty) {
      final existingReversal = InventoryMovement.fromMap(
        existingReversals.single,
      );
      if (existingReversal.idempotencyKey == idempotencyKey) {
        return existingReversal.id!;
      }
      throw StateError('Inventory movement $movementId was already reversed');
    }

    return _recordInventoryMovement(
      txn,
      InventoryMovement(
        productId: original.productId,
        warehouseId: original.warehouseId,
        movementType: InventoryMovement.reversal,
        direction: original.direction == InventoryMovement.inbound
            ? InventoryMovement.outbound
            : InventoryMovement.inbound,
        quantity: original.quantity,
        storageUnit: original.storageUnit,
        unitCost: original.unitCost,
        totalCost: original.totalCost,
        costStatus: original.costStatus,
        sourceType: original.sourceType == InventoryMovement.purchaseInvoice
            ? InventoryMovement.purchaseInvoiceReversal
            : InventoryMovement.invoiceReversal,
        sourceDocumentId: original.sourceDocumentId,
        sourceLineId: original.sourceLineId,
        movementAt: DateTime.now().toIso8601String(),
        recordedAt: recordedAt,
        createdByUserId: createdByUserId,
        reason: reason,
        notes: notes,
        reversalOfMovementId: movementId,
        idempotencyKey: idempotencyKey,
        trackingStatus: original.trackingStatus,
      ),
      allowNegativeStock: allowNegativeStock,
    );
  }

  Future<int> _recordInventoryMovement(
    DatabaseExecutor txn,
    InventoryMovement movement, {
    bool allowNegativeStock = false,
  }) async {
    if (movement.productId <= 0 ||
        !movement.quantity.isFinite ||
        movement.quantity <= 0 ||
        movement.idempotencyKey.trim().isEmpty ||
        movement.storageUnit.trim().isEmpty) {
      throw ArgumentError('Invalid inventory movement');
    }
    if (movement.direction != InventoryMovement.inbound &&
        movement.direction != InventoryMovement.outbound) {
      throw ArgumentError.value(movement.direction, 'direction');
    }
    if ((movement.unitCost == null) != (movement.totalCost == null) ||
        (movement.unitCost != null &&
            (!movement.unitCost!.isFinite ||
                movement.unitCost! < 0 ||
                !movement.totalCost!.isFinite ||
                movement.totalCost! < 0))) {
      throw ArgumentError('Inventory movement costs must be valid and paired');
    }

    final existing = await txn.query(
      'inventory_movements',
      where: 'idempotencyKey = ?',
      whereArgs: [movement.idempotencyKey],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final saved = InventoryMovement.fromMap(existing.single);
      final sameRequest =
          saved.productId == movement.productId &&
          saved.movementType == movement.movementType &&
          saved.direction == movement.direction &&
          saved.quantity == movement.quantity &&
          saved.storageUnit == movement.storageUnit &&
          saved.sourceType == movement.sourceType &&
          saved.sourceDocumentId == movement.sourceDocumentId &&
          saved.sourceLineId == movement.sourceLineId &&
          saved.reversalOfMovementId == movement.reversalOfMovementId;
      if (!sameRequest) {
        throw StateError('Inventory movement idempotency key was reused');
      }
      return saved.id!;
    }

    final products = await txn.query(
      'products',
      columns: ['quantity', 'storageUnit'],
      where: 'id = ?',
      whereArgs: [movement.productId],
      limit: 1,
    );
    if (products.isEmpty) {
      throw StateError('Product ${movement.productId} not found');
    }
    final storageUnit = products.single['storageUnit'] as String? ?? '';
    if (storageUnit.trim().toLowerCase() !=
        movement.storageUnit.trim().toLowerCase()) {
      throw StateError(
        'Movement storage unit does not match product ${movement.productId}',
      );
    }

    final signedQuantity = movement.direction == InventoryMovement.inbound
        ? movement.quantity
        : -movement.quantity;
    final whereClause =
        movement.direction == InventoryMovement.outbound && !allowNegativeStock
        ? 'id = ? AND COALESCE(quantity, 0) >= ?'
        : 'id = ?';
    final whereArgs =
        movement.direction == InventoryMovement.outbound && !allowNegativeStock
        ? [movement.productId, movement.quantity]
        : [movement.productId];
    final updated = await txn.rawUpdate(
      'UPDATE products SET quantity = COALESCE(quantity, 0) + ? WHERE $whereClause',
      [signedQuantity, ...whereArgs],
    );
    if (updated != 1) {
      throw StateError(
        'Insufficient stock or missing product ${movement.productId}',
      );
    }

    return txn.insert('inventory_movements', movement.toMap());
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

      final itemStockReductions = <int, double>{};
      final preparedItems = <(InvoiceItem, String, double)>[];
      for (final item in items) {
        final products = await txn.query(
          'products',
          columns: ['storageUnit', 'conversionFactor'],
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );
        if (products.isEmpty) {
          throw StateError('Product ${item.productId} not found');
        }
        final product = products.single;
        final storageUnit = product['storageUnit'] as String? ?? '';
        var conversionToStorage =
            (product['conversionFactor'] as num?)?.toDouble() ?? 1;
        if (item.saleUnit.trim().toLowerCase() !=
            storageUnit.trim().toLowerCase()) {
          final saleUnits = await txn.query(
            'product_sale_units',
            columns: ['conversionToStorage'],
            where: 'productId = ? AND LOWER(TRIM(saleUnit)) = ?',
            whereArgs: [item.productId, item.saleUnit.trim().toLowerCase()],
            limit: 1,
          );
          if (saleUnits.isNotEmpty) {
            conversionToStorage =
                (saleUnits.single['conversionToStorage'] as num).toDouble();
          }
        }
        final storageQuantity = calculateStorageQuantity(
          quantity: item.quantity,
          saleUnit: item.saleUnit,
          storageUnit: storageUnit,
          conversionToStorage: conversionToStorage,
        );
        itemStockReductions.update(
          item.productId,
          (quantity) => quantity + storageQuantity,
          ifAbsent: () => storageQuantity,
        );
        preparedItems.add((item, storageUnit, storageQuantity));
      }

      if (stockReductions.length != itemStockReductions.length ||
          itemStockReductions.entries.any((entry) {
            final supplied = stockReductions[entry.key];
            return supplied == null ||
                (supplied - entry.value).abs() > 0.0000001;
          })) {
        throw StateError(
          'Stock reductions do not match invoice item quantities',
        );
      }

      final invoiceId = await txn.insert('invoices', invoice.toMap());
      final recordedAt = DateTime.now().toIso8601String();
      for (final prepared in preparedItems) {
        final item = prepared.$1;
        final itemId = await txn.insert('invoice_items', {
          ...item.toMap(),
          'invoiceId': invoiceId,
        });
        await _recordInventoryMovement(
          txn,
          InventoryMovement(
            productId: item.productId,
            movementType: InventoryMovement.saleIssue,
            direction: InventoryMovement.outbound,
            quantity: prepared.$3,
            storageUnit: prepared.$2,
            costStatus: InventoryMovement.costUnknown,
            sourceType: InventoryMovement.salesInvoice,
            sourceDocumentId: invoiceId,
            sourceLineId: itemId,
            movementAt: invoice.date,
            recordedAt: recordedAt,
            createdByUserId: invoice.cashierId,
            idempotencyKey: 'sale-invoice:$invoiceId:item:$itemId',
          ),
        );
      }

      if (invoice.paymentMethod == 'credit') {
        await _recordCustomerAccountTransaction(
          txn,
          customerId: invoice.customerId!,
          transactionType: 'credit_invoice',
          amount: invoice.total,
          sourceType: 'credit_sales_invoice',
          sourceDocumentId: invoiceId,
          invoiceId: invoiceId,
          occurredAt: invoice.date,
          recordedAt: recordedAt,
          idempotencyKey: 'credit-sales-invoice:$invoiceId',
        );
      }

      return invoiceId;
    });
  }

  Future<int> createReceiptVoucher(ReceiptVoucher voucher) async {
    if (!voucher.amount.isFinite ||
        voucher.amount <= 0 ||
        voucher.idempotencyKey.trim().isEmpty) {
      throw ArgumentError(
        'A positive receipt amount and idempotency key are required',
      );
    }

    final db = await database;
    return db.transaction((txn) async {
      final priorTransactions = await txn.query(
        'customer_account_transactions',
        where: 'idempotencyKey = ?',
        whereArgs: [voucher.idempotencyKey],
        limit: 1,
      );
      if (priorTransactions.isNotEmpty) {
        final prior = priorTransactions.single;
        final matches =
            prior['customerId'] == voucher.customerId &&
            prior['transactionType'] == 'receipt' &&
            (prior['amount'] as num).toDouble() == -voucher.amount &&
            prior['invoiceId'] == voucher.invoiceId &&
            prior['sourceType'] == 'receipt_voucher' &&
            prior['sourceDocumentId'] != null;
        if (!matches) {
          throw StateError('Receipt idempotency key was reused');
        }
        return prior['sourceDocumentId'] as int;
      }

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
          columns: ['total', 'customerId', 'paymentMethod', 'status'],
          where: 'id = ?',
          whereArgs: [voucher.invoiceId],
          limit: 1,
        );
        if (invoices.isEmpty ||
            invoices.first['customerId'] != voucher.customerId ||
            invoices.first['paymentMethod'] != 'credit' ||
            invoices.first['status'] == 'voided') {
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

      await _recordCustomerAccountTransaction(
        txn,
        customerId: voucher.customerId,
        transactionType: 'receipt',
        amount: -voucher.amount,
        sourceType: 'receipt_voucher',
        sourceDocumentId: voucherId,
        invoiceId: voucher.invoiceId,
        occurredAt: voucher.date,
        recordedAt: voucher.createdAt,
        notes: voucher.notes,
        idempotencyKey: voucher.idempotencyKey,
      );
      return voucherId;
    });
  }

  Future<void> cancelSalesInvoiceWithEffects(
    int invoiceId, {
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Cancellation reason required',
      );
    }
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
      if (invoice['status'] == 'voided') return;

      Map<String, dynamic>? creditInvoiceTransaction;
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
        final accountTransactions = await txn.query(
          'customer_account_transactions',
          where: 'sourceType = ? AND sourceDocumentId = ?',
          whereArgs: ['credit_sales_invoice', invoiceId],
        );
        if (accountTransactions.length != 1) {
          throw StateError(
            'لا يمكن إلغاء الفاتورة الآجلة بأمان: لا يوجد قيد مالي موثق '
            'لها. يلزم مراجعة رصيد العميل وتسويته يدويًا أولًا.',
          );
        }
        final accountTransaction = accountTransactions.single;
        final invoiceTotal = (invoice['total'] as num?)?.toDouble() ?? 0;
        if (accountTransaction['customerId'] != customerId ||
            accountTransaction['transactionType'] != 'credit_invoice' ||
            ((accountTransaction['amount'] as num).toDouble() - invoiceTotal)
                    .abs() >
                0.0000001) {
          throw StateError(
            'قيد الفاتورة الآجل غير مطابق لبيانات الفاتورة؛ أوقف الإلغاء للمراجعة.',
          );
        }
        creditInvoiceTransaction = accountTransaction;
      }

      final items = await txn.query(
        'invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [invoiceId],
      );
      final saleMovements = await txn.query(
        'inventory_movements',
        where: 'sourceType = ? AND sourceDocumentId = ? AND movementType = ?',
        whereArgs: [
          InventoryMovement.salesInvoice,
          invoiceId,
          InventoryMovement.saleIssue,
        ],
      );
      final movementsByLineId = <int, InventoryMovement>{};
      for (final movementRow in saleMovements) {
        final movement = InventoryMovement.fromMap(movementRow);
        final lineId = movement.sourceLineId;
        if (lineId == null ||
            movementsByLineId.containsKey(lineId) ||
            movement.trackingStatus != 'tracked') {
          throw StateError(
            'Invoice has incomplete or invalid inventory movement history',
          );
        }
        movementsByLineId[lineId] = movement;
      }
      if (items.length != movementsByLineId.length ||
          items.any((item) {
            final movement = movementsByLineId[item['id']];
            return movement == null ||
                movement.productId != item['productId'] ||
                movement.direction != InventoryMovement.outbound;
          })) {
        throw StateError(
          'This invoice predates the inventory ledger or lacks complete '
          'movement history. Review it and record a documented adjustment '
          'before cancellation.',
        );
      }
      final recordedAt = DateTime.now().toIso8601String();
      for (final movement in movementsByLineId.values) {
        await _reverseInventoryMovement(
          txn,
          movement.id!,
          idempotencyKey: 'sale-reversal:${movement.id}',
          recordedAt: recordedAt,
          createdByUserId: invoice['cashierId'] as int?,
          reason: reason.trim(),
        );
      }

      if (creditInvoiceTransaction != null) {
        final originalTransaction = creditInvoiceTransaction;
        await _recordCustomerAccountTransaction(
          txn,
          customerId: originalTransaction['customerId'] as int,
          transactionType: 'invoice_reversal',
          amount: -((originalTransaction['amount'] as num).toDouble()),
          sourceType: 'sales_invoice_cancellation',
          sourceDocumentId: invoiceId,
          invoiceId: invoiceId,
          occurredAt: recordedAt,
          recordedAt: recordedAt,
          reason: reason.trim(),
          reversalOfTransactionId: originalTransaction['id'] as int,
          idempotencyKey: 'credit-invoice-reversal:$invoiceId',
        );
      }

      final updated = await txn.update(
        'invoices',
        {
          'status': 'voided',
          'cancelledAt': recordedAt,
          'cancellationReason': reason.trim(),
        },
        where: "id = ? AND status != 'voided'",
        whereArgs: [invoiceId],
      );
      if (updated != 1) {
        throw StateError('Invoice status changed during cancellation');
      }
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

  Future<List<Map<String, dynamic>>> getCustomerAccountTransactions(
    int customerId,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
SELECT cat.*, i.invoiceNumber, i.status AS invoiceStatus,
       rv.voucherNumber AS receiptNumber
FROM customer_account_transactions cat
LEFT JOIN invoices i ON i.id = cat.invoiceId
LEFT JOIN receipt_vouchers rv
  ON cat.sourceType = 'receipt_voucher' AND rv.id = cat.sourceDocumentId
WHERE cat.customerId = ?
ORDER BY cat.occurredAt DESC, cat.id DESC
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
        final quantity = (item['quantity'] as num).toDouble();
        final storageQuantity = calculateStorageQuantity(
          quantity: quantity,
          saleUnit: selectedUnit,
          storageUnit: productStorageUnit,
          conversionToStorage: conversionFactor,
        );
        final itemId = await txn.insert('purchase_invoice_items', {
          ...item,
          'invoiceId': invoiceId,
          'purchaseUnit': selectedUnit,
          'conversionFactor': conversionFactor,
          'storageQuantity': storageQuantity,
        });

        final hasUnallocatedDiscount =
            ((invoice['discount'] as num?)?.toDouble() ?? 0) > 0;
        final lineTotal = (item['total'] as num).toDouble();
        await _recordInventoryMovement(
          txn,
          InventoryMovement(
            productId: item['productId'] as int,
            movementType: InventoryMovement.purchaseReceipt,
            direction: InventoryMovement.inbound,
            quantity: storageQuantity,
            storageUnit: productStorageUnit,
            unitCost: hasUnallocatedDiscount
                ? null
                : (item['unitPrice'] as num).toDouble() / conversionFactor,
            totalCost: hasUnallocatedDiscount ? null : lineTotal,
            costStatus: hasUnallocatedDiscount
                ? InventoryMovement.costUnallocated
                : InventoryMovement.costKnown,
            sourceType: InventoryMovement.purchaseInvoice,
            sourceDocumentId: invoiceId,
            sourceLineId: itemId,
            movementAt: invoice['date'] as String,
            recordedAt: invoice['updatedAt'] as String,
            reason: hasUnallocatedDiscount
                ? 'تكلفة البند غير موزعة بعد خصم الفاتورة'
                : null,
            idempotencyKey: 'purchase-invoice:$invoiceId:item:$itemId',
          ),
        );
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
    bool includeVoided = true,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final arguments = <Object>[];

    if (!includeVoided) {
      conditions.add("pi.status != 'voided'");
    }

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

  Future<int> cancelPurchaseInvoice(int id, {required String reason}) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Cancellation reason required',
      );
    }
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
      if (invoice['status'] == 'voided') return 0;
      final items = await txn.query(
        'purchase_invoice_items',
        where: 'invoiceId = ?',
        whereArgs: [id],
      );
      final purchaseMovements = await txn.query(
        'inventory_movements',
        where: 'sourceType = ? AND sourceDocumentId = ? AND movementType = ?',
        whereArgs: [
          InventoryMovement.purchaseInvoice,
          id,
          InventoryMovement.purchaseReceipt,
        ],
      );
      final movementsByLineId = <int, InventoryMovement>{};
      for (final movementRow in purchaseMovements) {
        final movement = InventoryMovement.fromMap(movementRow);
        final lineId = movement.sourceLineId;
        if (lineId == null ||
            movementsByLineId.containsKey(lineId) ||
            movement.trackingStatus != 'tracked') {
          throw StateError(
            'Purchase invoice has incomplete or invalid inventory history',
          );
        }
        movementsByLineId[lineId] = movement;
      }
      if (items.length != movementsByLineId.length ||
          items.any((item) {
            final movement = movementsByLineId[item['id']];
            return movement == null ||
                movement.productId != item['productId'] ||
                movement.direction != InventoryMovement.inbound;
          })) {
        throw StateError(
          'This purchase invoice predates the inventory ledger or lacks '
          'complete movement history. Review it and record a documented '
          'adjustment before cancellation.',
        );
      }

      for (final item in items) {
        final itemId = item['id'] as int;
        final movement = movementsByLineId[itemId]!;
        final laterMovements = await txn.query(
          'inventory_movements',
          columns: ['id'],
          where: '''
productId = ? AND id > ? AND NOT (sourceType = ? AND sourceDocumentId = ?)
''',
          whereArgs: [
            movement.productId,
            movement.id,
            InventoryMovement.purchaseInvoice,
            id,
          ],
          limit: 1,
        );
        if (laterMovements.isNotEmpty) {
          throw StateError(
            'Purchase invoice cannot be cancelled safely: product '
            '${movement.productId} has later inventory movements. Review '
            'subsequent sales and adjustments first.',
          );
        }
      }

      final quantitiesToReverse = <int, double>{};
      for (final movement in movementsByLineId.values) {
        quantitiesToReverse.update(
          movement.productId,
          (quantity) => quantity + movement.quantity,
          ifAbsent: () => movement.quantity,
        );
      }
      for (final entry in quantitiesToReverse.entries) {
        final products = await txn.query(
          'products',
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (products.isEmpty) {
          throw StateError(
            'Product ${entry.key} is missing; purchase cancellation stopped',
          );
        }
        final available =
            (products.single['quantity'] as num?)?.toDouble() ?? 0;
        if (available + 0.0000001 < entry.value) {
          throw StateError(
            'Purchase cancellation stopped: product ${entry.key} has '
            'insufficient stock to reverse the received quantity.',
          );
        }
      }

      final recordedAt = DateTime.now().toIso8601String();
      for (final movement in movementsByLineId.values) {
        await _reverseInventoryMovement(
          txn,
          movement.id!,
          idempotencyKey: 'purchase-reversal:${movement.id}',
          recordedAt: recordedAt,
          reason: reason.trim(),
        );
      }

      if (invoice['paymentType'] == 'credit') {
        final suppliers = await txn.query(
          'suppliers',
          columns: ['currentBalance'],
          where: 'id = ?',
          whereArgs: [invoice['supplierId']],
          limit: 1,
        );
        if (suppliers.isEmpty) {
          throw StateError(
            'Supplier ${invoice['supplierId']} not found during cancellation',
          );
        }
        final balance =
            (suppliers.single['currentBalance'] as num?)?.toDouble() ?? 0;
        final totalAmount = (invoice['totalAmount'] as num?)?.toDouble() ?? 0;
        if (balance < totalAmount) {
          throw StateError(
            'Supplier balance has already been settled or adjusted. '
            'Resolve the supplier account before cancelling this invoice.',
          );
        }
        await txn.rawUpdate(
          'UPDATE suppliers SET currentBalance = COALESCE(currentBalance, 0) - ?, updatedAt = ? WHERE id = ?',
          [
            invoice['totalAmount'],
            DateTime.now().toIso8601String(),
            invoice['supplierId'],
          ],
        );
      }

      final updated = await txn.update(
        'purchase_invoices',
        {
          'status': 'voided',
          'cancelledAt': recordedAt,
          'cancellationReason': reason.trim(),
        },
        where: "id = ? AND status != 'voided'",
        whereArgs: [id],
      );
      if (updated != 1) {
        throw StateError('Purchase invoice status changed during cancellation');
      }
      return 1;
    });
  }
}
