import 'purchase_invoice_item_model.dart';

class PurchaseInvoice {
  int? id;
  final String invoiceNumber;
  final int supplierId;
  final String date;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final String paymentType;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String? supplierName;
  final List<PurchaseInvoiceItem> items;

  PurchaseInvoice({
    this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.date,
    required this.subtotal,
    required this.discount,
    required this.totalAmount,
    required this.paymentType,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'supplierId': supplierId,
      'date': date,
      'subtotal': subtotal,
      'discount': discount,
      'totalAmount': totalAmount,
      'paymentType': paymentType,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    final mappedItems = map['items'] as List<dynamic>?;
    return PurchaseInvoice(
      id: map['id'],
      invoiceNumber: map['invoiceNumber'] ?? '',
      supplierId: map['supplierId'],
      date: map['date'] ?? '',
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paymentType: map['paymentType'] ?? 'cash',
      notes: map['notes'],
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? '',
      supplierName: map['supplierName'],
      items:
          mappedItems
              ?.map(
                (item) =>
                    PurchaseInvoiceItem.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}
