double calculateStorageQuantity({
  required double quantity,
  required String saleUnit,
  required String storageUnit,
  required double conversionToStorage,
}) {
  final normalizedStorageUnit = storageUnit.trim().toLowerCase();
  final normalizedSaleUnit = saleUnit.trim().toLowerCase();

  if (normalizedSaleUnit == normalizedStorageUnit) {
    return quantity;
  }

  if ((normalizedStorageUnit.contains('كيلو') ||
          normalizedStorageUnit.contains('kg')) &&
      (normalizedSaleUnit.contains('جرام') ||
          normalizedSaleUnit.contains('gram'))) {
    return quantity * 0.001;
  }

  if ((normalizedStorageUnit.contains('جرام') ||
          normalizedStorageUnit.contains('gram')) &&
      (normalizedSaleUnit.contains('كيلو') ||
          normalizedSaleUnit.contains('kg'))) {
    return quantity * 1000;
  }

  return quantity * conversionToStorage;
}
