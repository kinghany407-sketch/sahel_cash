class Product {
  String name;
  String barcode;
  String sku;
  String category;
  String brand;

  double buyPrice;
  double sellPrice;

  int quantity;
  int minQuantity;

  String description;

  Product({
    required this.name,
    required this.barcode,
    required this.sku,
    required this.category,
    required this.brand,
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
    required this.minQuantity,
    required this.description,
  });

  double get profit => sellPrice - buyPrice;

  double get profitPercent {
    if (buyPrice == 0) return 0;
    return ((sellPrice - buyPrice) / buyPrice) * 100;
  }
}