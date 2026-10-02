class ReceiptVoucher {
  int? id;
  final String voucherNumber;
  final int customerId;
  final int? invoiceId;
  final String date;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final String createdAt;
  final String? invoiceNumber;

  ReceiptVoucher({
    this.id,
    required this.voucherNumber,
    required this.customerId,
    this.invoiceId,
    required this.date,
    required this.amount,
    this.paymentMethod = 'cash',
    this.notes,
    required this.createdAt,
    this.invoiceNumber,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'voucherNumber': voucherNumber,
    'customerId': customerId,
    'invoiceId': invoiceId,
    'date': date,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory ReceiptVoucher.fromMap(Map<String, dynamic> map) {
    return ReceiptVoucher(
      id: map['id'],
      voucherNumber: map['voucherNumber'] ?? '',
      customerId: map['customerId'],
      invoiceId: map['invoiceId'],
      date: map['date'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'cash',
      notes: map['notes'],
      createdAt: map['createdAt'] ?? '',
      invoiceNumber: map['invoiceNumber'],
    );
  }
}
