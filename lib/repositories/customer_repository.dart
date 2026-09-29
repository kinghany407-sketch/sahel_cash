import '../database/database_helper.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createCustomer(Customer customer) async {
    return await _databaseHelper.insertCustomer(customer.toMap());
  }

  Future<List<Customer>> getAllCustomers() async {
    final maps = await _databaseHelper.getCustomers();
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final map = await _databaseHelper.getCustomerById(id);
    if (map == null) return null;
    return Customer.fromMap(map);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final maps = await _databaseHelper.searchCustomers(query);
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<int> updateCustomer(Customer customer) async {
    return await _databaseHelper.updateCustomer(customer.toMap());
  }

  Future<int> deleteCustomer(int id) async {
    return await _databaseHelper.deleteCustomer(id);
  }

  Future<int> updateCustomerBalance(int customerId, double amount) async {
    return await _databaseHelper.updateCustomerBalance(customerId, amount);
  }
}
