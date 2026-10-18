class Invoice {
  int? id;
  final String invoiceNumber;
  final String date;
  final double total;
  final String paymentMethod;
  final int? customerId;
  final String? notes;
  final int? cashierId;
  final String? cashierName;
  final double discount;
  final String? discountType;
  final double paidAmount;
  final double changeAmount;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    required this.total,
    this.paymentMethod = 'cash',
    this.customerId,
    this.notes,
    this.cashierId,
    this.cashierName,
    this.discount = 0.0,
    this.discountType,
    this.paidAmount = 0.0,
    this.changeAmount = 0.0,
  });

  int? get createdBy => cashierId;
  String? get createdByName => cashierName;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': date,
      'total': total,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'notes': notes,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'discount': discount,
      'discountType': discountType,
      'paidAmount': paidAmount,
      'changeAmount': changeAmount,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoiceNumber'] ?? '',
      date: map['date'] ?? DateTime.now().toIso8601String(),
      total: (map['total'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'cash',
      customerId: map['customerId'],
      notes: map['notes'],
      cashierId: map['cashierId'] ?? map['createdBy'],
      cashierName: map['cashierName'] ?? map['createdByName'],
      discount: (map['discount'] ?? 0.0).toDouble(),
      discountType: map['discountType'],
      paidAmount: (map['paidAmount'] ?? 0.0).toDouble(),
      changeAmount: (map['changeAmount'] ?? 0.0).toDouble(),
    );
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    String? date,
    double? total,
    String? paymentMethod,
    int? customerId,
    String? notes,
    int? cashierId,
    String? cashierName,
    double? discount,
    String? discountType,
    double? paidAmount,
    double? changeAmount,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      date: date ?? this.date,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      notes: notes ?? this.notes,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
    );
  }
}

