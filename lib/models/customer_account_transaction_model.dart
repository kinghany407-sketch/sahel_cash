class CustomerAccountTransaction {
  final int id;
  final int customerId;
  final String transactionType;
  final double amount;
  final String sourceType;
  final int? sourceDocumentId;
  final int? invoiceId;
  final String occurredAt;
  final String recordedAt;
  final String? reason;
  final String? notes;
  final int? reversalOfTransactionId;
  final String? invoiceNumber;
  final String? receiptNumber;
  final String? invoiceStatus;

  const CustomerAccountTransaction({
    required this.id,
    required this.customerId,
    required this.transactionType,
    required this.amount,
    required this.sourceType,
    this.sourceDocumentId,
    this.invoiceId,
    required this.occurredAt,
    required this.recordedAt,
    this.reason,
    this.notes,
    this.reversalOfTransactionId,
    this.invoiceNumber,
    this.receiptNumber,
    this.invoiceStatus,
  });

  factory CustomerAccountTransaction.fromMap(Map<String, dynamic> map) {
    return CustomerAccountTransaction(
      id: map['id'] as int,
      customerId: map['customerId'] as int,
      transactionType: map['transactionType'] as String,
      amount: (map['amount'] as num).toDouble(),
      sourceType: map['sourceType'] as String,
      sourceDocumentId: map['sourceDocumentId'] as int?,
      invoiceId: map['invoiceId'] as int?,
      occurredAt: map['occurredAt'] as String,
      recordedAt: map['recordedAt'] as String,
      reason: map['reason'] as String?,
      notes: map['notes'] as String?,
      reversalOfTransactionId: map['reversalOfTransactionId'] as int?,
      invoiceNumber: map['invoiceNumber'] as String?,
      receiptNumber: map['receiptNumber'] as String?,
      invoiceStatus: map['invoiceStatus'] as String?,
    );
  }
}
