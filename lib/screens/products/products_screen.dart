import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import 'add_product_dialog.dart';
import 'product_search.dart';
import 'product_table.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final List<Product> products = [];

  final TextEditingController searchController = TextEditingController();

  String searchText = "";

  void _addProduct(Product product) {
    setState(() {
      products.add(product);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = products.where((product) {
      final query = searchText.toLowerCase();

      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("📦 إدارة الأصناف"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProductSearch(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),

            const SizedBox(height: 15),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("إضافة صنف"),
                onPressed: () async {
                  final Product? product = await showDialog<Product>(
                    context: context,
                    builder: (_) => const AddProductDialog(),
                  );

                  if (product != null) {
                    _addProduct(product);
                  }
                },
              ),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: ProductTable(
                products: filteredProducts,
              ),
            ),
          ],
        ),
      ),
    );
  }
}