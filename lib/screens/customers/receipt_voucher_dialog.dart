import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../models/receipt_voucher_model.dart';
import '../../repositories/receipt_voucher_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class ReceiptVoucherDialog extends StatefulWidget {
  final Customer customer;

  const ReceiptVoucherDialog({super.key, required this.customer});

  @override
  State<ReceiptVoucherDialog> createState() => _ReceiptVoucherDialogState();
}

class _ReceiptVoucherDialogState extends State<ReceiptVoucherDialog> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ReceiptVoucherRepository _receiptRepository =
      ReceiptVoucherRepository();
  final DraggableDialogController _dialogController =
      DraggableDialogController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Invoice> _creditInvoices = [];
  Invoice? _selectedInvoice;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    try {
      final invoices = await _invoiceRepository.getInvoicesForCustomer(
        widget.customer.id!,
        creditOnly: true,
      );
      if (mounted) setState(() => _creditInvoices = invoices);
    } catch (error) {
      if (mounted) _showError('تعذر تحميل فواتير العميل: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveVoucher() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغًا صحيحًا أكبر من صفر');
      return;
    }
    if (amount > widget.customer.currentBalance) {
      _showError('المبلغ أكبر من رصيد العميل المستحق');
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now().toIso8601String();
    try {
      await _receiptRepository.createReceiptVoucher(
        ReceiptVoucher(
          voucherNumber: '',
          customerId: widget.customer.id!,
          invoiceId: _selectedInvoice?.id,
          date: now,
          amount: amount,
          paymentMethod: 'cash',
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          createdAt: now,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError('تعذر حفظ سند القبض: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
      child: DraggableDialog(
        controller: _dialogController,
        title: 'سند قبض',
        width: 520,
        height: 460,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('العميل: ${widget.customer.name}'),
                    const SizedBox(height: 4),
                    Text(
                      'الرصيد المستحق: ${widget.customer.currentBalance.toStringAsFixed(2)} ج.م',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Invoice>(
                      initialValue: _selectedInvoice,
                      decoration: const InputDecoration(
                        labelText: 'ربط بفاتورة (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Invoice>(
                          value: null,
                          child: Text('على إجمالي رصيد العميل'),
                        ),
                        ..._creditInvoices.map(
                          (invoice) => DropdownMenuItem<Invoice>(
                            value: invoice,
                            child: Text(
                              '${invoice.invoiceNumber} - ${invoice.total.toStringAsFixed(2)} ج.م',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (invoice) =>
                          setState(() => _selectedInvoice = invoice),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveVoucher,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('حفظ سند القبض'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _dialogController.dispose();
    super.dispose();
  }
}
