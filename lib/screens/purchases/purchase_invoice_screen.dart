import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../models/purchase_invoice_item_model.dart';
import '../../models/purchase_invoice_model.dart';
import '../../models/supplier_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class PurchaseInvoiceScreen extends StatefulWidget {
  final int? supplierId;

  const PurchaseInvoiceScreen({super.key, this.supplierId});

  @override
  State<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends State<PurchaseInvoiceScreen> {
  final SupplierRepository _supplierRepository = SupplierRepository();
  final ProductRepository _productRepository = ProductRepository();
  final PurchaseInvoiceRepository _invoiceRepository =
      PurchaseInvoiceRepository();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();
  final DraggableDialogController _dateDialogController =
      DraggableDialogController();

  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  final List<PurchaseInvoiceItem> _items = [];
  Supplier? _selectedSupplier;
  Product? _selectedProduct;
  DateTime _date = DateTime.now();
  String _invoiceNumber = '...';
  String _paymentType = 'cash';
  bool _isLoading = true;
  bool _isSaving = false;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.total);
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_refreshTotals);
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final results = await Future.wait([
        _supplierRepository.getAllSuppliers(),
        _productRepository.getProducts(),
        _invoiceRepository.getNextInvoiceNumber(),
      ]);
      if (!mounted) return;
      final suppliers = results[0] as List<Supplier>;
      setState(() {
        _suppliers = suppliers;
        _products = results[1] as List<Product>;
        _invoiceNumber = results[2] as String;
        _selectedSupplier = suppliers
            .where((supplier) => supplier.id == widget.supplierId)
            .firstOrNull;
      });
    } catch (error) {
      if (mounted) _showError('تعذر تحميل بيانات الفاتورة: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Product> get _matchingProducts {
    final query = _productSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    return _products
        .where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query);
        })
        .take(10)
        .toList();
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _productSearchController.text = product.name;
      _unitPriceController.text = product.buyPrice.toStringAsFixed(2);
    });
  }

  void _addProduct() {
    final product = _selectedProduct;
    final quantity = double.tryParse(_quantityController.text.trim());
    final unitPrice = double.tryParse(_unitPriceController.text.trim());
    if (product?.id == null ||
        quantity == null ||
        quantity <= 0 ||
        unitPrice == null ||
        unitPrice < 0) {
      _showError('اختر منتجاً وأدخل كمية وسعر شراء صحيحين');
      return;
    }

    setState(() {
      _items.add(
        PurchaseInvoiceItem(
          productId: product!.id!,
          productName: product.name,
          quantity: quantity,
          unitPrice: unitPrice,
          total: quantity * unitPrice,
        ),
      );
      _selectedProduct = null;
      _productSearchController.clear();
      _quantityController.text = '1';
      _unitPriceController.clear();
    });
  }

  void _refreshTotals() {
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          Directionality(
            textDirection: TextDirection.rtl,
            child: DraggableDialog(
              controller: _dateDialogController,
              title: 'اختيار تاريخ الفاتورة',
              width: 380,
              height: 440,
              child: Column(
                children: [
                  Expanded(
                    child: CalendarDatePicker(
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      onDateChanged: (date) =>
                          Navigator.of(dialogContext).pop(date),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _saveInvoice() async {
    if (_selectedSupplier?.id == null) {
      _showError('اختر المورد');
      return;
    }
    if (_items.isEmpty) {
      _showError('أضف منتجاً واحداً على الأقل');
      return;
    }
    if (_discount < 0 || _discount > _subtotal) {
      _showError('الخصم يجب أن يكون بين صفر والإجمالي الفرعي');
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now().toIso8601String();
    final invoice = PurchaseInvoice(
      invoiceNumber: _invoiceNumber,
      supplierId: _selectedSupplier!.id!,
      date: _date.toIso8601String(),
      subtotal: _subtotal,
      discount: _discount,
      totalAmount: _total,
      paymentType: _paymentType,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _invoiceRepository.createPurchaseInvoice(invoice, _items);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError('تعذر حفظ فاتورة الشراء: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppStyles.errorColor),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.backgroundColor,
        appBar: AppBar(title: const Text('فاتورة شراء'), centerTitle: true),
        body: _suppliers.isEmpty
            ? const Center(child: Text('أضف مورداً أولاً لإنشاء فاتورة شراء'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'رقم الفاتورة: $_invoiceNumber',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _pickDate,
                                      icon: const Icon(Icons.calendar_month),
                                      label: Text(_formatDate(_date)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<Supplier>(
                                  initialValue: _selectedSupplier,
                                  decoration: const InputDecoration(
                                    labelText: 'المورد *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _suppliers
                                      .map(
                                        (supplier) => DropdownMenuItem(
                                          value: supplier,
                                          child: Text(supplier.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (supplier) => setState(
                                    () => _selectedSupplier = supplier,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'إضافة منتجات',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _productSearchController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'بحث عن منتج بالاسم أو الباركود أو SKU',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _selectedProduct = null),
                                ),
                                if (_matchingProducts.isNotEmpty)
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: _matchingProducts
                                          .map(
                                            (product) => ListTile(
                                              dense: true,
                                              title: Text(product.name),
                                              subtitle: Text(
                                                'سعر الشراء: ${product.buyPrice.toStringAsFixed(2)}',
                                              ),
                                              onTap: () =>
                                                  _selectProduct(product),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: TextField(
                                        controller: _quantityController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'الكمية',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 180,
                                      child: TextField(
                                        controller: _unitPriceController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'سعر الوحدة',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: _addProduct,
                                      icon: const Icon(Icons.add),
                                      label: const Text('إضافة'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_items.isEmpty)
                                  const Text(
                                    'لم تتم إضافة منتجات بعد',
                                    textAlign: TextAlign.center,
                                  )
                                else
                                  ..._items.asMap().entries.map(
                                    (entry) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        entry.value.productName ?? 'منتج',
                                      ),
                                      subtitle: Text(
                                        '${entry.value.quantity} × ${entry.value.unitPrice.toStringAsFixed(2)}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            entry.value.total.toStringAsFixed(
                                              2,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'حذف المنتج',
                                            onPressed: () => setState(
                                              () => _items.removeAt(entry.key),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: AppStyles.errorColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _summaryRow('الإجمالي الفرعي', _subtotal),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'الخصم',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _summaryRow(
                                  'الإجمالي',
                                  _total,
                                  emphasized: true,
                                ),
                                const Divider(height: 28),
                                const Text(
                                  'طريقة الدفع',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                RadioGroup<String>(
                                  groupValue: _paymentType,
                                  onChanged: (value) => setState(
                                    () => _paymentType = value ?? 'cash',
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        child: RadioListTile<String>(
                                          value: 'cash',
                                          title: Text('نقدي'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<String>(
                                          value: 'credit',
                                          title: Text('آجل'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextField(
                                  controller: _notesController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'ملاحظات',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _isSaving ? null : _saveInvoice,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: const Text('حفظ فاتورة الشراء'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool emphasized = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
            fontSize: emphasized ? 18 : 14,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _discountController
      ..removeListener(_refreshTotals)
      ..dispose();
    _notesController.dispose();
    _dateDialogController.dispose();
    super.dispose();
  }
}
