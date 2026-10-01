import 'package:flutter/material.dart';

import '../../models/purchase_invoice_model.dart';
import '../../repositories/purchase_invoice_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';
import 'purchase_invoice_details_dialog.dart';
import 'purchase_invoice_screen.dart';

class PurchaseInvoicesListScreen extends StatefulWidget {
  final int? supplierId;

  const PurchaseInvoicesListScreen({super.key, this.supplierId});

  @override
  State<PurchaseInvoicesListScreen> createState() =>
      _PurchaseInvoicesListScreenState();
}

class _PurchaseInvoicesListScreenState
    extends State<PurchaseInvoicesListScreen> {
  final PurchaseInvoiceRepository _repository = PurchaseInvoiceRepository();
  final TextEditingController _searchController = TextEditingController();
  List<PurchaseInvoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _repository.getAllPurchaseInvoices(
        query: _searchController.text.trim(),
        supplierId: widget.supplierId,
      );
      if (mounted) setState(() => _invoices = invoices);
    } catch (error) {
      if (mounted) {
        _showMessage('تعذر تحميل فواتير الشراء: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvoice() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PurchaseInvoiceScreen(supplierId: widget.supplierId),
      ),
    );
    if (created == true && mounted) {
      _showMessage('تم حفظ فاتورة الشراء بنجاح');
      await _loadInvoices();
    }
  }

  Future<void> _showDetails(PurchaseInvoice invoice) async {
    final details = await _repository.getPurchaseInvoiceById(invoice.id!);
    if (details == null || !mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, _, _) => PurchaseInvoiceDetailsDialog(invoice: details),
    );
  }

  Future<void> _deleteInvoice(PurchaseInvoice invoice) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          Directionality(
            textDirection: TextDirection.rtl,
            child: DraggableDialog(
              title: 'حذف فاتورة الشراء',
              width: 440,
              height: 250,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'سيتم حذف الفاتورة وعكس أثرها على المخزون ورصيد المورد.',
                    ),
                    Text('هل تريد حذف ${invoice.invoiceNumber}؟'),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
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
      await _repository.deletePurchaseInvoice(invoice.id!);
      if (mounted) {
        _showMessage('تم حذف فاتورة الشراء');
        await _loadInvoices();
      }
    } catch (error) {
      if (mounted) _showMessage('تعذر حذف فاتورة الشراء: $error', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppStyles.errorColor : AppStyles.successColor,
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
        appBar: AppBar(title: const Text('فواتير الشراء'), centerTitle: true),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'بحث برقم الفاتورة أو اسم المورد',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _loadInvoices(),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoices.isEmpty
                  ? const Center(child: Text('لا توجد فواتير شراء'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _invoices.length,
                      itemBuilder: (context, index) =>
                          _buildInvoiceTile(_invoices[index]),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createInvoice,
          icon: const Icon(Icons.add),
          label: const Text('فاتورة شراء'),
        ),
      ),
    );
  }

  Widget _buildInvoiceTile(PurchaseInvoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${invoice.supplierName ?? 'مورد غير معروف'}  •  ${_formatDate(invoice.date)}',
        ),
        leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${invoice.totalAmount.toStringAsFixed(2)} ج.م',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'عرض التفاصيل',
              onPressed: () => _showDetails(invoice),
              icon: const Icon(Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: 'حذف الفاتورة',
              onPressed: () => _deleteInvoice(invoice),
              icon: const Icon(
                Icons.delete_outline,
                color: AppStyles.errorColor,
              ),
            ),
          ],
        ),
        onTap: () => _showDetails(invoice),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
