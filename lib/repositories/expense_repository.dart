import '../database/database_helper.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createExpense(Expense expense) {
    return _databaseHelper.createExpense(expense.toMap());
  }

  Future<int> updateExpense(Expense expense) {
    return _databaseHelper.updateExpense(expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final rows = await _databaseHelper.getExpenses();
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> deleteExpense(int id) {
    return _databaseHelper.deleteExpense(id);
  }
}
