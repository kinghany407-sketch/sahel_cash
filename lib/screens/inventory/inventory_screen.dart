import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum InventoryFilter {
  all,
  available,
  low,
  out,
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductRepository _repository = ProductRepository();
  final DraggableDialogController _dialogController = DraggableDialogController();

  final List<Product> _products = [];
  final TextEditingController _searchController = TextEditingController();

  InventoryFilter _filter = InventoryFilter.all;
  bool _isLoading = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final loadedProducts = await _repository.getProducts();
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(loadedProducts);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المخزون: $e'),
            backgroundColor: AppStyles.errorColor,
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

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _products.where((product) {
      final byStatus = _matchesFilter(product);
      if (!byStatus) return false;

      if (query.isEmpty) return true;

      final name = product.name.toLowerCase();
      final sku = product.sku.toLowerCase();
      final barcode = product.barcode.toLowerCase();
      return name.contains(query) || sku.contains(query) || barcode.contains(query);
    }).toList();
  }

  bool _matchesFilter(Product product) {
    switch (_filter) {
      case InventoryFilter.available:
        return product.quantity > product.minQuantity;
      case InventoryFilter.low:
        return product.quantity > 0 && product.quantity <= product.minQuantity;
      case InventoryFilter.out:
        return product.quantity <= 0;
      case InventoryFilter.all:
        return true;
    }
  }

  int get _totalProducts => _products.length;

  int get _availableCount =>
      _products.where((product) => product.quantity > product.minQuantity).length;

  int get _lowCount =>
      _products.where((product) => product.quantity > 0 && product.quantity <= product.minQuantity).length;

  int get _outCount => _products.where((product) => product.quantity <= 0).length;

  double get _inventoryValue {
    return _products.fold(0.0, (sum, product) => sum + (product.quantity * product.sellPrice));
  }

  Color _statusColor(Product product) {
    if (product.quantity <= 0) return Colors.red;
    if (product.quantity <= product.minQuantity) return Colors.orange;
    return Colors.green;
  }

  String _statusLabel(Product product) {
    if (product.quantity <= 0) return 'نافد';
    if (product.quantity <= product.minQuantity) return 'منخفض';
    return 'متوفر';
  }

  Future<void> _openStockDialog(Product product) async {
    final quantityController = TextEditingController(text: '1');
    final reasonController = TextEditingController();
    final quantityFocusNode = FocusNode();
    String operation = 'إدخال';

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) {
        return DraggableDialog(
          controller: _dialogController,
          title: 'إدخال / إخراج مخزون',
          width: 450,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                quantityFocusNode.requestFocus();
              });

              return AlertDialog(
                title: const Text(
                  'إدخال / إخراج مخزون',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Directionality(
                  textDirection: TextDirection.rtl,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('الكمية الحالية: ${product.displayQuantity} ${product.storageUnit}'),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'إدخال',
                              label: Text('إدخال'),
                            ),
                            ButtonSegment<String>(
                              value: 'إخراج',
                              label: Text('إخراج'),
                            ),
                          ],
                          selected: {operation},
                          onSelectionChanged: (values) {
                            setDialogState(() {
                              operation = values.first;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: quantityController,
                          focusNode: quantityFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'الكمية'),
                          autofocus: true,
                          onSubmitted: (_) async {
                            await _commitStockChange(
                              product,
                              quantityController,
                              reasonController,
                              operation,
                              context,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            labelText: operation == 'إدخال' ? 'السبب (شراء جديد / مرتجع)' : 'السبب (تالف / مفقود / هدية)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _commitStockChange(
                        product,
                        quantityController,
                        reasonController,
                        operation,
                        context,
                      );
                    },
                    child: const Text('تأكيد'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _commitStockChange(
    Product product,
    TextEditingController quantityController,
    TextEditingController reasonController,
    String operation,
    BuildContext context,
  ) async {
    final quantity = double.tryParse(quantityController.text) ?? 0;
    if (quantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل كمية صحيحة')),
        );
      }
      return;
    }

    if (operation == 'إخراج' && quantity > product.quantity) {
      await _showInsufficientStockDialog(product, quantity, product.quantity);
      return;
    }

    if (operation == 'إدخال') {
      product.quantity += quantity;
    } else {
      product.quantity -= quantity;
    }

    await _repository.updateProduct(product);
    if (!mounted) return;

    await _loadProducts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحديث بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  Future<void> _showInsufficientStockDialog(
    Product product,
    double requestedQuantity,
    double availableQuantity,
  ) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) {
        return DraggableDialog(
          controller: _dialogController,
          title: 'الكمية غير متوفرة',
          width: 400,
          height: 280,
          child: AlertDialog(
            title: const Text(
              'الكمية غير متوفرة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('الكمية المطلوبة: ${requestedQuantity.toStringAsFixed(2)} ${product.storageUnit}'),
                  Text('الكمية المتاحة: ${availableQuantity.toStringAsFixed(2)} ${product.storageUnit}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Text(
                      '📦 المخزون',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadProducts,
                      tooltip: 'تحديث',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: _buildStatCard('إجمالي المنتجات', _totalProducts.toString(), Icons.inventory_2, Colors.indigo),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('متوفرة', _availableCount.toString(), Icons.circle, Colors.green, emoji: '🟢'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('منخفضة', _lowCount.toString(), Icons.circle, Colors.orange, emoji: '🟠'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('نافدة', _outCount.toString(), Icons.circle, Colors.red, emoji: '🔴'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard('قيمة المخزون', _inventoryValue.toStringAsFixed(2), Icons.account_balance_wallet, Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم / SKU / الباركود...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  textDirection: TextDirection.rtl,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('الكل', InventoryFilter.all),
                    _buildFilterChip('متوفر', InventoryFilter.available),
                    _buildFilterChip('منخفض', InventoryFilter.low),
                    _buildFilterChip('نافد', InventoryFilter.out),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isGridView = true;
                            });
                          },
                          icon: const Icon(Icons.grid_view, size: 14),
                          label: const Text('عرض الكروت', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isGridView ? AppStyles.primaryColor : Colors.white,
                            foregroundColor: _isGridView ? Colors.white : AppStyles.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isGridView = false;
                            });
                          },
                          icon: const Icon(Icons.table_chart, size: 14),
                          label: const Text('عرض الجدول', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_isGridView ? AppStyles.primaryColor : Colors.white,
                            foregroundColor: !_isGridView ? Colors.white : AppStyles.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _isGridView
                          ? GridView.builder(
                              padding: const EdgeInsets.all(4),
                              itemCount: _filteredProducts.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 1.3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return _buildProductCard(product);
                              },
                            )
                          : _buildInventoryTable(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String title, InventoryFilter filter) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(title),
      selected: selected,
      selectedColor: AppStyles.primaryColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) {
        setState(() {
          _filter = filter;
        });
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {String emoji = ''}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11)),
                Text('$emoji $value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTable() {
    final rows = _filteredProducts;
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('الصنف')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('الباركود')),
          DataColumn(label: Text('الكمية')),
          DataColumn(label: Text('الوحدة')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('السعر')),
          DataColumn(label: Text('الإجراءات')),
        ],
        rows: rows.map((product) {
          return DataRow(
            cells: [
              DataCell(Text(product.name)),
              DataCell(Text(product.sku)),
              DataCell(Text(product.barcode)),
              DataCell(Text(product.displayQuantity)),
              DataCell(Text(product.storageUnit)),
              DataCell(
                Row(
                  children: [
                    Icon(Icons.circle, color: _statusColor(product), size: 10),
                    const SizedBox(width: 4),
                    Text(_statusLabel(product), style: TextStyle(color: _statusColor(product))),
                  ],
                ),
              ),
              DataCell(Text(product.sellPrice.toStringAsFixed(2))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _openStockDialog(product),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final hasSku = product.sku.trim().isNotEmpty;
    final hasBarcode = product.barcode.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => _openStockDialog(product),
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildProductImageOrCategoryIcon(product),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              if (hasSku) ...[
                const SizedBox(height: 2),
                Text('SKU: ${product.sku}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              if (hasBarcode) ...[
                const SizedBox(height: 2),
                Text('الباركود: ${product.barcode}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 2),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.scale, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('الكمية: ${product.displayQuantity} ${product.storageUnit}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.circle, color: _statusColor(product), size: 10),
                  const SizedBox(width: 4),
                  Text(_statusLabel(product), style: TextStyle(color: _statusColor(product), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'السعر: ${product.sellPrice.toStringAsFixed(2)} جنيه',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyles.primaryColor, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImageOrCategoryIcon(Product product) {
    if (product.imagePath.isNotEmpty && File(product.imagePath).existsSync()) {
      return Image.file(
        File(product.imagePath),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _categoryIconFor(product.category),
      );
    }

    return _categoryIconFor(product.category);
  }

  Widget _categoryIconFor(String category) {
    final normalized = category.trim().toLowerCase();

    if (normalized.contains('أكياس بلاستيك') || normalized.contains('أكياس')) {
      return const Icon(Icons.shopping_bag, color: Colors.orange, size: 40);
    }
    if (normalized.contains('شنط بلاستيك') || normalized.contains('شنط')) {
      return const Icon(Icons.shopping_bag_outlined, color: Colors.brown, size: 40);
    }
    if (normalized.contains('أكواب ورقية') || normalized.contains('أكواب') || normalized.contains('كوب')) {
      return const Icon(Icons.local_cafe, color: Colors.red, size: 40);
    }
    if (normalized.contains('أطباق فويل') || normalized.contains('فويل')) {
      return const Icon(Icons.auto_awesome, color: Colors.blueGrey, size: 40);
    }
    if (normalized.contains('فوم')) {
      return const Icon(Icons.restaurant_menu, color: Colors.blue, size: 40);
    }
    if (normalized.contains('منتجات ورقية') || normalized.contains('ورقية')) {
      return const Icon(Icons.description, color: Colors.teal, size: 40);
    }
    if (normalized.contains('كرتون')) {
      return const Icon(Icons.archive, color: Colors.brown, size: 40);
    }

    return const Icon(Icons.label, color: Colors.grey, size: 40);
  }
}
