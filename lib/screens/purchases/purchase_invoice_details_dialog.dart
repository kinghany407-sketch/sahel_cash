import 'package:flutter/material.dart';

import '../../models/purchase_invoice_model.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/draggable_dialog.dart';

class PurchaseInvoiceDetailsDialog extends StatelessWidget {
  final PurchaseInvoice invoice;

  const PurchaseInvoiceDetailsDialog({super.key, required this.invoice});

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'تفاصيل فاتورة الشراء ${invoice.invoiceNumber}',
        width: 760,
        height: 640,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _detailRow('رقم الفاتورة', invoice.invoiceNumber),
                _detailRow('المورد', invoice.supplierName ?? 'غير معروف'),
                _detailRow('التاريخ', _formatDate(invoice.date)),
                _detailRow(
                  'طريقة الدفع',
                  invoice.paymentType == 'credit' ? 'آجل' : 'نقدي',
                ),
                if (invoice.notes != null && invoice.notes!.isNotEmpty)
                  _detailRow('ملاحظات', invoice.notes!),
                const Divider(height: 28),
                const Text(
                  'المنتجات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (invoice.items.isEmpty)
                  const Text('لا توجد تفاصيل للمنتجات')
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(1.5),
                    },
                    border: TableBorder.all(color: Colors.black12),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF4F5F8)),
                        children: [
                          _TableCell('المنتج', isHeader: true),
                          _TableCell('كمية الشراء', isHeader: true),
                          _TableCell('كمية التخزين', isHeader: true),
                          _TableCell('سعر الوحدة', isHeader: true),
                          _TableCell('الإجمالي', isHeader: true),
                        ],
                      ),
                      ...invoice.items.map(
                        (item) => TableRow(
                          children: [
                            _TableCell(item.productName ?? 'منتج'),
                            _TableCell(
                              '${formatQuantity(item.quantity)} ${item.purchaseUnit}',
                            ),
                            _TableCell(formatQuantity(item.storageQuantity)),
                            _TableCell(item.unitPrice.toStringAsFixed(2)),
                            _TableCell(item.total.toStringAsFixed(2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 28),
                _detailRow(
                  'الإجمالي الفرعي',
                  '${invoice.subtotal.toStringAsFixed(2)} ج.م',
                ),
                _detailRow(
                  'الخصم',
                  '${invoice.discount.toStringAsFixed(2)} ج.م',
                ),
                _detailRow(
                  'الإجمالي',
                  '${invoice.totalAmount.toStringAsFixed(2)} ج.م',
                  bold: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isHeader;

  const _TableCell(this.text, {this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
