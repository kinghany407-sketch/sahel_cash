class InventoryMovement {
  static const purchaseReceipt = 'purchase_receipt';
  static const saleIssue = 'sale_issue';
  static const salesReturn = 'sales_return';
  static const purchaseReturn = 'purchase_return';
  static const adjustmentIn = 'adjustment_in';
  static const adjustmentOut = 'adjustment_out';
  static const damage = 'damage';
  static const openingBalance = 'opening_balance';
  static const reversal = 'reversal';

  static const inbound = 'in';
  static const outbound = 'out';

  static const purchaseInvoice = 'purchase_invoice';
  static const salesInvoice = 'sales_invoice';
  static const manualAdjustment = 'manual_adjustment';
  static const invoiceReversal = 'invoice_reversal';
  static const purchaseInvoiceReversal = 'purchase_invoice_reversal';
  static const sourceSalesReturn = 'sales_return';
  static const sourcePurchaseReturn = 'purchase_return';
  static const sourceDamage = 'damage';
  static const sourceStockAdjustment = 'stock_adjustment';
  static const sourceOpeningBalance = 'opening_balance';

  static const costKnown = 'known';
  static const costUnallocated = 'unallocated';
  static const costUnknown = 'unknown';
  static const legacyUnverified = 'legacy_unverified';

  final int? id;
  final int productId;
  final int? warehouseId;
  final String movementType;
  final String direction;
  final double quantity;
  final String storageUnit;
  final double? unitCost;
  final double? totalCost;
  final String costStatus;
  final String sourceType;
  final int? sourceDocumentId;
  final int? sourceLineId;
  final String movementAt;
  final String recordedAt;
  final int? createdByUserId;
  final String? reason;
  final String? notes;
  final int? reversalOfMovementId;
  final String idempotencyKey;
  final String trackingStatus;

  const InventoryMovement({
    this.id,
    required this.productId,
    this.warehouseId,
    required this.movementType,
    required this.direction,
    required this.quantity,
    required this.storageUnit,
    this.unitCost,
    this.totalCost,
    this.costStatus = costUnknown,
    required this.sourceType,
    this.sourceDocumentId,
    this.sourceLineId,
    required this.movementAt,
    required this.recordedAt,
    this.createdByUserId,
    this.reason,
    this.notes,
    this.reversalOfMovementId,
    required this.idempotencyKey,
    this.trackingStatus = 'tracked',
  });

  Map<String, Object?> toMap() => {
    'productId': productId,
    'warehouseId': warehouseId,
    'movementType': movementType,
    'direction': direction,
    'quantity': quantity,
    'storageUnit': storageUnit,
    'unitCost': unitCost,
    'totalCost': totalCost,
    'costStatus': costStatus,
    'sourceType': sourceType,
    'sourceDocumentId': sourceDocumentId,
    'sourceLineId': sourceLineId,
    'movementAt': movementAt,
    'recordedAt': recordedAt,
    'createdByUserId': createdByUserId,
    'reason': reason,
    'notes': notes,
    'reversalOfMovementId': reversalOfMovementId,
    'idempotencyKey': idempotencyKey,
    'trackingStatus': trackingStatus,
  };

  factory InventoryMovement.fromMap(Map<String, Object?> map) =>
      InventoryMovement(
        id: map['id'] as int?,
        productId: map['productId'] as int,
        warehouseId: map['warehouseId'] as int?,
        movementType: map['movementType'] as String,
        direction: map['direction'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        storageUnit: map['storageUnit'] as String,
        unitCost: (map['unitCost'] as num?)?.toDouble(),
        totalCost: (map['totalCost'] as num?)?.toDouble(),
        costStatus: map['costStatus'] as String,
        sourceType: map['sourceType'] as String,
        sourceDocumentId: map['sourceDocumentId'] as int?,
        sourceLineId: map['sourceLineId'] as int?,
        movementAt: map['movementAt'] as String,
        recordedAt: map['recordedAt'] as String,
        createdByUserId: map['createdByUserId'] as int?,
        reason: map['reason'] as String?,
        notes: map['notes'] as String?,
        reversalOfMovementId: map['reversalOfMovementId'] as int?,
        idempotencyKey: map['idempotencyKey'] as String,
        trackingStatus: map['trackingStatus'] as String,
      );
}
