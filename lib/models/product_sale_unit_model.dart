class ProductSaleUnit {
  int? id;
  final int productId;
  final String saleUnit;
  final double retailPrice;
  final double? wholesalePrice;
  final double conversionToStorage;
  final bool allowSellingByAmount;

  ProductSaleUnit({
    this.id,
    required this.productId,
    required this.saleUnit,
    required this.retailPrice,
    this.wholesalePrice,
    required this.conversionToStorage,
    this.allowSellingByAmount = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'saleUnit': saleUnit,
      'retailPrice': retailPrice,
      'wholesalePrice': wholesalePrice,
      'conversionToStorage': conversionToStorage,
      'allowSellingByAmount': allowSellingByAmount ? 1 : 0,
    };
  }

  factory ProductSaleUnit.fromMap(Map<String, dynamic> map) {
    return ProductSaleUnit(
      id: map['id'],
      productId: map['productId'] as int,
      saleUnit: map['saleUnit'] as String,
      retailPrice: (map['retailPrice'] ?? 0).toDouble(),
      wholesalePrice: map['wholesalePrice'] != null
          ? (map['wholesalePrice'] as num).toDouble()
          : null,
      conversionToStorage: (map['conversionToStorage'] ?? 1).toDouble(),
      allowSellingByAmount: (map['allowSellingByAmount'] ?? 0) == 1,
    );
  }
}
