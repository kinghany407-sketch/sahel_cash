import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';

class InvoiceRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createInvoice(Invoice invoice) async {
    final db = await _databaseHelper.database;
    return await db.insert('invoices', invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> createInvoiceItem(InvoiceItem item) async {
    final db = await _databaseHelper.database;
    return await db.insert('invoice_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<List<Invoice>> getAllInvoices({int limit = 20, int offset = 0}) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'invoices',
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
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

    return List.generate(maps.length, (index) => InvoiceItem.fromMap(maps[index]));
  }

  Future<void> deleteInvoiceItemsByInvoiceId(int invoiceId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'invoice_items',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<void> deleteInvoice(int invoiceId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }
}
