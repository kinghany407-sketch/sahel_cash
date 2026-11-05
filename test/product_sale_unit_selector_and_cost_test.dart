import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/models/product_model.dart';
import 'package:sahel_cash/models/product_sale_unit_model.dart';
import 'package:sahel_cash/screens/cashier/cashier_screen.dart';
import 'package:sahel_cash/utils/cashier_sale_unit_labels.dart';
import 'package:sahel_cash/utils/product_cost_calculator.dart';
import 'package:sahel_cash/widgets/product_sale_unit_selector.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('dropdown lists registered units with their available prices', (
    tester,
  ) async {
    final units = [
      ProductSaleUnit(
        productId: 49,
        saleUnit: 'كوب',
        retailPrice: 3,
        conversionToStorage: 1,
      ),
      ProductSaleUnit(
        productId: 49,
        saleUnit: 'عامود',
        retailPrice: null,
        wholesalePrice: 85,
        conversionToStorage: 50,
      ),
      ProductSaleUnit(
        productId: 49,
        saleUnit: 'كيلو',
        retailPrice: 120,
        wholesalePrice: 100,
        conversionToStorage: 1000,
      ),
      ProductSaleUnit(
        productId: 49,
        saleUnit: 'طبق',
        retailPrice: 12,
        conversionToStorage: 10,
      ),
    ];
    ProductSaleUnit? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ProductSaleUnitSelector(
              units: units,
              selectedUnit: selected,
              onSelected: (unit) => setState(() => selected = unit),
            ),
          ),
        ),
      ),
    );

    final dropdown = find.byType(DropdownButtonFormField<ProductSaleUnit>);
    expect(dropdown, findsOneWidget);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    expect(find.text('كوب — قطاعي 3.00 ج.م'), findsOneWidget);
    expect(find.text('عامود — جملة 85.00 ج.م'), findsOneWidget);
    expect(
      find.text('كيلو — قطاعي 120.00 ج.م — جملة 100.00 ج.م'),
      findsOneWidget,
    );
    expect(find.text('طبق — قطاعي 12.00 ج.م'), findsOneWidget);

    await tester.tap(find.text('عامود — جملة 85.00 ج.م'));
    await tester.pumpAndSettle();
    expect(selected?.saleUnit, 'عامود');
  });

  test('sale prices, totals, and labels follow each selected unit', () {
    final product = Product(
      id: 49,
      name: 'اختبار',
      barcode: '',
      sku: '',
      category: '',
      brand: '',
      buyPrice: 0,
      sellPrice: 0,
      quantity: 100,
      minQuantity: 0,
      description: '',
    );
    final cases = [
      (unit: 'كوب', retail: 3.0, wholesale: false),
      (unit: 'عامود', retail: 85.0, wholesale: true),
      (unit: 'كيلو', retail: 120.0, wholesale: false),
      (unit: 'طبق', retail: 12.0, wholesale: false),
    ];

    for (final testCase in cases) {
      final saleUnit = ProductSaleUnit(
        productId: 49,
        saleUnit: testCase.unit,
        retailPrice: testCase.wholesale ? null : testCase.retail,
        wholesalePrice: testCase.wholesale ? testCase.retail : null,
        conversionToStorage: 1,
      );
      final item = CartItem(
        product: product,
        selectedSaleUnit: saleUnit,
        storageUnitsPerSaleUnit: 1,
        quantity: 2,
        isWholesale: testCase.wholesale,
      );

      expect(item.unitPrice, testCase.retail);
      expect(item.total, testCase.retail * 2);
      expect(
        CashierSaleUnitLabels.price(testCase.unit),
        'سعر ${testCase.unit}',
      );
      expect(
        CashierSaleUnitLabels.quantity(testCase.unit),
        'الكمية بوحدة ${testCase.unit}',
      );
    }
  });

  test('isolated database units calculate expected column cost', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());
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
    final cup = ProductSaleUnit(
      productId: 49,
      saleUnit: 'كوب',
      retailPrice: 3,
      conversionToStorage: 1,
    );
    final dbColumn = ProductSaleUnit(
      productId: 49,
      saleUnit: 'عامود',
      retailPrice: null,
      wholesalePrice: 85,
      conversionToStorage: 50,
    );
    await db.insert('product_sale_units', cup.toMap());
    await db.insert('product_sale_units', dbColumn.toMap());
    final units = (await db.query(
      'product_sale_units',
    )).map(ProductSaleUnit.fromMap).toList();
    expect(units, hasLength(2));
    final product = Product(
      id: 49,
      name: 'كوب شفاف بغطاء',
      barcode: '',
      sku: '',
      category: '',
      brand: '',
      buyPrice: 1500,
      sellPrice: 3,
      quantity: 1000,
      minQuantity: 0,
      description: '',
      storageUnit: 'كوب',
      purchaseUnit: 'كرتونة',
      unitsPerPurchaseUnit: 1000,
    );
    final unitMap = {
      for (final unit in units)
        '${unit.productId}_${unit.saleUnit.trim().toLowerCase()}': unit,
    };
    final cost = ProductCostCalculator.itemCost(product, 'عامود', 1, unitMap);

    expect(cost, 75);
    expect(85 - cost!, 10);
  });
}
