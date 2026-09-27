// Selling helper methods for POS functionality
// Supports three selling methods:
// 1. Sell by Quantity (e.g., 2 kg, 5 pieces)
// 2. Sell by Weight (e.g., 350 grams, 1.25 kg)
// 3. Sell by Amount (e.g., 30 EGP worth of product at 100 EGP/kg)

enum SellingMethod {
  quantity,
  weight,
  amount,
}

class SellingHelper {
  /// Calculate quantity to sell based on amount
  /// 
  /// Example:
  /// Product Price: 100 EGP / kg
  /// Customer asks: 30 EGP
  /// Result: 0.3 kg
  static double calculateQuantityFromAmount(
    double amount,
    double unitPrice,
  ) {
    if (unitPrice <= 0) return 0;
    return amount / unitPrice;
  }

  /// Calculate total price for a given quantity
  static double calculateTotalPrice(
    double quantity,
    double unitPrice,
  ) {
    return quantity * unitPrice;
  }

  /// Validate if selling by amount is possible
  static bool canSellByAmount(
    double amount,
    double unitPrice,
    double availableQuantity,
  ) {
    if (unitPrice <= 0) return false;
    final requiredQuantity = calculateQuantityFromAmount(amount, unitPrice);
    return requiredQuantity <= availableQuantity;
  }

  /// Calculate quantity to reduce from stock
  /// This handles conversion between storage and sale units.
  /// If the sale unit and storage unit are the same after normalization,
  /// no conversion should be applied.
  static double calculateStockReduction(
    double soldQuantity,
    String saleUnit,
    String storageUnit,
    double conversionFactor,
  ) {
    final normalizedSaleUnit = saleUnit.trim().toLowerCase();
    final normalizedStorageUnit = storageUnit.trim().toLowerCase();

    if (normalizedSaleUnit == normalizedStorageUnit) {
      return soldQuantity;
    }

    // Convert from sale unit to storage unit.
    return soldQuantity * conversionFactor;
  }

  /// Convert quantity from one unit to another
  static double convertQuantity(
    double quantity,
    String fromUnit,
    String toUnit,
    double conversionFactor,
  ) {
    if (fromUnit == toUnit) {
      return quantity;
    }
    
    // If converting from sale unit to storage unit
    // Example: from pieces to kg, conversion factor applies
    return quantity * conversionFactor;
  }

  /// Format quantity for display
  static String formatQuantity(double quantity) {
    if (quantity == quantity.toInt()) {
      return quantity.toInt().toString();
    }
    return quantity
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  /// Validate if sale is possible given stock
  static bool isSalePossible(
    double requestedQuantity,
    double availableQuantity,
  ) {
    return requestedQuantity <= availableQuantity;
  }
}
