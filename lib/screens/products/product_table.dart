import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../models/product_sale_unit_model.dart';
import '../../repositories/product_repository.dart';
import 'access_control.dart';
import 'app_styles.dart';
import 'product_card.dart';

class ProductTable extends StatefulWidget {
  final List<Product> products;
  final void Function(Product product) onEdit;
  final void Function(Product product) onDelete;
  final void Function(Product product) onView;
  final UserRole role;
  final bool initialIsGrid;
  final void Function(bool isGrid)? onViewModeChanged;

  const ProductTable({
    super.key,
    required this.products,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
    this.role = UserRole.admin,
    this.initialIsGrid = false,
    this.onViewModeChanged,
  });

  @override
  State<ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<ProductTable> {
  late bool isGrid;
  final ProductRepository _productRepository = ProductRepository();
  final Map<int, List<ProductSaleUnit>> _productSaleUnits = {};
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    isGrid = widget.initialIsGrid;
    _loadSaleUnits();
  }

  Future<void> _loadSaleUnits() async {
    for (final product in widget.products) {
      if (product.id != null) {
        try {
          final units = await _productRepository.getSaleUnits(product.id!);
          if (mounted) {
            setState(() {
              _productSaleUnits[product.id!] = units;
            });
          }
        } catch (e) {
          // Continue even if loading fails
        }
      }
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() {
      isGrid = !isGrid;
    });
    widget.onViewModeChanged?.call(isGrid);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _toggleViewMode,
            icon: Icon(isGrid ? Icons.table_rows : Icons.grid_view),
            label: Text(isGrid ? 'عرض الجدول' : 'عرض الكروت'),
            style: TextButton.styleFrom(
              foregroundColor: AppStyles.primaryColor,
            ),
          ),
        ),
        Expanded(
          child: widget.products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: AppStyles.iconSizeXl,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: AppStyles.spacingMd),
                      const Text(
                        'لا توجد أصناف حتى الآن',
                        style: TextStyle(
                          fontSize: AppStyles.fontSizeLg,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : (isGrid ? buildGrid() : buildTable()),
        ),
      ],
    );
  }

  Widget buildTable() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: AppStyles.elevationSm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              controller: _verticalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 40,
                  columnSpacing: 8,
                  horizontalMargin: 4,
                  dividerThickness: 1,
                  headingRowColor: WidgetStateProperty.all(
                    AppStyles.primaryColor.withValues(alpha: 0.05),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'الصنف',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'SKU',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الباركود',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'سعر البيع',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'المخزون',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الحد الأدنى',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الحالة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الإجراءات',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                    ),
                  ],
                  rows: widget.products.map((item) {
                    final bool lowStock = item.isLowStock;
                    final bool outOfStock = item.quantity <= 0;

                    return DataRow(
                      cells: [
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: SizedBox(
                              width: 110,
                              child: Text(
                                item.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              item.sku,
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              item.barcode.isEmpty ? '—' : item.barcode,
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _buildPriceCell(item),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              '${item.displayQuantity} ${item.storageUnit != item.saleUnit ? '${item.storageUnit} (${item.saleUnit})' : item.saleUnit}',
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              '${item.minQuantity} ${item.storageUnit}',
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _buildStatusBadge(outOfStock, lowStock),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 90,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility, size: 15),
                                    onPressed: () => widget.onView(item),
                                    tooltip: 'عرض',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 15),
                                    onPressed: () => widget.onEdit(item),
                                    tooltip: 'تعديل',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 15, color: Colors.red),
                                    onPressed: () => widget.onDelete(item),
                                    tooltip: 'حذف',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool outOfStock, bool lowStock) {
    if (outOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD32F2F), width: 1),
        ),
        child: const Text(
          '🔴 نفد',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFFD32F2F),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (lowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD32F2F), width: 1),
        ),
        child: const Text(
          '🔴 منخفض',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFFD32F2F),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF388E3C).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF388E3C), width: 1),
        ),
        child: const Text(
          '🟢 جيد',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF388E3C),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildPriceCell(Product item) {
    final saleUnits = _productSaleUnits[item.id];
    if (saleUnits == null || saleUnits.isEmpty) {
      // Fallback to old sellPrice if no sale units
      return Text(
        item.sellPrice.toStringAsFixed(2),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.right,
      );
    }

    // Show summary of sale units
    final unitsText = saleUnits.map((u) {
      final retailText = '${u.saleUnit}: ${u.retailPrice.toStringAsFixed(2)}';
      final wholesaleText = u.wholesalePrice != null
          ? ' | جملة ${u.wholesalePrice!.toStringAsFixed(2)}'
          : '';
      return '$retailText$wholesaleText';
    }).join('\n');

    return Tooltip(
      message: unitsText,
      child: Text(
        saleUnits.length > 1 ? '${saleUnits.length} وحدات' : saleUnits.first.saleUnit,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget buildGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = 230; // Sidebar width
    final availableWidth = screenWidth - sidebarWidth - 40; // Reduced padding
    
    // Calculate crossAxisCount based on screen width
    int crossAxisCount;

    if (screenWidth >= 1920) {
      crossAxisCount = 4;
    } else if (screenWidth >= 1600) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 3;
    }
    
    // Calculate card width
    final cardWidth = (availableWidth - (crossAxisCount - 1) * 6) / crossAxisCount;
    
    return GridView.builder(
      itemCount: widget.products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: cardWidth / 160, // 160 is max card height
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final item = widget.products[index];

        return ProductCard(
          image: item.imagePath,
          name: item.name,
          brand: item.brand,
          sku: item.sku,
          barcode: item.barcode,
          purchasePrice: item.buyPrice,
          salePrice: item.sellPrice,
          quantity: item.quantity,
          minQuantity: item.minQuantity,
          storageUnit: item.storageUnit,
          saleUnit: item.saleUnit,
          isLowStock: item.isLowStock,
          onEdit: () => widget.onEdit(item),
          onDelete: () => widget.onDelete(item),
          showPurchasePrice: ProductAccess.canAccessPurchasePrice(widget.role),
          showProfit: ProductAccess.canAccessProfit(widget.role),
        );
      },
    );
  }
}
