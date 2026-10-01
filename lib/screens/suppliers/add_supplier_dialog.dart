import 'package:flutter/material.dart';

import '../../models/supplier_model.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class AddSupplierDialog extends StatefulWidget {
  final Supplier? supplier;

  const AddSupplierDialog({super.key, this.supplier});

  @override
  State<AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<AddSupplierDialog> {
  final SupplierRepository _repository = SupplierRepository();
  final DraggableDialogController _dialogController = DraggableDialogController();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    if (supplier != null) {
      _nameController.text = supplier.name;
      _phoneController.text = supplier.phone ?? '';
      _addressController.text = supplier.address ?? '';
      _initialBalanceController.text = supplier.initialBalance.toStringAsFixed(2);
      _notesController.text = supplier.notes ?? '';
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

  Future<void> _saveSupplier() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال اسم المورد'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final initialBalance = double.tryParse(_initialBalanceController.text.trim());
    if (initialBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال رصيد أولي صحيح'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();
    final existingSupplier = widget.supplier;
    final supplier = Supplier(
      id: existingSupplier?.id,
      name: name,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      initialBalance: initialBalance,
      currentBalance: existingSupplier?.currentBalance ?? initialBalance,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: existingSupplier?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (existingSupplier == null) {
        await _repository.createSupplier(supplier);
      } else {
        await _repository.updateSupplier(supplier);
      }

      if (mounted) Navigator.of(context).pop(supplier);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حفظ المورد: $error'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        controller: _dialogController,
        title: widget.supplier == null ? 'إضافة مورد' : 'تعديل مورد',
        width: 500,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'اسم المورد *',
                    prefixIcon: Icons.person,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
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
                TextField(
                  controller: _addressController,
                  decoration: AppStyles.inputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icons.location_on,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveSupplier,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(widget.supplier == null ? 'حفظ' : 'تحديث'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
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