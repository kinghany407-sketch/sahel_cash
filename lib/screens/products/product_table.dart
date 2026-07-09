import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import 'product_card.dart';

class ProductTable extends StatefulWidget {
  final List<Product> products;

  const ProductTable({
    super.key,
    required this.products,
  });

  @override
  State<ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<ProductTable> {
  bool isGrid = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                isGrid = !isGrid;
              });
            },
            icon: Icon(
              isGrid ? Icons.table_rows : Icons.grid_view,
            ),
            label: Text(
              isGrid ? "عرض جدول" : "عرض كروت",
            ),
          ),
        ),

        Expanded(
          child: widget.products.isEmpty
              ? const Center(
                  child: Text(
                    "لا توجد أصناف حتى الآن",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                )
              : (isGrid ? buildGrid() : buildTable()),
        ),
      ],
    );
  }

  Widget buildTable() {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text("اختبار")),
          DataColumn(label: Text("SKU")),
          DataColumn(label: Text("البيع")),
          DataColumn(label: Text("الكمية")),
          DataColumn(label: Text("الحالة")),
        ],
        rows: widget.products.map((item) {
          final bool lowStock = item.quantity <= item.minQuantity;

          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>(
              (states) {
                if (lowStock) {
                  return Colors.red.shade100;
                }
                return null;
              },
            ),
            cells: [
              DataCell(Text(item.name)),
              DataCell(Text(item.sku)),
              DataCell(Text(item.sellPrice.toStringAsFixed(2))),
              DataCell(Text(item.quantity.toString())),
              DataCell(
                lowStock
                    ? const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "مخزون منخفض",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "جيد",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget buildGrid() {
    return GridView.builder(
      itemCount: widget.products.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = widget.products[index];

        return ProductCard(
          image: "",
          name: item.name,
          sku: item.sku,
          barcode: item.barcode,
          purchasePrice: item.buyPrice,
          salePrice: item.sellPrice,
          quantity: item.quantity,
        );
      },
    );
  }
}