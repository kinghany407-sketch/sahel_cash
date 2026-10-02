import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/models/expense_model.dart';
import 'package:sahel_cash/repositories/expense_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  final repository = ExpenseRepository();

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
CREATE TABLE expenses(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount > 0),
  date TEXT NOT NULL,
  notes TEXT,
  createdAt TEXT NOT NULL
)
''');
    DatabaseHelper.setDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  test('approved expense categories are available', () {
    expect(Expense.categories, [
      'إيجار',
      'رواتب',
      'فواتير',
      'مشتريات تشغيلية',
      'نقل',
      'أخرى',
    ]);
  });

  test('expense fields are persisted and returned newest date first', () async {
    final firstId = await repository.createExpense(
      Expense(
        category: 'إيجار',
        amount: 2500,
        date: '2026-10-01T00:00:00.000',
        notes: 'المحل',
        createdAt: '2026-10-01T10:00:00.000',
      ),
    );
    await repository.createExpense(
      Expense(
        category: 'نقل',
        amount: 125,
        date: '2026-10-02T00:00:00.000',
        createdAt: '2026-10-02T10:00:00.000',
      ),
    );

    final expenses = await repository.getAllExpenses();
    expect(expenses, hasLength(2));
    expect(expenses.first.category, 'نقل');
    expect(expenses.last.id, firstId);
    expect(expenses.last.amount, 2500);
    expect(expenses.last.notes, 'المحل');
  });

  test('expense can be deleted', () async {
    final id = await repository.createExpense(
      Expense(
        category: 'فواتير',
        amount: 400,
        date: '2026-10-02',
        createdAt: '2026-10-02',
      ),
    );

    expect(await repository.deleteExpense(id), 1);
    expect(await repository.getAllExpenses(), isEmpty);
  });

  test('expense can be edited with a custom category', () async {
    final id = await repository.createExpense(
      Expense(
        category: 'أخرى',
        amount: 100,
        date: '2026-10-02',
        createdAt: '2026-10-02',
      ),
    );

    await repository.updateExpense(
      Expense(
        id: id,
        category: 'صيانة معدات',
        amount: 175,
        date: '2026-10-03',
        notes: 'إصلاح جهاز',
        createdAt: '2026-10-02',
      ),
    );

    final expenses = await repository.getAllExpenses();
    expect(expenses, hasLength(1));
    expect(expenses.single.id, id);
    expect(expenses.single.category, 'صيانة معدات');
    expect(expenses.single.amount, 175);
    expect(expenses.single.notes, 'إصلاح جهاز');
  });

  test('database rejects zero and negative expense amounts', () async {
    for (final amount in [0.0, -1.0]) {
      await expectLater(
        repository.createExpense(
          Expense(
            category: 'أخرى',
            amount: amount,
            date: '2026-10-02',
            createdAt: '2026-10-02',
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    }
    expect(await repository.getAllExpenses(), isEmpty);
  });
}
