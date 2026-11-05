import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/models/product_model.dart';
import 'package:sahel_cash/utils/product_cost_calculator.dart';
import 'package:sahel_cash/utils/sales_cost_summary.dart';

void main() {
  test('missing product cost makes aggregate cost and profit incomplete', () {
    final summary = SalesCostSummary()
      ..addCost(ProductCostCalculator.itemCost(null, 'قطعة', 2, {}));

    expect(summary.isComplete, isFalse);
    expect(summary.unknownCostCount, 1);
    expect(summary.totalCost, isNull);
    expect(summary.profitFor(100), isNull);
  });

  test('a product without a valid purchase price has unknown cost', () {
    final product = Product(
      id: 8,
      name: 'منتج',
      barcode: '',
      sku: '',
      category: '',
      brand: '',
      buyPrice: 0,
      sellPrice: 20,
      quantity: 3,
      minQuantity: 0,
      description: '',
      storageUnit: 'قطعة',
      purchaseUnit: 'قطعة',
    );

    expect(ProductCostCalculator.itemCost(product, 'قطعة', 1, {}), isNull);
  });

  test('a known zero-cost result is not confused with an unknown cost', () {
    final summary = SalesCostSummary()..addCost(0);

    expect(summary.isComplete, isTrue);
    expect(summary.totalCost, 0);
    expect(summary.profitFor(100), 100);
  });

  test('a known product cost is calculated and aggregated', () {
    final product = Product(
      id: 8,
      name: 'منتج',
      barcode: '',
      sku: '',
      category: '',
      brand: '',
      buyPrice: 12,
      sellPrice: 20,
      quantity: 3,
      minQuantity: 0,
      description: '',
      storageUnit: 'قطعة',
      purchaseUnit: 'قطعة',
    );
    final summary = SalesCostSummary()
      ..addCost(ProductCostCalculator.itemCost(product, 'قطعة', 2, {}))
      ..addCost(ProductCostCalculator.itemCost(product, 'قطعة', 1, {}));

    expect(summary.isComplete, isTrue);
    expect(summary.totalCost, 36);
    expect(summary.profitFor(60), 24);
  });

  test('no line items can be marked as unknown instead of free cost', () {
    final summary = SalesCostSummary()..addCost(null);

    expect(summary.totalCost, isNull);
    expect(summary.profitFor(50), isNull);
  });
}
