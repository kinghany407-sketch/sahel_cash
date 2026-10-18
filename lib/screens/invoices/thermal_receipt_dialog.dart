import 'package:flutter/material.dart';

import '../../models/invoice_item_model.dart';
import '../../models/invoice_model.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class ThermalReceiptDialog extends StatelessWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final String? customerName;

  const ThermalReceiptDialog({
    super.key,
    required this.invoice,
    required this.items,
    this.customerName,
  });

  static Future<void> show(
    BuildContext context, {
    required Invoice invoice,
    required List<InvoiceItem> items,
    String? customerName,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ThermalReceiptDialog(
          invoice: invoice,
          items: items,
          customerName: customerName,
        );
      },
    );
  }

  String _formatDateTime(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    final y = parsed.year;
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    final h = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '$y/$m/$d   $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final totalQuantity = items.fold(0.0, (sum, it) => sum + it.quantity);

    return DraggableDialog(
      title: 'معاينة طباعة الفاتورة',
      width: 460,
      height: 660,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Receipt Paper Canvas
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Store Header
                        const Center(
                          child: Text(
                            'سهل كاش',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Center(
                          child: Text(
                            'فاتورة مبيعات نقدية',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDottedLine(),
                        const SizedBox(height: 8),

                        // Invoice Details & Cashier Info
                        _buildReceiptRow('رقم الفاتورة:', '#${invoice.invoiceNumber}'),
                        _buildReceiptRow('التاريخ والوقت:', _formatDateTime(invoice.date)),
                        _buildReceiptRow(
                          'الكاشير / البائع:',
                          invoice.cashierName?.isNotEmpty == true
                              ? invoice.cashierName!
                              : (invoice.createdByName?.isNotEmpty == true
                                  ? invoice.createdByName!
                                  : 'غير محدد'),
                          isBold: true,
                          highlightColor: AppStyles.primaryColor,
                        ),
                        _buildReceiptRow(
                          'طريقة الدفع:',
                          invoice.paymentMethod == 'cash'
                              ? 'نقدي'
                              : invoice.paymentMethod == 'credit'
                                  ? 'آجل'
                                  : invoice.paymentMethod,
                        ),
                        if (customerName != null && customerName!.isNotEmpty)
                          _buildReceiptRow('العميل:', customerName!),

                        const SizedBox(height: 8),
                        _buildDottedLine(),
                        const SizedBox(height: 8),

                        // Items Header
                        Row(
                          children: const [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'الصنف',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'الكمية',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'السعر',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'الإجمالي',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(thickness: 1, height: 12),

                        // Items List
                        ...items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${formatQuantity(item.quantity)} ${item.saleUnit}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.unitPrice.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.total.toStringAsFixed(2),
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 8),
                        _buildDottedLine(),
                        const SizedBox(height: 8),

                        // Totals Summary
                        _buildReceiptRow('عدد البنود:', '${items.length} صنف'),
                        _buildReceiptRow('إجمالي الكميات:', formatQuantity(totalQuantity)),
                        const SizedBox(height: 4),
                        if (invoice.discount > 0) ...[
                          _buildReceiptRow(
                            'المجموع الفرعي:',
                            '${(invoice.total + invoice.discount).toStringAsFixed(2)} ج.م',
                          ),
                          _buildReceiptRow(
                            'الخصم:',
                            '-${invoice.discount.toStringAsFixed(2)} ج.م',
                            isBold: true,
                            highlightColor: Colors.red,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'الإجمالي المطلوب:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${invoice.total.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        if (invoice.paymentMethod == 'cash') ...[
                          const SizedBox(height: 4),
                          _buildReceiptRow('المدفوع:', '${invoice.paidAmount.toStringAsFixed(2)} ج.م'),
                          _buildReceiptRow(
                            'الباقي:',
                            '${invoice.changeAmount.toStringAsFixed(2)} ج.م',
                            isBold: true,
                            highlightColor: invoice.changeAmount >= 0 ? Colors.green : Colors.red,
                          ),
                        ],

                        const SizedBox(height: 12),
                        _buildDottedLine(),
                        const SizedBox(height: 12),

                        // Receipt Footer
                        const Center(
                          child: Text(
                            'شكراً لزيارتكم! نتمنى لكم يوماً سعيداً',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'برمجة وتطوير Sahel Cash POS',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Simulated Barcode
                        Center(
                          child: Text(
                            '||| | ||||| || |||| ||| ||||||| |||',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إرسال أمر الطباعة بنجاح للطابعة الحرارية'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة الفاتورة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: highlightColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 6).floor();
        return Text(
          '- ' * dashCount,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        );
      },
    );
  }
}
