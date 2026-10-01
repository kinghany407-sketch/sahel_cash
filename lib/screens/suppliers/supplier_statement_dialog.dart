import 'package:flutter/material.dart';

import '../../models/supplier_model.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class SupplierStatementDialog extends StatelessWidget {
  final Supplier supplier;

  const SupplierStatementDialog({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    final balanceColor = supplier.currentBalance >= 0
        ? AppStyles.successColor
        : AppStyles.errorColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'كشف حساب المورد',
        width: 600,
        height: 620,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping, size: 32, color: AppStyles.primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                supplier.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('الهاتف: ${supplier.phone}'),
                        ],
                        if (supplier.address != null && supplier.address!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('العنوان: ${supplier.address}'),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الرصيد الحالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${supplier.currentBalance.toStringAsFixed(2)} ج.م',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: balanceColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long, color: AppStyles.primaryColor),
                            SizedBox(width: 8),
                            Text('سجل المشتريات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'سيتم إضافة المشتريات في المرحلة الثانية',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF9E9E9E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.payments, color: AppStyles.primaryColor),
                            SizedBox(width: 8),
                            Text('سجل المدفوعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'سيتم إضافة المشتريات في المرحلة الثانية',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF9E9E9E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ملخص الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildSummaryRow('الرصيد الأولي', supplier.initialBalance),
                        const SizedBox(height: 8),
                        _buildSummaryRow('الرصيد الحالي', supplier.currentBalance),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF616161))),
        Text('${value.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Color(0xFF616161))),
      ],
    );
  }
}