import 'package:flutter/material.dart';

import '../../models/customer_model.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class AddCustomerDialog extends StatefulWidget {
  final Customer? customer;

  const AddCustomerDialog({super.key, this.customer});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final CustomerRepository _repository = CustomerRepository();
  final DraggableDialogController _dialogController = DraggableDialogController();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone ?? '';
      _addressController.text = widget.customer!.address ?? '';
      _initialBalanceController.text = widget.customer!.initialBalance.toStringAsFixed(2);
      _notesController.text = widget.customer!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _initialBalanceController.dispose();
    _notesController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء إدخال اسم العميل'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final initialBalance = double.tryParse(_initialBalanceController.text.trim());
    if (initialBalance == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء إدخال رصيد أولي صحيح'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final now = DateTime.now().toIso8601String();

    final customer = Customer(
      id: widget.customer?.id,
      name: name,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      initialBalance: initialBalance!,
      currentBalance: widget.customer?.currentBalance ?? initialBalance,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.customer?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (widget.customer == null) {
        await _repository.createCustomer(customer);
      } else {
        await _repository.updateCustomer(customer);
      }

      if (mounted) {
        Navigator.of(context).pop(customer);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ العميل: $e'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        controller: _dialogController,
        title: widget.customer == null ? 'إضافة عميل' : 'تعديل عميل',
        width: 500,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: _nameController,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'اسم العميل *',
                    prefixIcon: Icons.person,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),

                // Phone
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icons.phone,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),

                // Address
                TextField(
                  controller: _addressController,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icons.location_on,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),

                // Initial Balance
                TextField(
                  controller: _initialBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: AppStyles.inputDecoration(
                    labelText: 'الرصيد الأولي',
                    prefixIcon: Icons.account_balance_wallet,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),

                // Notes
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: Icons.note,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.customer == null ? 'حفظ' : 'تحديث',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontSize: 16),
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
  }
}
