import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/helpers/purchase_invoice_unit_helper.dart';
import 'package:sahel_cash/models/purchase_invoice_item_model.dart';
import 'package:sahel_cash/screens/purchases/purchase_invoice_draft_store.dart';

void main() {
  group('Purchase invoice unit conversion', () {
    test('purchase unit converts to storage quantity', () {
      final factor = PurchaseInvoiceUnitHelper.conversionFactorToStorage(
        invoiceUnit: 'عمود',
        purchaseUnit: 'عمود',
        storageUnit: 'قطعة',
        unitsPerPurchaseUnit: 100,
      );

      expect(2 * factor, 200);
    });

    test('storage unit quantity remains unchanged', () {
      final factor = PurchaseInvoiceUnitHelper.conversionFactorToStorage(
        invoiceUnit: 'قطعة',
        purchaseUnit: 'عمود',
        storageUnit: 'قطعة',
        unitsPerPurchaseUnit: 100,
      );

      expect(50 * factor, 50);
    });

    test('same purchase and storage unit is offered once', () {
      expect(
        PurchaseInvoiceUnitHelper.availableUnits(
          purchaseUnit: 'كيلو',
          storageUnit: 'كيلو',
        ),
        ['كيلو'],
      );
    });

    test('unsupported invoice unit is rejected', () {
      expect(
        () => PurchaseInvoiceUnitHelper.conversionFactorToStorage(
          invoiceUnit: 'كرتونة',
          purchaseUnit: 'عمود',
          storageUnit: 'قطعة',
          unitsPerPurchaseUnit: 100,
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'draft store restores invoice fields and lines after screen recreation',
    () {
      final store = PurchaseInvoiceDraftStore.instance;
      store.clear();
      final item = PurchaseInvoiceItem(
        productId: 7,
        quantity: 2,
        purchaseUnit: 'عمود',
        conversionFactor: 100,
        storageQuantity: 200,
        unitPrice: 30,
        total: 60,
        productName: 'أطباق فوم نص',
      );

      store.save(
        PurchaseInvoiceDraft(
          supplierId: 3,
          date: '2026-10-01',
          paymentType: 'credit',
          discountText: '5',
          notes: 'مسودة اختبار',
          items: [item],
          selectedProductId: 7,
          productSearchText: 'أطباق فوم نص',
          selectedUnit: 'عمود',
          quantityText: '2',
          unitPriceText: '30',
          unitPrices: {'عمود': '30', 'قطعة': '0.3'},
        ),
      );

      final restored = PurchaseInvoiceDraftStore.instance.draft!;
      expect(restored.supplierId, 3);
      expect(restored.paymentType, 'credit');
      expect(restored.discountText, '5');
      expect(restored.items.single.storageQuantity, 200);
      expect(restored.selectedUnit, 'عمود');
      expect(restored.unitPriceText, '30');

      store.clear();
      expect(store.draft, isNull);
    },
  );
}
