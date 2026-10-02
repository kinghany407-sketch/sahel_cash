import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../models/receipt_voucher_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/receipt_voucher_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';
import 'receipt_voucher_dialog.dart';

class CustomerStatementDialog extends StatefulWidget {
  final Customer customer;

  const CustomerStatementDialog({super.key, required this.customer});

  @override
  State<CustomerStatementDialog> createState() =>
      _CustomerStatementDialogState();
}

class _CustomerStatementDialogState extends State<CustomerStatementDialog> {
  final CustomerRepository _customerRepository = CustomerRepository();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ReceiptVoucherRepository _receiptRepository =
      ReceiptVoucherRepository();
  final ScrollController _scrollController = ScrollController();

  late Customer _customer;
  List<Invoice> _invoices = [];
  List<ReceiptVoucher> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    final customerId = widget.customer.id;
    if (customerId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final customer = await _customerRepository.getCustomerById(customerId);
      final invoices = await _invoiceRepository.getInvoicesForCustomer(
        customerId,
      );
      final receipts = await _receiptRepository.getForCustomer(customerId);
      if (!mounted) return;
      setState(() {
        _customer = customer ?? widget.customer;
        _invoices = invoices;
        _receipts = receipts;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل كشف الحساب: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showReceiptDialog() async {
    final created = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, _, _) => ReceiptVoucherDialog(customer: _customer),
    );
    if (created == true && mounted) await _loadStatement();
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final screenSize = MediaQuery.sizeOf(context);
    final balanceColor = customer.currentBalance > 0
        ? AppStyles.errorColor
        : AppStyles.successColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'كشف حساب',
        width: math.min(600, screenSize.width - 32),
        height: math.min(720, math.max(360, screenSize.height - 48)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Info
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 32,
                                color: AppStyles.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (customer.phone != null &&
                              customer.phone!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone,
                                  size: 18,
                                  color: Color(0xFF9E9E9E),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  customer.phone!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF616161),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (customer.address != null &&
                              customer.address!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: Color(0xFF9E9E9E),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    customer.address!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF616161),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'الرصيد الحالي:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${customer.currentBalance.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: balanceColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                color: AppStyles.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'سجل الفواتير',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_invoices.isEmpty)
                            const Text('لا توجد فواتير مسجلة لهذا العميل')
                          else
                            ..._invoices.map(
                              (invoice) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.receipt_long),
                                title: Text(invoice.invoiceNumber),
                                subtitle: Text(
                                  '${invoice.date} • ${invoice.paymentMethod == 'credit' ? 'آجل' : 'نقدي'}',
                                ),
                                trailing: Text(
                                  '${invoice.total.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.payments,
                                color: AppStyles.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'سجل سندات القبض',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _customer.currentBalance > 0
                                    ? _showReceiptDialog
                                    : null,
                                icon: const Icon(Icons.add),
                                label: const Text('سند قبض'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_receipts.isEmpty)
                            const Text('لا توجد سندات قبض مسجلة')
                          else
                            ..._receipts.map(
                              (receipt) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.payments_outlined),
                                title: Text(receipt.voucherNumber),
                                subtitle: Text(
                                  receipt.invoiceNumber == null
                                      ? receipt.date
                                      : '${receipt.date} • فاتورة ${receipt.invoiceNumber}',
                                ),
                                trailing: Text(
                                  '- ${receipt.amount.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(
                                    color: AppStyles.successColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ملخص الحساب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryRow(
                            'الرصيد الأولي',
                            customer.initialBalance.toStringAsFixed(2),
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'الرصيد الحالي',
                            customer.currentBalance.toStringAsFixed(2),
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(
                            'فرق المعاملات',
                            (customer.currentBalance - customer.initialBalance)
                                .toStringAsFixed(2),
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF616161),
          ),
        ),
        Text(
          '$value ج.م',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppStyles.primaryColor : const Color(0xFF616161),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
