import 'package:flutter/material.dart';

import '../../models/customer_model.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class CustomerStatementDialog extends StatelessWidget {
  final Customer customer;

  const CustomerStatementDialog({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final balanceColor = customer.currentBalance >= 0
        ? AppStyles.successColor
        : AppStyles.errorColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'كشف حساب',
        width: 600,
        height: 700,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
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
                            const Icon(Icons.person, size: 32, color: AppStyles.primaryColor),
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
                        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 18, color: Color(0xFF9E9E9E)),
                              const SizedBox(width: 8),
                              Text(
                                customer.phone!,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF616161)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (customer.address != null && customer.address!.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 18, color: Color(0xFF9E9E9E)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customer.address!,
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF616161)),
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

                // Invoices Placeholder
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
                            const Icon(Icons.receipt_long, color: AppStyles.primaryColor),
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
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: const Color(0xFFBDBDBD),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'سيتم إضافة الفواتير في المرحلة الثانية',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Payments Placeholder
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
                            const Icon(Icons.payments, color: AppStyles.primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'سجل المدفوعات',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.money_off_outlined,
                                size: 48,
                                color: const Color(0xFFBDBDBD),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'سيتم إضافة المدفوعات في المرحلة الثانية',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
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
                        _buildSummaryRow('الرصيد الأولي', customer.initialBalance.toStringAsFixed(2)),
                        const SizedBox(height: 8),
                        _buildSummaryRow('الرصيد الحالي', customer.currentBalance.toStringAsFixed(2)),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'فرق المعاملات',
                          (customer.currentBalance - customer.initialBalance).toStringAsFixed(2),
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
}
