import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../widgets/draggable_dialog.dart';
import 'access_control.dart';
import 'add_product_dialog.dart';
import 'app_styles.dart';
import 'master_data_screen.dart';
import 'product_search.dart';
import 'product_table.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductRepository _repository = ProductRepository();
  final DraggableDialogController _dialogController = DraggableDialogController();

  final List<Product> products = [];
  final TextEditingController searchController = TextEditingController();

  String searchText = '';
  bool _isLoading = true;
  UserRole _currentRole = UserRole.admin;
  bool _isGridView = false;

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
        products
          ..clear()
          ..addAll(loadedProducts);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الأصناف: $e'),
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

  Future<void> _showAddDialog() async {
    final Product? product = await showGeneralDialog<Product>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) => AddProductDialog(role: _currentRole),
    );

    if (product == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة الصنف بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadProducts();
    }
  }

  Future<void> _showEditDialog(Product product) async {
    final currentViewMode = _isGridView;
    final currentSearchText = searchText;
    
    final Product? updatedProduct = await showGeneralDialog<Product>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) =>
          AddProductDialog(product: product, role: _currentRole),
    );

    if (updatedProduct == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الصنف بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Preserve view mode and search text
      setState(() {
        _isGridView = currentViewMode;
        searchText = currentSearchText;
      });
      await _loadProducts();
    }
  }

  Future<void> _showViewDialog(Product product) async {
    await showGeneralDialog<Product>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) => AddProductDialog(
        product: product,
        role: _currentRole,
        readOnly: true,
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final bool? confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) {
        return DraggableDialog(
          controller: _dialogController,
          title: 'تأكيد الحذف',
          width: 400,
          height: 250,
          child: AlertDialog(
            title: const Text(
              'تأكيد الحذف',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text('هل تريد حذف الصنف "${product.name}"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.errorColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || product.id == null) return;

    try {
      await _repository.deleteProduct(product.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الصنف بنجاح'),
            backgroundColor: AppStyles.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الصنف: $e'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  String _normalizeArabicSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = products.where((product) {
      final query = searchText.toLowerCase().trim();
      final normalizedNameQuery = _normalizeArabicSearchText(searchText);
      
      if (query.isEmpty) return true;
      
      // Search by name
      final nameMatch = _normalizeArabicSearchText(product.name).contains(
        normalizedNameQuery,
      );
      
      // Search by SKU (only if SKU is not empty)
      bool skuMatch = false;
      if (product.sku.isNotEmpty) {
        final productSku = product.sku.toLowerCase().trim();
        skuMatch = productSku.contains(query);
      }
      
      // Search by barcode (only if barcode is not empty)
      bool barcodeMatch = false;
      if (product.barcode.isNotEmpty) {
        final productBarcode = product.barcode.toLowerCase().trim();
        barcodeMatch = productBarcode.contains(query);
      }
      
      return nameMatch || skuMatch || barcodeMatch;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Header with product count badge on the right
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Text(
                      '📦 إدارة الأصناف',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _isLoading ? null : _loadProducts,
                      tooltip: 'تحديث',
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<UserRole>(
                          value: _currentRole,
                          items: UserRole.values.map((role) {
                            return DropdownMenuItem<UserRole>(
                              value: role,
                              child: Text(
                                ProductAccess.roleLabel(role),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _currentRole = value);
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppStyles.primaryColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Product count badge on the right
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${filteredProducts.length} أصناف',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Compact toolbar
                SizedBox(
                  height: 36,
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: ProductSearch(
                          controller: searchController,
                          onChanged: (value) {
                            setState(() => searchText = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _showAddDialog,
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('إضافة صنف', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MasterDataScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.dataset, size: 14),
                          label: const Text('البيانات الأساسية', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.primaryColor.withValues(alpha: 0.1),
                            foregroundColor: AppStyles.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Product list
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadProducts,
                          child: ProductTable(
                            products: filteredProducts,
                            onEdit: _showEditDialog,
                            onDelete: _confirmDelete,
                            onView: _showViewDialog,
                            role: _currentRole,
                            initialIsGrid: _isGridView,
                            onViewModeChanged: (isGrid) {
                              setState(() => _isGridView = isGrid);
                            },
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
}
