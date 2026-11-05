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
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, _, _) => PurchaseInvoiceDetailsDialog(invoice: details),
    );
  }

  Future<void> _cancelInvoice(PurchaseInvoice invoice) async {
    if (invoice.status == 'voided') return;
    final reasonController = TextEditingController();
    final reason = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          StatefulBuilder(
            builder: (context, setDialogState) => Directionality(
              textDirection: TextDirection.rtl,
              child: DraggableDialog(
                title: 'إلغاء فاتورة الشراء',
                width: 440,
                height: 310,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text(
                        'ستبقى الفاتورة محفوظة بحالة ملغاة، مع فحص أثرها على المخزون ورصيد المورد.',
                      ),
                      const SizedBox(height: 8),
                      Text('هل تريد إلغاء ${invoice.invoiceNumber}؟'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'سبب الإلغاء',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('رجوع'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  reasonController.text.trim().isEmpty
                                  ? null
                                  : Navigator.of(
                                      dialogContext,
                                    ).pop(reasonController.text.trim()),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppStyles.errorColor,
                              ),
                              child: const Text('تأكيد الإلغاء'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await _repository.cancelPurchaseInvoice(invoice.id!, reason: reason);
      if (mounted) {
        _showMessage('تم إلغاء الفاتورة مع الاحتفاظ بها');
        await _loadInvoices();
      }
    } catch (error) {
      if (mounted) {
        _showMessage('تعذر إلغاء فاتورة الشراء: $error', error: true);
      }
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
          invoice.status == 'voided'
              ? '${invoice.invoiceNumber} • ملغاة'
              : invoice.invoiceNumber,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: invoice.status == 'voided' ? AppStyles.errorColor : null,
          ),
        ),
        subtitle: Text(
          '${invoice.supplierName ?? 'مورد غير معروف'}  •  ${_formatDate(invoice.date)}'
          '${invoice.status == 'voided' ? '\nسبب الإلغاء: ${invoice.cancellationReason ?? 'غير مسجل'}' : ''}',
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
            if (invoice.status != 'voided')
              IconButton(
                tooltip: 'إلغاء الفاتورة',
                onPressed: () => _cancelInvoice(invoice),
                icon: const Icon(
                  Icons.cancel_outlined,
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
