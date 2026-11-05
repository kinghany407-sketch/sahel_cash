import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/screens/products/categories_manager.dart';
import 'package:sahel_cash/screens/products/conversion_manager.dart';
import 'package:sahel_cash/screens/products/descriptions_manager.dart';
import 'package:sahel_cash/screens/products/units_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory databaseDirectory;
  late Database database;

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'products-master-data-',
    );
    database = await databaseFactoryFfi.openDatabase(
      '${databaseDirectory.path}${Platform.pathSeparator}units.db',
    );
    await database.execute('''
CREATE TABLE products(
  storageUnit TEXT,
  purchaseUnit TEXT,
  saleUnit TEXT
)
''');
    await database.execute('CREATE TABLE product_sale_units(saleUnit TEXT)');
    await database.execute('CREATE TABLE invoice_items(saleUnit TEXT)');
    await database.execute(
      'CREATE TABLE purchase_invoice_items(purchaseUnit TEXT)',
    );
    await DatabaseHelper.migrateUnitMasterTable(database);
    DatabaseHelper.setDatabaseForTesting(database);
    await UnitsManager.instance.loadUnits();
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    if (database.isOpen) await database.close();
    await databaseDirectory.delete(recursive: true);
  });

  group('Product master data managers', () {
    test('categories manager supports add edit and delete', () {
      final manager = CategoriesManager();
      expect(manager.categories, contains('أخرى'));

      manager.addCategory('اختبار');
      expect(manager.categories, contains('اختبار'));

      manager.updateCategory('اختبار', 'اختبار جديد');
      expect(manager.categories, contains('اختبار جديد'));
      expect(manager.categories, isNot(contains('اختبار')));

      manager.deleteCategory('اختبار جديد');
      expect(manager.categories, isNot(contains('اختبار جديد')));
    });

    test('units manager supports add edit and delete', () async {
      final manager = UnitsManager();
      await manager.addUnit('وحدة اختبار');
      await manager.updateUnit('وحدة اختبار', 'وحدة اختبار محدثة');
      expect(manager.availableUnits, contains('وحدة اختبار محدثة'));
      expect(manager.availableUnits, isNot(contains('علبة')));
      await manager.deleteUnit('وحدة اختبار محدثة');
      expect(manager.availableUnits, isNot(contains('وحدة اختبار محدثة')));
    });

    test('conversion manager supports add edit and delete', () {
      final manager = ConversionManager();
      manager.addTemplate('كرتونة', 'قطعة', 500);
      expect(manager.findFactor('كرتونة', 'قطعة'), 500);

      manager.updateTemplate('كرتونة', 'قطعة', 600);
      expect(manager.findFactor('كرتونة', 'قطعة'), 600);

      manager.deleteTemplate('كرتونة', 'قطعة');
      expect(manager.findFactor('كرتونة', 'قطعة'), null);
    });

    test('updating a unit name keeps conversion templates aligned', () async {
      final unitsManager = UnitsManager();
      final conversionManager = ConversionManager();

      await unitsManager.addUnit('وحدة تحويل');
      conversionManager.addTemplate('وحدة تحويل', 'قطعة', 2);

      await unitsManager.updateUnit('وحدة تحويل', 'وحدة تحويل محدثة');

      expect(unitsManager.availableUnits, contains('وحدة تحويل محدثة'));
      expect(conversionManager.findFactor('وحدة تحويل محدثة', 'قطعة'), 2);
      expect(conversionManager.findFactor('وحدة تحويل', 'قطعة'), null);
      conversionManager.deleteTemplate('وحدة تحويل محدثة', 'قطعة');
    });

    test('descriptions manager supports add edit and delete', () {
      final manager = DescriptionsManager();
      manager.addDescription('وصف تجريبي');
      expect(manager.descriptions, contains('وصف تجريبي'));
      manager.updateDescription('وصف تجريبي', 'وصف محدث');
      expect(manager.descriptions, contains('وصف محدث'));
      manager.deleteDescription('وصف محدث');
      expect(manager.descriptions, isNot(contains('وصف محدث')));
    });
  });
}
