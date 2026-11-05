import '../../database/database_helper.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';

class InvoiceRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  @Deprecated(
    'Use createInvoiceWithItems to record inventory and account effects',
  )
  Future<int> createInvoice(Invoice invoice) async {
    throw StateError(
      'Invoices must be created with their items through createInvoiceWithItems',
    );
  }

  @Deprecated(
    'Use createInvoiceWithItems to record inventory and account effects',
  )
  Future<int> createInvoiceItem(InvoiceItem item) async {
    throw StateError(
      'Invoice items must be created with their invoice through createInvoiceWithItems',
    );
  }

  Future<int> createInvoiceWithItems({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required Map<int, double> stockReductions,
  }) {
    return _databaseHelper.createSalesInvoiceWithItems(
      invoice: invoice,
      items: items,
      stockReductions: stockReductions,
    );
  }

  Future<List<Invoice>> getInvoicesForCustomer(
    int customerId, {
    bool creditOnly = false,
    bool includeVoided = false,
  }) async {
    final db = await _databaseHelper.database;
    final filters = <String>['customerId = ?'];
    final args = <Object?>[customerId];
    if (creditOnly) {
      filters.add('paymentMethod = ?');
      args.add('credit');
    }
    if (!includeVoided) filters.add("status != 'voided'");
    final maps = await db.query(
      'invoices',
      where: filters.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return maps.map(Invoice.fromMap).toList();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Invoice.fromMap(maps.first);
  }

  Future<List<Invoice>> getAllInvoices({
    int limit = 20,
    int offset = 0,
    bool includeVoided = true,
  }) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'invoices',
      where: includeVoided ? null : "status != 'voided'",
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (index) => Invoice.fromMap(maps[index]));
  }

  Future<List<Invoice>> getTodayInvoices({bool includeVoided = true}) async {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'invoices',
      where: includeVoided
          ? 'date LIKE ?'
          : "date LIKE ? AND status != 'voided'",
      whereArgs: ['$todayStr%'],
      orderBy: 'id DESC',
    );

    return List.generate(maps.length, (index) => Invoice.fromMap(maps[index]));
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );

    return List.generate(
      maps.length,
      (index) => InvoiceItem.fromMap(maps[index]),
    );
  }

  Future<void> cancelInvoice(int invoiceId, {required String reason}) {
    return _databaseHelper.cancelSalesInvoiceWithEffects(
      invoiceId,
      reason: reason,
    );
  }
}
