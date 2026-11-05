import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/models/product_model.dart';
import 'package:sahel_cash/screens/products/add_product_dialog.dart';
import 'package:sahel_cash/screens/products/units_manager.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'sale unit dialog adds units, converts duplicates to edits, and preserves amount selling',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late Directory directory;
      late Database db;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('sale-unit-dialog-');
        db = await databaseFactoryFfi.openDatabase(
          '${directory.path}\\sale-units.db',
        );
        await _createTestSchema(db);
      });
      DatabaseHelper.setDatabaseForTesting(db);
      addTearDown(() async {
        DatabaseHelper.setDatabaseForTesting(null);
        await tester.runAsync(() async {
          if (db.isOpen) await db.close();
          await directory.delete(recursive: true);
        });
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AddProductDialog(product: _testProduct()),
                ),
                child: const Text('فتح الصنف'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('فتح الصنف'));
      await _pumpDatabaseWork(tester);
      late List<String> databaseUnits;
      await tester.runAsync(() async {
        databaseUnits = await DatabaseHelper.instance.getUnits();
      });
      expect(databaseUnits, contains('طبق'));
      expect(UnitsManager().isLoaded, isTrue);

      await _openSaleUnitsSection(tester);
      await _openAddUnitDialog(tester);
      await _selectUnit(tester, 'طبق');
      await _enterSaleUnitFields(
        tester,
        retail: '12',
        wholesale: '',
        conversion: '1',
      );
      await _setAmountSelling(tester, true);
      await _saveSaleUnitDialog(tester);

      expect(find.text('طبق'), findsWidgets);

      await _openAddUnitDialog(tester);
      await _selectUnit(tester, 'كيلو');
      var dialog = _saleUnitDialog();
      expect(
        find.descendant(of: dialog, matching: find.text('تعديل وحدة بيع')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(
            'هذه الوحدة مسجلة بالفعل. سيتم تعديلها فقط بعد تأكيد الحفظ.',
          ),
        ),
        findsOneWidget,
      );
      expect(_saleUnitFieldValues(tester, dialog), [
        '120.0',
        '100.0',
        '1000.0',
      ]);
      expect(
        tester
            .widget<SwitchListTile>(
              find.descendant(
                of: dialog,
                matching: find.byType(SwitchListTile),
              ),
            )
            .value,
        isTrue,
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('إلغاء')),
      );
      await tester.pumpAndSettle();

      await _openSaleUnitsSection(tester);
      await _editSaleUnit(tester, 'كيلو');
      dialog = _saleUnitDialog();
      expect(_saleUnitFieldValues(tester, dialog), [
        '120.0',
        '100.0',
        '1000.0',
      ]);
      await _enterSaleUnitFields(
        tester,
        retail: '121',
        wholesale: '100',
        conversion: '900',
      );
      await _setAmountSelling(tester, false);
      await _saveSaleUnitDialog(tester);

      expect(find.text('قطاعي: 12.00'), findsOneWidget);
      expect(find.text('قطاعي: 121.00 | جملة: 100.00'), findsOneWidget);

      late List<Map<String, Object?>> unchangedUnits;
      await tester.runAsync(() async {
        unchangedUnits = await db.query(
          'product_sale_units',
          where: 'productId = ?',
          whereArgs: [44],
          orderBy: 'saleUnit',
        );
      });
      expect(unchangedUnits, hasLength(2));
      expect(unchangedUnits.map((unit) => unit['saleUnit']).toSet(), {
        'جرام',
        'كيلو',
      });
    },
  );
}

Future<void> _createTestSchema(Database db) async {
  await db.execute('''
CREATE TABLE units(
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  normalizedName TEXT NOT NULL UNIQUE
)
''');
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
  purchaseUnit TEXT,
  saleUnit TEXT,
  conversionFactor REAL,
  unitsPerPurchaseUnit INTEGER,
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
  allowSellingByAmount INTEGER NOT NULL DEFAULT 0
)
''');

  for (final unit in ['جرام', 'كيلو', 'طبق']) {
    await db.insert('units', {'name': unit, 'normalizedName': unit});
  }
  await db.insert('products', _testProduct().toMap());
  await db.insert('product_sale_units', {
    'productId': 44,
    'saleUnit': 'جرام',
    'retailPrice': 0.12,
    'wholesalePrice': 0.10,
    'conversionToStorage': 1,
    'allowSellingByAmount': 1,
  });
  await db.insert('product_sale_units', {
    'productId': 44,
    'saleUnit': 'كيلو',
    'retailPrice': 120,
    'wholesalePrice': 100,
    'conversionToStorage': 1000,
    'allowSellingByAmount': 1,
  });
}

Product _testProduct() => Product(
  id: 44,
  name: 'اكياس شفاف 20*20',
  barcode: '',
  sku: '',
  category: 'أخرى',
  brand: '',
  buyPrice: 50,
  sellPrice: 120,
  quantity: 100,
  minQuantity: 0,
  description: '',
  storageUnit: 'كيلو',
  purchaseUnit: 'كيلو',
  saleUnit: 'كيلو',
  conversionFactor: 1,
  unitsPerPurchaseUnit: 1,
);

Finder _saleUnitDialog() => find.byType(AlertDialog).last;

Future<void> _pumpDatabaseWork(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
  for (var index = 0; index < 5; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openSaleUnitsSection(WidgetTester tester) async {
  final section = find.text('وحدات البيع والأسعار');
  await tester.ensureVisible(section);
  if (find.text('إضافة وحدة بيع').evaluate().isNotEmpty) return;
  await tester.tap(section);
  await tester.pumpAndSettle();
}

Future<void> _openAddUnitDialog(WidgetTester tester) async {
  final addButton = find.text('إضافة وحدة بيع');
  await tester.ensureVisible(addButton);
  await tester.tap(addButton);
  await tester.pumpAndSettle();
}

Future<void> _selectUnit(WidgetTester tester, String unit) async {
  final dialog = _saleUnitDialog();
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.byType(DropdownButtonFormField<String>),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(unit).last);
  await tester.pumpAndSettle();
}

Future<void> _enterSaleUnitFields(
  WidgetTester tester, {
  required String retail,
  required String wholesale,
  required String conversion,
}) async {
  final dialog = _saleUnitDialog();
  final fields = find.descendant(
    of: dialog,
    matching: find.byType(TextFormField),
  );
  await tester.enterText(fields.at(0), retail);
  await tester.enterText(fields.at(1), wholesale);
  await tester.enterText(fields.at(2), conversion);
}

List<String> _saleUnitFieldValues(WidgetTester tester, Finder dialog) => tester
    .widgetList<TextFormField>(
      find.descendant(of: dialog, matching: find.byType(TextFormField)),
    )
    .map((field) => field.controller!.text)
    .toList();

Future<void> _setAmountSelling(WidgetTester tester, bool enabled) async {
  final tile = find.descendant(
    of: _saleUnitDialog(),
    matching: find.byType(SwitchListTile),
  );
  final current = tester.widget<SwitchListTile>(tile).value;
  if (current != enabled) {
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }
}

Future<void> _saveSaleUnitDialog(WidgetTester tester) async {
  final dialog = _saleUnitDialog();
  await tester.tap(find.descendant(of: dialog, matching: find.text('حفظ')));
  await tester.pumpAndSettle();
}

Future<void> _editSaleUnit(WidgetTester tester, String name) async {
  final title = find.text(name).last;
  final card = find.ancestor(of: title, matching: find.byType(Card)).first;
  await tester.tap(
    find.descendant(of: card, matching: find.byIcon(Icons.edit)),
  );
  await tester.pumpAndSettle();
}
