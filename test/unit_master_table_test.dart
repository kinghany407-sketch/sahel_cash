import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/models/product_model.dart';
import 'package:sahel_cash/screens/products/add_product_dialog.dart';
import 'package:sahel_cash/screens/products/units_manager.dart';
import 'package:sahel_cash/utils/unit_name_normalizer.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'version 22 migration imports units and preserves legacy tables',
    () async {
      final directory = await Directory.systemTemp.createTemp('units-v22-');
      addTearDown(() => directory.delete(recursive: true));

      final sourcePath = Platform.environment['UNIT_MASTER_MIGRATION_SOURCE'];
      final dbPath = '${directory.path}\\migration-test.db';
      if (sourcePath != null && sourcePath.isNotEmpty) {
        await File(sourcePath).copy(dbPath);
      }

      late Database db;
      db = await databaseFactoryFfi.openDatabase(dbPath);
      addTearDown(() async {
        if (db.isOpen) await db.close();
      });
      if (sourcePath == null || sourcePath.isEmpty) {
        await _createLegacySchema(db);
      }

      final legacyTables = [
        'products',
        'product_sale_units',
        'invoices',
        'invoice_items',
        'purchase_invoices',
        'purchase_invoice_items',
      ];
      final before = <String, String>{};
      for (final table in legacyTables) {
        before[table] = jsonEncode(await db.query(table, orderBy: 'id'));
      }
      final beforeCounts = await _tableCounts(db, legacyTables);
      final beforeVersion = (await db.rawQuery(
        'PRAGMA user_version',
      )).single['user_version'];

      await db.transaction(DatabaseHelper.migrateUnitMasterTable);
      await db.execute('PRAGMA user_version = 22');

      expect(await db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
        0,
      );
      expect(
        (await db.rawQuery('PRAGMA user_version')).single['user_version'],
        22,
      );
      for (final table in legacyTables) {
        expect(jsonEncode(await db.query(table, orderBy: 'id')), before[table]);
      }
      expect(await _tableCounts(db, legacyTables), beforeCounts);

      final imported = (await db.query(
        'units',
        columns: ['name'],
      )).map((row) => row['name'] as String).toSet();
      expect(imported, containsAll(UnitNameNormalizer.defaultUnits));
      if (sourcePath != null && sourcePath.isNotEmpty) {
        expect(imported, hasLength(21));
        expect(imported, containsAll(['كوب', 'عامود', 'طبق']));
        final orphanUnits = await db.rawQuery('''
SELECT COUNT(*) AS count
FROM product_sale_units u
LEFT JOIN products p ON p.id = u.productId
WHERE p.id IS NULL
''');
        expect((orphanUnits.single['count'] as num).toInt(), 6);
        final orphanInvoiceItems = await db.rawQuery('''
SELECT COUNT(*) AS count
FROM invoice_items i
LEFT JOIN products p ON p.id = i.productId
WHERE p.id IS NULL
''');
        expect((orphanInvoiceItems.single['count'] as num).toInt(), 8);
        expect(beforeVersion, 21);
      } else {
        expect(imported, hasLength(20));
        expect(imported, containsAll(['كوب', 'عامود', 'كرتونة']));
      }

      DatabaseHelper.setDatabaseForTesting(db);
      addTearDown(() => DatabaseHelper.setDatabaseForTesting(null));
      final manager = UnitsManager();
      await manager.loadUnits();
      await manager.addUnit('طبق جديد');
      await manager.loadUnits();
      expect(manager.availableUnits, containsAll(['كوب', 'عامود', 'طبق جديد']));

      await expectLater(
        manager.addUnit('  كرتونه  '),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        manager.updateUnit('كوب', 'وعاء'),
        throwsA(isA<StateError>()),
      );
      await expectLater(manager.deleteUnit('كوب'), throwsA(isA<StateError>()));

      await manager.addUnit('وحدة قبل');
      await manager.updateUnit('وحدة قبل', 'وحدة بعد');
      await manager.loadUnits();
      expect(manager.availableUnits, contains('وحدة بعد'));
      await manager.deleteUnit('وحدة بعد');
      await manager.loadUnits();
      expect(manager.availableUnits, isNot(contains('وحدة بعد')));

      DatabaseHelper.setDatabaseForTesting(null);
      await db.close();
      db = await databaseFactoryFfi.openDatabase(dbPath);
      DatabaseHelper.setDatabaseForTesting(db);
      await manager.loadUnits();
      expect(manager.availableUnits, containsAll(['كوب', 'عامود', 'طبق جديد']));

      DatabaseHelper.setDatabaseForTesting(null);
    },
  );

  testWidgets('product view mode has no sale-unit mutation controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late Directory directory;
    late Database db;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('readonly-unit-');
      db = await databaseFactoryFfi.openDatabase(
        '${directory.path}\\readonly-test.db',
      );
      await _createLegacySchema(db);
      await DatabaseHelper.migrateUnitMasterTable(db);
    });
    DatabaseHelper.setDatabaseForTesting(db);
    addTearDown(() async {
      DatabaseHelper.setDatabaseForTesting(null);
      await tester.runAsync(() async {
        if (db.isOpen) await db.close();
        await directory.delete(recursive: true);
      });
    });
    late Map<String, String> before;
    await tester.runAsync(() async {
      before = await _tableSnapshots(db);
    });

    final product = Product(
      id: 49,
      name: 'كوب شفاف بغطاء',
      barcode: '',
      sku: '',
      category: '',
      brand: '',
      buyPrice: 0,
      sellPrice: 3,
      quantity: 20,
      minQuantity: 0,
      description: '',
      storageUnit: 'كوب',
      purchaseUnit: 'كرتونة',
      saleUnit: 'كوب',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    AddProductDialog(product: product, readOnly: true),
              ),
              child: const Text('فتح العرض'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.tap(find.text('فتح العرض'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('عرض الصنف'), findsOneWidget);
    expect(find.text('إضافة وحدة بيع', skipOffstage: false), findsNothing);
    expect(find.byIcon(Icons.edit, skipOffstage: false), findsNothing);
    expect(find.byIcon(Icons.delete, skipOffstage: false), findsNothing);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField, skipOffstage: false))
          .every((field) => field.readOnly),
      isTrue,
    );
    expect(
      tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>, skipOffstage: false),
          )
          .every((field) => field.onChanged == null),
      isTrue,
    );

    final saleUnitsSection = find.text('وحدات البيع والأسعار');
    await tester.ensureVisible(saleUnitsSection);
    await tester.tap(saleUnitsSection);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('كوب'), findsWidgets);
    expect(find.text('عامود'), findsWidgets);

    late Map<String, String> after;
    await tester.runAsync(() async {
      after = await _tableSnapshots(db);
    });
    expect(after, before);
  });
}

