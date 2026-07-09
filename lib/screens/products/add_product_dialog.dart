import 'package:flutter/material.dart';
import '../../models/product_model.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final skuController = TextEditingController();
  final buyPriceController = TextEditingController();
  final sellPriceController = TextEditingController();
  final quantityController = TextEditingController();
  final minQuantityController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    barcodeController.dispose();
    skuController.dispose();
    buyPriceController.dispose();
    sellPriceController.dispose();
    quantityController.dispose();
    minQuantityController.dispose();
    super.dispose();
  }

  void saveProduct() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      Product(
        name: nameController.text,
        barcode: barcodeController.text,
        sku: skuController.text,
        category: "",
        brand: "",
        buyPrice: double.tryParse(buyPriceController.text) ?? 0,
        sellPrice: double.tryParse(sellPriceController.text) ?? 0,
        quantity: int.tryParse(quantityController.text) ?? 0,
        minQuantity: int.tryParse(minQuantityController.text) ?? 0,
        description: "",
      ),
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "هذا الحقل مطلوب";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "إضافة صنف جديد",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                buildField(
                  controller: nameController,
                  label: "اسم الصنف",
                  icon: Icons.inventory_2,
                ),

                buildField(
                  controller: skuController,
                  label: "SKU",
                  icon: Icons.numbers,
                ),

                buildField(
                  controller: barcodeController,
                  label: "الباركود",
                  icon: Icons.qr_code,
                ),

                buildField(
                  controller: buyPriceController,
                  label: "سعر الشراء",
                  icon: Icons.money,
                  keyboard: TextInputType.number,
                ),

                buildField(
                  controller: sellPriceController,
                  label: "سعر البيع",
                  icon: Icons.attach_money,
                  keyboard: TextInputType.number,
                ),

                buildField(
                  controller: quantityController,
                  label: "الكمية",
                  icon: Icons.production_quantity_limits,
                  keyboard: TextInputType.number,
                ),

                buildField(
                  controller: minQuantityController,
                  label: "الحد الأدنى",
                  icon: Icons.warning_amber_rounded,
                  keyboard: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("إلغاء"),
        ),
        ElevatedButton.icon(
          onPressed: saveProduct,
          icon: const Icon(Icons.save),
          label: const Text("حفظ"),
        ),
      ],
    );
  }
}