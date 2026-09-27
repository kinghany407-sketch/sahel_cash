import 'dart:io';

import 'package:flutter/material.dart';

import 'app_styles.dart';

class ProductCard extends StatelessWidget {
  final String image;
  final String name;
  final String brand;
  final String sku;
  final String barcode;
  final double purchasePrice;
  final double salePrice;
  final double quantity;
  final double minQuantity;
  final String storageUnit;
  final String saleUnit;
  final bool isLowStock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showPurchasePrice;
  final bool showProfit;

  const ProductCard({
    super.key,
    required this.image,
    required this.name,
    required this.brand,
    required this.sku,
    required this.barcode,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    required this.minQuantity,
    required this.storageUnit,
    required this.saleUnit,
    required this.isLowStock,
    required this.onEdit,
    required this.onDelete,
    this.showPurchasePrice = true,
    this.showProfit = true,
  });

  @override
  Widget build(BuildContext context) {
    final profit = salePrice - purchasePrice;
    final quantityText = quantity == quantity.toInt()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);
    final minQuantityText = minQuantity == minQuantity.toInt()
        ? minQuantity.toInt().toString()
        : minQuantity.toStringAsFixed(2);
    
    // Stock status
    String stockStatus;
    String stockIcon;
    if (quantity <= 0) {
      stockStatus = 'نفد';
      stockIcon = '🔴';
    } else if (isLowStock) {
      stockStatus = 'منخفض';
      stockIcon = '🔴';
    } else {
      stockStatus = 'جيد';
      stockIcon = '🟢';
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: AppStyles.elevationSm,
        color: isLowStock ? AppStyles.errorColor.withValues(alpha: 0.05) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isLowStock
                ? AppStyles.errorColor.withValues(alpha: 0.3)
                : Colors.grey.shade200,
            width: isLowStock ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              // Product information (RTL - on the right)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                    // Product name with warning icon
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        if (isLowStock)
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppStyles.errorColor,
                            size: 16,
                          ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Brand, SKU, Barcode in compact row
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        if (brand.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              brand,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            'SKU: $sku',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (barcode.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'باركود: $barcode',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Prices and quantity in compact row
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        if (showPurchasePrice)
                          Flexible(
                            child: Text(
                              'شراء: ${purchasePrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'بيع: ${salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.primaryColor,
                            ),
                          ),
                        ),
                        if (showProfit) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'ربح: ${profit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppStyles.successColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Stock status with visible text
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          '$stockIcon $stockStatus',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: quantity <= 0
                                ? const Color(0xFFD32F2F)
                                : isLowStock
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF388E3C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Quantity and min quantity
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Flexible(
                          child: Text(
                            'الكمية: $quantityText ${storageUnit != saleUnit ? '$storageUnit ($saleUnit)' : saleUnit}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: quantity <= 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'الحد الأدنى: $minQuantityText',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      textDirection: TextDirection.rtl,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            onPressed: onEdit,
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 16,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            onPressed: onDelete,
                            icon: const Icon(
                              Icons.delete,
                              color: AppStyles.errorColor,
                              size: 16,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppStyles.errorColor.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Product image on the left - 80x80
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: image.isNotEmpty
                      ? Image.file(
                          File(image),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.inventory_2,
                            size: 36,
                            color: AppStyles.primaryColor.withValues(alpha: 0.5),
                          ),
                        )
                      : Icon(
                          Icons.inventory_2,
                          size: 36,
                          color: AppStyles.primaryColor.withValues(alpha: 0.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
