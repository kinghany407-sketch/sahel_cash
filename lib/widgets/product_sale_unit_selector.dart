import 'package:flutter/material.dart';

import '../models/product_sale_unit_model.dart';

class ProductSaleUnitSelector extends StatelessWidget {
  final List<ProductSaleUnit> units;
  final ProductSaleUnit? selectedUnit;
  final ValueChanged<ProductSaleUnit> onSelected;

  const ProductSaleUnitSelector({
    super.key,
    required this.units,
    required this.selectedUnit,
    required this.onSelected,
  });

  String _priceLabel(ProductSaleUnit unit) {
    final prices = <String>[];
    if (unit.retailPrice != null) {
      prices.add('قطاعي ${unit.retailPrice!.toStringAsFixed(2)} ج.م');
    }
    if (unit.wholesalePrice != null) {
      prices.add('جملة ${unit.wholesalePrice!.toStringAsFixed(2)} ج.م');
    }
    return prices.join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ProductSaleUnit>(
      initialValue: selectedUnit,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'وحدة البيع',
        prefixIcon: Icon(Icons.straighten),
        border: OutlineInputBorder(),
      ),
      hint: const Text('اختر وحدة البيع'),
      items: units.map((unit) {
        return DropdownMenuItem<ProductSaleUnit>(
          value: unit,
          child: Text(
            '${unit.saleUnit} — ${_priceLabel(unit)}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (unit) {
        if (unit != null) onSelected(unit);
      },
    );
  }
}
