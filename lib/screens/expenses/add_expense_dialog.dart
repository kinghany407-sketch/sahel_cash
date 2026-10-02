import 'package:flutter/material.dart';

import '../../models/expense_model.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class AddExpenseDialog extends StatefulWidget {
  final Expense? expense;

  const AddExpenseDialog({super.key, this.expense});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final ExpenseRepository _repository = ExpenseRepository();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customCategoryController =
      TextEditingController();

  String _category = Expense.categories.first;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense == null) return;

    _amountController.text = expense.amount.toStringAsFixed(2);
    _notesController.text = expense.notes ?? '';
    _date = DateTime.tryParse(expense.date) ?? DateTime.now();
    if (Expense.categories.contains(expense.category)) {
      _category = expense.category;
    } else {
      _category = 'أخرى';
      _customCategoryController.text = expense.category;
    }
  }

  Future<void> _pickDate() async {
    final selectedDate = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          Directionality(
            textDirection: TextDirection.rtl,
            child: DraggableDialog(
              title: 'تاريخ المصروف',
              width: 380,
              height: 440,
              child: Column(
                children: [
                  Expanded(
                    child: CalendarDatePicker(
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      onDateChanged: (date) =>
                          Navigator.of(dialogContext).pop(date),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (selectedDate != null && mounted) {
      setState(() => _date = selectedDate);
    }
  }

  Future<void> _saveExpense() async {
    final customCategory = _customCategoryController.text.trim();
    if (_category == 'أخرى' && customCategory.isEmpty) {
      _showError('اكتب اسم الفئة المخصصة');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغًا أكبر من صفر');
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now().toIso8601String();
    final expense = Expense(
      id: widget.expense?.id,
      category: _category == 'أخرى' ? customCategory : _category,
      amount: amount,
      date: _date.toIso8601String(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.expense?.createdAt ?? now,
    );
    try {
      if (_isEditing) {
        await _repository.updateExpense(expense);
      } else {
        await _repository.createExpense(expense);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError('تعذر حفظ المصروف: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppStyles.errorColor),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: _isEditing ? 'تعديل مصروف' : 'إضافة مصروف',
        width: 520,
        height: 540,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'الفئة *',
                    border: OutlineInputBorder(),
                  ),
                  items: Expense.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (category) {
                    if (category != null) setState(() => _category = category);
                  },
                ),
                if (_category == 'أخرى') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الفئة المخصصة *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ *',
                    suffixText: 'ج.م',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('التاريخ: ${_formatDate(_date)}'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveExpense,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isEditing ? 'حفظ التعديلات' : 'حفظ المصروف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }
}
