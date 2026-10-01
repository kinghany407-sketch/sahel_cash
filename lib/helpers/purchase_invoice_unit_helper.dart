class PurchaseInvoiceUnitHelper {
  const PurchaseInvoiceUnitHelper._();

  static List<String> availableUnits({
    required String purchaseUnit,
    required String storageUnit,
  }) {
    return [
      purchaseUnit,
      storageUnit,
    ].where((unit) => unit.trim().isNotEmpty).toSet().toList();
  }

  static double conversionFactorToStorage({
    required String invoiceUnit,
    required String purchaseUnit,
    required String storageUnit,
    required double unitsPerPurchaseUnit,
  }) {
    if (invoiceUnit == storageUnit) return 1;
    if (invoiceUnit == purchaseUnit && unitsPerPurchaseUnit > 0) {
      return unitsPerPurchaseUnit;
    }
    throw ArgumentError('Unsupported purchase invoice unit: $invoiceUnit');
  }
}
