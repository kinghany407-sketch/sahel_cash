import '../models/product_model.dart';
import '../models/product_sale_unit_model.dart';

class ProductCostCalculator {
  static bool _isSubUnit(String candidateSub, String candidateSuper) {
    final sub = candidateSub.trim().toLowerCase();
    final sup = candidateSuper.trim().toLowerCase();
    if (sub == sup || sub.isEmpty || sup.isEmpty) return false;

    const smallUnits = [
      'قطعة',
      'قطعه',
      'حبه',
      'حبة',
      'طبق',
      'كوب',
      'قرص',
      'علبة',
      'علبه',
      'جرام',
      'جم',
      'piece',
      'unit',
      'item',
      'plate',
      'cup',
      'gram',
      'g',
    ];
    const largeUnits = [
      'كرتونة',
      'كرتونه',
      'كرتون',
      'لفة',
      'لفه',
      'عامود',
      'عمود',
      'باكت',
      'بكت',
      'صندوق',
      'شيكارة',
      'شكارة',
      'شوال',
      'دسته',
      'دستة',
      'طرد',
      'كيلو',
      'كجم',
      'box',
      'carton',
      'pack',
      'package',
      'bundle',
      'roll',
      'bag',
      'sack',
      'kg',
      'kilo',
    ];

    return smallUnits.any((unit) => sub.contains(unit)) &&
        largeUnits.any((unit) => sup.contains(unit));
  }

  static double? costPerStorageUnit(
    Product? product,
    Map<String, ProductSaleUnit> saleUnits,
  ) {
    if (product == null ||
        !product.buyPrice.isFinite ||
        product.buyPrice <= 0) {
      return null;
    }

    final purchaseUnit = product.purchaseUnit.trim().toLowerCase();
    final storageUnit = product.storageUnit.trim().toLowerCase();
    if (purchaseUnit == storageUnit ||
        purchaseUnit.isEmpty ||
        storageUnit.isEmpty) {
      return product.buyPrice;
    }

    if ((purchaseUnit.contains('كيلو') || purchaseUnit.contains('kg')) &&
        (storageUnit.contains('جرام') || storageUnit.contains('gram'))) {
      return product.buyPrice / 1000;
    }
    if ((purchaseUnit.contains('جرام') || purchaseUnit.contains('gram')) &&
        (storageUnit.contains('كيلو') || storageUnit.contains('kg'))) {
      return product.buyPrice * 1000;
    }

    var factor = product.unitsPerPurchaseUnit > 1
        ? product.unitsPerPurchaseUnit.toDouble()
        : (product.conversionFactor > 1 ? product.conversionFactor : 1);

    if (factor <= 1 && _isSubUnit(storageUnit, purchaseUnit)) {
      final saleUnit = saleUnits['${product.id}_$purchaseUnit'];
      if (saleUnit != null && saleUnit.conversionToStorage > 1) {
        factor = saleUnit.conversionToStorage;
      }
    }

    final cost = factor > 1 ? product.buyPrice / factor : product.buyPrice;
    return cost.isFinite && cost >= 0 ? cost : null;
  }

  static double? storageQuantity(
    Product? product,
    String saleUnit,
    double quantity,
    Map<String, ProductSaleUnit> saleUnits,{double? savedConversionToStorage}
  ) {
    if (product == null) return quantity;

    final normalizedSaleUnit = saleUnit.trim().toLowerCase();
    final storageUnit = product.storageUnit.trim().toLowerCase();
    if (normalizedSaleUnit == storageUnit) return quantity;

    // Use saved conversionToStorage from invoice if available
    if (savedConversionToStorage != null && savedConversionToStorage > 0) {
      return quantity * savedConversionToStorage;
    }

    // If no saved conversionToStorage, return null to indicate incomplete data
    // Do NOT use fallback from current product settings
    return null;
  }

  static double? itemCost(
    Product? product,
    String saleUnit,
    double quantity,
    Map<String, ProductSaleUnit> saleUnits,{double? savedConversionToStorage}
  ) {
    final costPerUnit = costPerStorageUnit(product, saleUnits);
    if (costPerUnit == null || !quantity.isFinite || quantity < 0) return null;

    final storageQty = storageQuantity(
      product,
      saleUnit,
      quantity,
      saleUnits,
      savedConversionToStorage: savedConversionToStorage,
    );

    // If storageQuantity is null, return null to indicate incomplete data
    if (storageQty == null) return null;

    final cost = costPerUnit * storageQty;
    return cost.isFinite && cost >= 0 ? cost : null;
  }
}
