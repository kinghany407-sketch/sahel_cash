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
    double? total,
    required this.isWholesale,
  }) : total = total ?? (quantity * unitPrice);

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
    final qty = (map['quantity'] ?? 0).toDouble();
    final price = (map['unitPrice'] ?? 0).toDouble();
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoiceId'] ?? 0,
      productId: map['productId'] ?? 0,
      productName: map['productName'] ?? '',
      saleUnit: map['saleUnit'] ?? '',
      quantity: qty,
      unitPrice: price,
      total: (map['total'] != null)
          ? (map['total'] as num).toDouble()
          : (qty * price),
      isWholesale: (map['isWholesale'] ?? 0) == 1,
    );
  }

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    String? saleUnit,
    double? quantity,
    double? unitPrice,
    double? total,
    bool? isWholesale,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      saleUnit: saleUnit ?? this.saleUnit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      isWholesale: isWholesale ?? this.isWholesale,
    );
  }
}

