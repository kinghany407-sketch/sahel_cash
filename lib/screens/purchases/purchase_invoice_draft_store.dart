import '../../models/purchase_invoice_item_model.dart';

class PurchaseInvoiceDraft {
  final int? supplierId;
  final String date;
  final String paymentType;
  final String discountText;
  final String notes;
  final List<PurchaseInvoiceItem> items;
  final int? selectedProductId;
  final String productSearchText;
  final String? selectedUnit;
  final String quantityText;
  final String unitPriceText;
  final Map<String, String> unitPrices;

  const PurchaseInvoiceDraft({
    this.supplierId,
    this.date = '',
    this.paymentType = 'cash',
    this.discountText = '0',
    this.notes = '',
    this.items = const [],
    this.selectedProductId,
    this.productSearchText = '',
    this.selectedUnit,
    this.quantityText = '1',
    this.unitPriceText = '',
    this.unitPrices = const {},
  });
}

class PurchaseInvoiceDraftStore {
  PurchaseInvoiceDraftStore._();

  static final PurchaseInvoiceDraftStore instance =
      PurchaseInvoiceDraftStore._();

  PurchaseInvoiceDraft? _draft;

  PurchaseInvoiceDraft? get draft => _draft;

  void save(PurchaseInvoiceDraft draft) {
    _draft = draft;
  }

  void clear() {
    _draft = null;
  }
}
