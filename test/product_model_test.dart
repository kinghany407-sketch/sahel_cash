import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/helpers/selling_helper.dart';
import 'package:sahel_cash/models/product_model.dart';
import 'package:sahel_cash/models/invoice_model.dart';
import 'package:sahel_cash/models/invoice_item_model.dart';

void main() {
  group('Product display helpers', () {
    test('whole quantities display as whole numbers', () {
      final product = Product(
        name: 'ماء',
        barcode: '123',
        sku: 'SKU-1',
        category: 'مشروبات',
        brand: 'Sahel',
        buyPrice: 10,
        sellPrice: 12,
        quantity: 5.0,
        minQuantity: 3.0,
        description: '',
        saleUnit: 'قطعة',
      );

      expect(product.displayQuantity, '5');
    });

    test('decimal quantities stay readable', () {
      final product = Product(
        name: 'أرز',
        barcode: '456',
        sku: 'SKU-2',
        category: 'مواد غذائية',
        brand: 'Sahel',
        buyPrice: 20,
        sellPrice: 25,
        quantity: 2.75,
        minQuantity: 3.0,
        description: '',
        saleUnit: 'كيلو',
      );

      expect(product.displayQuantity, '2.75');
    });

    test('stock reduction should treat same storage and sale units case-insensitively after trimming', () {
      final result = SellingHelper.calculateStockReduction(
        3,
        ' كيلو ',
        'كيلو',
        1000,
      );

      expect(result, 3);
    });

    test('invoice and invoice item models map cleanly', () {
      final invoice = Invoice(
        id: 1,
        invoiceNumber: '20260914-120000',
        date: '2026-09-14T12:00:00.000',
        total: 25.5,
        paymentMethod: 'cash',
        customerId: null,
        notes: 'نقدي',
      );

      final item = InvoiceItem(
        id: 1,
        invoiceId: 1,
        productId: 10,
        productName: 'برتقال',
        saleUnit: 'كيلو',
        quantity: 2,
        unitPrice: 12.75,
        total: 25.5,
        isWholesale: false,
      );

      expect(invoice.toMap()['invoiceNumber'], '20260914-120000');
      expect(item.toMap()['productName'], 'برتقال');
    });

    test('products below minimum quantity are flagged as low stock', () {
      final product = Product(
        name: 'شوكولاتة',
        barcode: '789',
        sku: 'SKU-3',
        category: 'حلويات',
        brand: 'Sahel',
        buyPrice: 5,
        sellPrice: 7,
        quantity: 2.0,
        minQuantity: 3.0,
        description: '',
        saleUnit: 'قطعة',
      );

      expect(product.isLowStock, isTrue);
    });

  });
}
