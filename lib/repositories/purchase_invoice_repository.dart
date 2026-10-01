import '../database/database_helper.dart';
import '../models/purchase_invoice_item_model.dart';
import '../models/purchase_invoice_model.dart';

class PurchaseInvoiceRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createPurchaseInvoice(
    PurchaseInvoice invoice,
    List<PurchaseInvoiceItem> items,
  ) async {
    return _databaseHelper.createPurchaseInvoice(
      invoice.toMap(),
      items.map((item) => item.toMap()).toList(),
    );
  }

  Future<List<PurchaseInvoice>> getAllPurchaseInvoices({
    String? query,
    int? supplierId,
  }) async {
    final maps = await _databaseHelper.getPurchaseInvoices(
      query: query,
      supplierId: supplierId,
    );
    return maps.map(PurchaseInvoice.fromMap).toList();
  }

  Future<PurchaseInvoice?> getPurchaseInvoiceById(int id) async {
    final map = await _databaseHelper.getPurchaseInvoice(id);
    if (map == null) return null;
    return PurchaseInvoice.fromMap(map);
  }

  Future<int> deletePurchaseInvoice(int id) async {
    return _databaseHelper.deletePurchaseInvoice(id);
  }

  Future<String> getNextInvoiceNumber() async {
    return _databaseHelper.getNextPurchaseInvoiceNumber();
  }
}
