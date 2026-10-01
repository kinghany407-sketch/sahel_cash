class PurchaseInvoiceItem {
  int? id;
  int? invoiceId;
  final int productId;
  final double quantity;
  final double unitPrice;
  final double total;
  final String? productName;

  PurchaseInvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.productName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceItem(
      id: map['id'],
      invoiceId: map['invoiceId'],
      productId: map['productId'],
      quantity: (map['quantity'] ?? 0).toDouble(),
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      productName: map['productName'],
    );
  }
}
