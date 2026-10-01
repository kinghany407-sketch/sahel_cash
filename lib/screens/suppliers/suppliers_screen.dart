import 'package:flutter/material.dart';

import '../../models/supplier_model.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';
import 'add_supplier_dialog.dart';
import 'supplier_statement_dialog.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierRepository _repository = SupplierRepository();
  final List<Supplier> suppliers = [];
  final TextEditingController searchController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final loadedSuppliers = await _repository.getAllSuppliers();
      if (!mounted) return;
      setState(() {
        suppliers
          ..clear()
          ..addAll(loadedSuppliers);
      });
    } catch (error) {
      if (mounted) _showError('خطأ في تحميل الموردين: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchSuppliers(String query) async {
    if (query.isEmpty) {
      await _loadSuppliers();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final matches = await _repository.searchSuppliers(query);
      if (!mounted) return;
      setState(() {
        suppliers
          ..clear()
          ..addAll(matches);
      });
    } catch (error) {
      if (mounted) _showError('خطأ في البحث: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddDialog({Supplier? supplier}) async {
    final savedSupplier = await showGeneralDialog<Supplier>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (context, animation, secondaryAnimation) =>
          AddSupplierDialog(supplier: supplier),
    );

    if (savedSupplier == null || !mounted) return;
    _showSuccess(supplier == null ? 'تم إضافة المورد بنجاح' : 'تم تحديث المورد بنجاح');
    await _loadSuppliers();
  }

  Future<void> _showStatement(Supplier supplier) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (context, animation, secondaryAnimation) =>
          SupplierStatementDialog(supplier: supplier),
    );
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableDialog(
          title: 'تأكيد الحذف',
          width: 420,
          height: 240,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('هل تريد حذف المورد "${supplier.name}"؟'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.errorColor,
                          foregroundColor: Colors.white,
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
      await _repository.deleteSupplier(supplier.id!);
      if (!mounted) return;
      _showSuccess('تم حذف المورد بنجاح');
      await _loadSuppliers();
    } catch (error) {
      if (mounted) _showError('خطأ في حذف المورد: $error');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppStyles.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppStyles.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff5f6fa),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, size: 28, color: AppStyles.primaryColor),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'الموردون',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'بحث عن مورد...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: _searchSuppliers,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : suppliers.isEmpty
                        ? _buildEmptyState()
                        : _buildSupplierList(),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(),
          backgroundColor: AppStyles.primaryColor,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('لا يوجد موردون', style: TextStyle(fontSize: 20, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('اضغط على + لإضافة مورد جديد', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildSupplierList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suppliers.length,
      itemBuilder: (context, index) => _buildSupplierCard(suppliers[index]),
    );
  }

  Widget _buildSupplierCard(Supplier supplier) {
    final balanceColor = supplier.currentBalance >= 0
        ? AppStyles.successColor
        : AppStyles.errorColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppStyles.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  supplier.name.isNotEmpty ? supplier.name[0] : '?',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppStyles.primaryColor),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(supplier.phone!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'الرصيد: ${supplier.currentBalance.toStringAsFixed(2)} ج.م',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: balanceColor),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long, size: 20),
                  onPressed: () => _showStatement(supplier),
                  tooltip: 'كشف الحساب',
                  color: Colors.blue,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showAddDialog(supplier: supplier),
                  tooltip: 'تعديل',
                  color: Colors.orange,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _deleteSupplier(supplier),
                  tooltip: 'حذف',
                  color: AppStyles.errorColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}