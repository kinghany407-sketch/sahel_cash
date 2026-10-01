import '../database/database_helper.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createSupplier(Supplier supplier) async {
    return await _databaseHelper.insertSupplier(supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final maps = await _databaseHelper.getSuppliers();
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final map = await _databaseHelper.getSupplierById(id);
    if (map == null) return null;
    return Supplier.fromMap(map);
  }

  Future<List<Supplier>> searchSuppliers(String query) async {
    final maps = await _databaseHelper.searchSuppliers(query);
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  Future<int> updateSupplier(Supplier supplier) async {
    return await _databaseHelper.updateSupplier(supplier.toMap());
  }

  Future<int> deleteSupplier(int id) async {
    return await _databaseHelper.deleteSupplier(id);
  }
}