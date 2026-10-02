import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/expense_model.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';
import 'add_expense_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseRepository _repository = ExpenseRepository();
  List<Expense> _expenses = [];
  bool _isLoading = true;

  double get _total =>
      _expenses.fold(0, (sum, expense) => sum + expense.amount);

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final expenses = await _repository.getAllExpenses();
      if (mounted) setState(() => _expenses = expenses);
    } catch (error) {
      if (mounted) _showMessage('تعذر تحميل المصروفات: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showExpenseDialog({Expense? expense}) async {
    final created = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, _, _) => AddExpenseDialog(expense: expense),
    );
    if (created == true && mounted) {
      await _loadExpenses();
      if (mounted) {
        _showMessage(expense == null ? 'تم حفظ المصروف' : 'تم تعديل المصروف');
      }
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.id == null) return;
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableDialog(
          title: 'حذف المصروف',
          width: 420,
          height: 240,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'حذف مصروف ${expense.amount.toStringAsFixed(2)} ج.م من فئة ${expense.category}؟',
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('رجوع'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppStyles.errorColor,
                        ),
                        child: const Text('حذف'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteExpense(expense.id!);
      if (mounted) {
        await _loadExpenses();
        if (mounted) _showMessage('تم حذف المصروف');
      }
    } catch (error) {
      if (mounted) _showMessage('تعذر حذف المصروف: $error', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppStyles.errorColor
            : AppStyles.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.backgroundColor,
        appBar: AppBar(title: const Text('المصروفات'), centerTitle: true),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('إجمالي المصروفات'),
                                const SizedBox(height: 4),
                                Text(
                                  '${_total.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppStyles.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _showExpenseDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة مصروف'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _expenses.isEmpty
                      ? const Center(child: Text('لا توجد مصروفات مسجلة'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _expenses.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _buildExpenseTile(_expenses[index]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
        title: Text(expense.category),
        subtitle: Text(
          expense.notes?.isNotEmpty == true
              ? '${_formatDate(expense.date)} • ${expense.notes}'
              : _formatDate(expense.date),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: math.min(170, MediaQuery.sizeOf(context).width * 0.32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '${expense.amount.toStringAsFixed(2)} ج.م',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppStyles.errorColor,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'تعديل المصروف',
                onPressed: () => _showExpenseDialog(expense: expense),
                icon: const Icon(Icons.edit_outlined, color: Colors.orange),
              ),
              IconButton(
                tooltip: 'حذف المصروف',
                onPressed: () => _deleteExpense(expense),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppStyles.errorColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
