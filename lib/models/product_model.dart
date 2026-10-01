class Product {
  int? id;

  String name;
  String barcode;
  String sku;

  String category;
  String brand;
  String supplier;

  double buyPrice;
  double sellPrice;

  double quantity;
  double minQuantity;

  String description;
  String imagePath;

  String storageUnit;
  String purchaseUnit;
  String saleUnit;
  double conversionFactor;
  int unitsPerPurchaseUnit;

  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.sku,
    required this.category,
    required this.brand,
    this.supplier = '',
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
    required this.minQuantity,
    required this.description,
    this.imagePath = '',
    this.storageUnit = 'قطعة',
    this.purchaseUnit = 'قطعة',
    this.saleUnit = 'قطعة',
    this.conversionFactor = 1,
    this.unitsPerPurchaseUnit = 1,
  });

  bool get isLowStock => quantity <= minQuantity;

  String get displayQuantity {
    if (quantity == quantity.toInt()) {
      return quantity.toInt().toString();
    }
    return quantity
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  double get profit => sellPrice - buyPrice;

  double get profitPercent {
    if (buyPrice == 0) return 0;
    return ((sellPrice - buyPrice) / buyPrice) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'sku': sku,
      'purchasePrice': buyPrice,
      'salePrice': sellPrice,
      'quantity': quantity,
      'minimumQuantity': minQuantity,
      'category': category,
      'brand': brand,
      'supplier': supplier,
      'description': description,
      'imagePath': imagePath,
      'storageUnit': storageUnit,
      'purchaseUnit': purchaseUnit,
      'saleUnit': saleUnit,
      'conversionFactor': conversionFactor,
      'unitsPerPurchaseUnit': unitsPerPurchaseUnit,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'] ?? '',
      barcode: map['barcode'] ?? '',
      sku: map['sku'] ?? '',
      category: map['category'] ?? '',
      brand: map['brand'] ?? '',
      supplier: map['supplier'] ?? '',
      buyPrice: (map['purchasePrice'] ?? 0).toDouble(),
      sellPrice: (map['salePrice'] ?? 0).toDouble(),
      quantity: (map['quantity'] ?? 0).toDouble(),
      minQuantity: (map['minimumQuantity'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      imagePath: map['imagePath'] ?? '',
      storageUnit: map['storageUnit'] ?? map['purchaseUnit'] ?? 'قطعة',
      purchaseUnit: map['purchaseUnit'] ?? 'قطعة',
      saleUnit: map['saleUnit'] ?? map['unit'] ?? 'قطعة',
      conversionFactor: (map['conversionFactor'] ?? 1).toDouble(),
      unitsPerPurchaseUnit: (map['unitsPerPurchaseUnit'] as num?)?.toInt() ?? 1,
    );
  }
}
