class InvoiceItem {
  int? id;
  final int invoiceId;
  final int productId;
  final String productName;
  final String saleUnit;
  final double quantity;
  final double unitPrice;
  final double total;
  final bool isWholesale;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.saleUnit,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.isWholesale,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'productId': productId,
      'productName': productName,
      'saleUnit': saleUnit,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
      'isWholesale': isWholesale ? 1 : 0,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoiceId'] ?? 0,
      productId: map['productId'] ?? 0,
      productName: map['productName'] ?? '',
      saleUnit: map['saleUnit'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      isWholesale: (map['isWholesale'] ?? 0) == 1,
    );
  }
}
