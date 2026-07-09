import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final String image;
  final String name;
  final String sku;
  final String barcode;
  final double purchasePrice;
  final double salePrice;
  final int quantity;

  const ProductCard({
    super.key,
    required this.image,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    final profit = salePrice - purchasePrice;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(
                Icons.inventory_2,
                size: 40,
                color: Colors.indigo,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 8),

            Text("SKU : $sku"),
            Text("Barcode : $barcode"),

            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("شراء : ${purchasePrice.toStringAsFixed(2)}"),
                Text("بيع : ${salePrice.toStringAsFixed(2)}"),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("الكمية : $quantity"),
                Text(
                  "ربح : ${profit.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.blue,
                  ),
                ),

                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}