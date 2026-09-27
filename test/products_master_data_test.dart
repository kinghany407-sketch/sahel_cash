import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/screens/products/categories_manager.dart';
import 'package:sahel_cash/screens/products/conversion_manager.dart';
import 'package:sahel_cash/screens/products/descriptions_manager.dart';
import 'package:sahel_cash/screens/products/units_manager.dart';

void main() {
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

    test('units manager supports add edit and delete', () {
      final manager = UnitsManager();
      manager.addUnit('عبوة');
      manager.updateUnit('عبوة', 'علبة');
      expect(manager.availableUnits, contains('علبة'));
      manager.deleteUnit('علبة');
      expect(manager.availableUnits, isNot(contains('علبة')));
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

    test('updating a unit name keeps conversion templates aligned', () {
      final unitsManager = UnitsManager();
      final conversionManager = ConversionManager();

      unitsManager.addUnit('عبوة');
      conversionManager.addTemplate('عبوة', 'قطعة', 2);

      unitsManager.updateUnit('عبوة', 'علبة');

      expect(unitsManager.availableUnits, contains('علبة'));
      expect(conversionManager.findFactor('علبة', 'قطعة'), 2);
      expect(conversionManager.findFactor('عبوة', 'قطعة'), null);
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
