import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/draggable_dialog.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

enum InvoiceFilter {
  all,
  today,
  week,
  month,
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ProductRepository _productRepository = ProductRepository();
  final DraggableDialogController _dialogController = DraggableDialogController();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  List<Invoice> _invoices = [];
  bool _isLoading = true;
  bool _isGridView = false;
  InvoiceFilter _filter = InvoiceFilter.all;

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _invoiceRepository.getAllInvoices(limit: 10000, offset: 0);
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الفواتير: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Invoice> get _filteredInvoices {
    final text = _searchController.text.trim();

    return _invoices.where((invoice) {
      final byFilter = _matchesFilter(invoice);
      if (!byFilter) return false;

      if (text.isNotEmpty && !invoice.invoiceNumber.contains(text)) {
        return false;
      }

      if (_fromDate != null) {
        final invoiceDate = DateTime.tryParse(invoice.date);
        if (invoiceDate == null || invoiceDate.isBefore(_fromDate!)) {
          return false;
        }
      }

      if (_toDate != null) {
        final invoiceDate = DateTime.tryParse(invoice.date);
        if (invoiceDate == null || invoiceDate.isAfter(_toDate!.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool _matchesFilter(Invoice invoice) {
    final now = DateTime.now();
    final invoiceDate = DateTime.tryParse(invoice.date);
    if (invoiceDate == null) return true;

    switch (_filter) {
      case InvoiceFilter.today:
        return _sameDay(invoiceDate, now);
      case InvoiceFilter.week:
        return !invoiceDate.isBefore(now.subtract(const Duration(days: 6))) && !invoiceDate.isAfter(now);
      case InvoiceFilter.month:
        return invoiceDate.year == now.year && invoiceDate.month == now.month;
      case InvoiceFilter.all:
        return true;
    }
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year && first.month == second.month && first.day == second.day;
  }

  int get _totalInvoices => _invoices.length;

  double get _todaySales {
    final today = DateTime.now();
    return _invoices.where((invoice) {
      final date = DateTime.tryParse(invoice.date);
      return date != null && _sameDay(date, today);
    }).fold(0.0, (sum, invoice) => sum + invoice.total);
  }

  double get _weekSales {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    return _invoices.where((invoice) {
      final date = DateTime.tryParse(invoice.date);
      return date != null && !date.isBefore(start) && !date.isAfter(now);
    }).fold(0.0, (sum, invoice) => sum + invoice.total);
  }

  double get _monthSales {
    final now = DateTime.now();
    return _invoices.where((invoice) {
      final date = DateTime.tryParse(invoice.date);
      return date != null && date.year == now.year && date.month == now.month;
    }).fold(0.0, (sum, invoice) => sum + invoice.total);
  }

  int get _todayInvoiceCount {
    final today = DateTime.now();
    return _invoices.where((invoice) {
      final date = DateTime.tryParse(invoice.date);
      return date != null && _sameDay(date, today);
    }).length;
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = picked;
      _fromDateController.text = _formatDate(picked);
    });
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _toDate = picked;
      _toDateController.text = _formatDate(picked);
    });
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatDateTime(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${_formatDate(date)}   ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDetailsDialog(Invoice invoice) async {
    final items = await _invoiceRepository.getInvoiceItems(invoice.id!);
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) {
        return DraggableDialog(
          controller: _dialogController,
          title: 'تفاصيل الفاتورة ${invoice.invoiceNumber}',
          width: 700,
          height: 500,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('تفاصيل الفاتورة ${invoice.invoiceNumber}'),
              content: SizedBox(
                width: 660,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('رقم الفاتورة: ${invoice.invoiceNumber}'),
                      const SizedBox(height: 8),
                      Text('التاريخ والوقت: ${_formatDateTime(invoice.date)}'),
                      const SizedBox(height: 8),
                      Text('طريقة الدفع: ${invoice.paymentMethod}'),
                      const SizedBox(height: 16),
                      const Text(
                        'العناصر:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3.0),  // المنتج
                          1: FlexColumnWidth(1.0),  // الكمية
                          2: FlexColumnWidth(1.0),  // الوحدة
                          3: FlexColumnWidth(1.0),  // السعر
                          4: FlexColumnWidth(1.5),  // الإجمالي
                        },
                        children: [
                          TableRow(
                            children: [
                              const Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('الوحدة', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('السعر', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          ...items.map((item) {
                            return TableRow(
                              children: [
                                Text(item.productName, maxLines: 3, overflow: TextOverflow.ellipsis),
                                Text(formatQuantity(item.quantity)),
                                Text(item.saleUnit),
                                Text(item.unitPrice.toStringAsFixed(2)),
                                Text(item.total.toStringAsFixed(2)),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('الإجمالي الكلي: ${invoice.total.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('طباعة'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('هل تريد حذف الفاتورة رقم ${invoice.invoiceNumber}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || invoice.id == null) return;

    try {
      final items = await _invoiceRepository.getInvoiceItems(invoice.id!);
      final products = await _productRepository.getProducts();

      for (final item in items) {
        Product? product;
        for (final candidate in products) {
          if (candidate.id == item.productId) {
            product = candidate;
            break;
          }
        }

        if (product == null) continue;

        double quantityToRestore = item.quantity;
        final productStorageUnit = product.storageUnit.trim().toLowerCase();
        final itemSaleUnit = item.saleUnit.trim().toLowerCase();

        final units = await _productRepository.getSaleUnits(product.id!);
        var selectedUnit = units.where((u) => u.saleUnit.trim().toLowerCase() == itemSaleUnit).toList();
        if (selectedUnit.isNotEmpty) {
          if (selectedUnit.first.saleUnit.trim().toLowerCase() == productStorageUnit) {
            quantityToRestore = item.quantity;
          } else {
            quantityToRestore = item.quantity * selectedUnit.first.conversionToStorage;
          }
        } else if (itemSaleUnit != productStorageUnit) {
          quantityToRestore = item.quantity * product.conversionFactor;
        }

        product.quantity += quantityToRestore;
        await _productRepository.updateProduct(product);
      }

      await _invoiceRepository.deleteInvoiceItemsByInvoiceId(invoice.id!);
      await _invoiceRepository.deleteInvoice(invoice.id!);

      if (!mounted) return;
      await _loadInvoices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف بنجاح')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف الفاتورة: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('الفواتير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: _loadInvoices, icon: const Icon(Icons.refresh)),
                    const SizedBox(width: 8),
                    SegmentedButton<InvoiceFilter>(
                      segments: const [
                        ButtonSegment(value: InvoiceFilter.all, label: Text('الكل')),
                        ButtonSegment(value: InvoiceFilter.today, label: Text('اليوم')),
                        ButtonSegment(value: InvoiceFilter.week, label: Text('الأسبوع')),
                        ButtonSegment(value: InvoiceFilter.month, label: Text('الشهر')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) {
                        setState(() => _filter = value.first);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      icon: Icon(_isGridView ? Icons.table_chart : Icons.grid_view),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _statCard('إجمالي الفواتير', '$_totalInvoices', Icons.receipt_long)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('مبيعات اليوم', '${_todaySales.toStringAsFixed(2)}', Icons.today)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('مبيعات الأسبوع', '${_weekSales.toStringAsFixed(2)}', Icons.date_range)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('مبيعات الشهر', '${_monthSales.toStringAsFixed(2)}', Icons.calendar_month)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('عدد فواتير اليوم', '$_todayInvoiceCount', Icons.numbers)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(labelText: 'بحث برقم الفاتورة', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _fromDateController,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'التاريخ من', border: OutlineInputBorder(), prefixIcon: Icon(Icons.date_range)),
                        onTap: _pickFromDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _toDateController,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'التاريخ إلى', border: OutlineInputBorder(), prefixIcon: Icon(Icons.date_range)),
                        onTap: _pickToDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading ? const Center(child: CircularProgressIndicator()) : (_isGridView ? _buildCards() : _buildTable()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    final invoices = _filteredInvoices;
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('رقم الفاتورة')),
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('الوقت')),
              DataColumn(label: Text('عدد العناصر')),
              DataColumn(label: Text('الإجمالي')),
              DataColumn(label: Text('الإجراءات')),
            ],
            rows: invoices.map((invoice) {
              final itemsFuture = _invoiceRepository.getInvoiceItems(invoice.id!);
              return DataRow(cells: [
                DataCell(Text(invoice.invoiceNumber)),
                DataCell(Text(_formatDate(DateTime.tryParse(invoice.date) ?? DateTime.now()))),
                DataCell(Text(_formatTime(DateTime.tryParse(invoice.date) ?? DateTime.now()))),
                DataCell(FutureBuilder<List<InvoiceItem>>(
                  future: itemsFuture,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Text('$count');
                  },
                )),
                DataCell(Text(invoice.total.toStringAsFixed(2))),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye),
                      onPressed: () => _showDetailsDialog(invoice),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(invoice),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCards() {
    final invoices = _filteredInvoices;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الفاتورة ${invoice.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(_formatDateTime(invoice.date)),
                const SizedBox(height: 8),
                FutureBuilder<List<InvoiceItem>>(
                  future: _invoiceRepository.getInvoiceItems(invoice.id!),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Text('عدد العناصر: $count');
                  },
                ),
                const SizedBox(height: 8),
                Text('الإجمالي: ${invoice.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDetailsDialog(invoice),
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text('عرض التفاصيل'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
