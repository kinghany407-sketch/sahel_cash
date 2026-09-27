import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../models/product_sale_unit_model.dart';
import '../repositories/product_repository.dart';
import '../screens/products/app_styles.dart';

class CashierProductSearchCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const CashierProductSearchCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  State<CashierProductSearchCard> createState() =>
      _CashierProductSearchCardState();
}

class _CashierProductSearchCardState extends State<CashierProductSearchCard> {
  final ProductRepository _repository = ProductRepository();
  List<ProductSaleUnit> _saleUnits = [];
  bool _isLoadingUnits = true;

  @override
  void initState() {
    super.initState();
    _loadSaleUnits();
  }

  Future<void> _loadSaleUnits() async {
    try {
      final units = await _repository.getSaleUnits(widget.product.id ?? 0);
      if (!mounted) return;

      setState(() {
        _saleUnits = units;
        _isLoadingUnits = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saleUnits = [];
        _isLoadingUnits = false;
      });
    }
  }

  String _categoryIcon(String category) {
    final normalized = category
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');

    if (normalized.contains('فوم')) return '🍽️';
    if (normalized.contains('شنط')) return '👜';
    if (normalized.contains('اكياس')) return '🛍️';
    if (normalized.contains('فويل')) return '✨';
    if (normalized.contains('كوب') ||
        normalized.contains('اكواب') ||
        normalized.contains('كوبيات')) return '🥤';
    if (normalized.contains('ورقي') || normalized.contains('ورقية')) return '📄';
    if (normalized.contains('كرتون')) return '📦';
    if (normalized.contains('بكر')) return '🎗️';
    if (normalized.contains('مناديل')) return '🧻';

    return '🏷️';
  }

  Color _stockColor(double quantity, double minQuantity) {
    if (quantity > minQuantity) return Colors.green;
    if (quantity > 0 && quantity <= minQuantity) return Colors.orange;
    return Colors.red;
  }

  String _stockStatusText(double quantity, double minQuantity) {
    if (quantity > minQuantity) return 'متوفر';
    if (quantity > 0 && quantity <= minQuantity) return 'مخزون منخفض';
    return 'نفد';
  }

  double _displayPrice() {
    if (_saleUnits.isNotEmpty) {
      return _saleUnits.first.retailPrice;
    }

    return widget.product.sellPrice;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final categoryIcon = _categoryIcon(product.category);
    final stockColor = _stockColor(product.quantity, product.minQuantity);
    final stockStatus = _stockStatusText(product.quantity, product.minQuantity);
    final displayPrice = _displayPrice();
    final isOutOfStock = product.quantity <= 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Opacity(
          opacity: isOutOfStock ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: 70,
                    child: Stack(
                      children: [
                        product.imagePath.isNotEmpty && File(product.imagePath).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(product.imagePath),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildCategoryFallback(categoryIcon),
                                ),
                              )
                            : _buildCategoryFallback(categoryIcon),
                        if (isOutOfStock)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppStyles.errorColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'نفد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'الكمية: ${product.displayQuantity}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: stockColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stockStatus,
                          style: TextStyle(
                            fontSize: 14,
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${displayPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (!_isLoadingUnits)
                      Text(
                        _saleUnits.isNotEmpty ? _saleUnits.first.saleUnit : product.saleUnit,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFallback(String icon) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppStyles.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          icon,
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );
  }
}