Future<Map<String, String>> _tableSnapshots(Database db) async {
  const tables = [
    'products',
    'product_sale_units',
    'invoices',
    'invoice_items',
    'purchase_invoices',
    'purchase_invoice_items',
    'units',
  ];
  return {
    for (final table in tables)
      table: jsonEncode(await db.query(table, orderBy: 'id')),
  };
}

Future<Map<String, int>> _tableCounts(Database db, List<String> tables) async {
  final counts = <String, int>{};
  for (final table in tables) {
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM "$table"');
    counts[table] = (result.single['count'] as num).toInt();
  }
  return counts;
}

Future<void> _createLegacySchema(Database db) async {
  await db.execute('''
CREATE TABLE products(
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  storageUnit TEXT,
  purchaseUnit TEXT,
  saleUnit TEXT
)
''');
  await db.execute('''
CREATE TABLE product_sale_units(
  id INTEGER PRIMARY KEY,
  productId INTEGER NOT NULL,
  saleUnit TEXT NOT NULL,
  retailPrice REAL,
  wholesalePrice REAL,
  conversionToStorage REAL NOT NULL
)
''');
  await db.execute('''
CREATE TABLE invoices(id INTEGER PRIMARY KEY, total REAL NOT NULL)
''');
  await db.execute('''
CREATE TABLE invoice_items(
  id INTEGER PRIMARY KEY,
  invoiceId INTEGER NOT NULL,
  productId INTEGER NOT NULL,
  productName TEXT NOT NULL,
  saleUnit TEXT NOT NULL,
  quantity REAL NOT NULL,
  unitPrice REAL NOT NULL,
  total REAL NOT NULL
)
''');
  await db.execute('''
CREATE TABLE purchase_invoices(id INTEGER PRIMARY KEY, totalAmount REAL)
''');
  await db.execute('''
CREATE TABLE purchase_invoice_items(
  id INTEGER PRIMARY KEY,
  invoiceId INTEGER NOT NULL,
  productId INTEGER NOT NULL,
  purchaseUnit TEXT NOT NULL
)
''');
  await db.insert('products', {
    'id': 49,
    'name': 'كوب شفاف بغطاء',
    'storageUnit': 'كوب',
    'purchaseUnit': 'كرتونة',
    'saleUnit': 'كوب',
  });
  await db.insert('product_sale_units', {
    'id': 127,
    'productId': 49,
    'saleUnit': 'كوب',
    'retailPrice': 3,
    'conversionToStorage': 1,
  });
  await db.insert('product_sale_units', {
    'id': 128,
    'productId': 49,
    'saleUnit': 'عامود',
    'wholesalePrice': 85,
    'conversionToStorage': 50,
  });
  await db.insert('invoice_items', {
    'id': 1,
    'invoiceId': 1,
    'productId': 49,
    'productName': 'كوب شفاف بغطاء',
    'saleUnit': 'عامود',
    'quantity': 1,
    'unitPrice': 85,
    'total': 85,
  });
  await db.insert('purchase_invoice_items', {
    'id': 1,
    'invoiceId': 1,
    'productId': 49,
    'purchaseUnit': 'كرتونة',
  });
  await db.execute('PRAGMA user_version = 21');
}
