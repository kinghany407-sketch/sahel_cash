class Invoice {
  int? id;
  final String invoiceNumber;
  final String date;
  final double total;
  final String paymentMethod;
  final int? customerId;
  final String? notes;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    required this.total,
    this.paymentMethod = 'cash',
    this.customerId,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': date,
      'total': total,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'notes': notes,
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
    );
  }
}
