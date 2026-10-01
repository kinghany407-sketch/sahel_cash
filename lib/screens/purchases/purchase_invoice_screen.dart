import 'package:flutter/material.dart';

import '../../helpers/purchase_invoice_unit_helper.dart';
import '../../models/product_model.dart';
import '../../models/purchase_invoice_item_model.dart';
import '../../models/purchase_invoice_model.dart';
import '../../models/supplier_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_invoice_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';
import 'purchase_invoice_draft_store.dart';

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
  final PurchaseInvoiceDraftStore _draftStore =
      PurchaseInvoiceDraftStore.instance;
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
  final Map<String, String> _unitPrices = {};
  Supplier? _selectedSupplier;
  Product? _selectedProduct;
  String? _selectedInvoiceUnit;
  DateTime _date = DateTime.now();
  String _invoiceNumber = '...';
  String _paymentType = 'cash';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRestoringDraft = false;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.total);
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);
  int get _selectedUnitsPerPurchaseUnit =>
      _selectedProduct?.unitsPerPurchaseUnit ?? 1;
  double get _selectedConversionFactor {
    final product = _selectedProduct;
    final invoiceUnit = _selectedInvoiceUnit;
    if (product == null || invoiceUnit == null) return 0;
    try {
      return PurchaseInvoiceUnitHelper.conversionFactorToStorage(
        invoiceUnit: invoiceUnit,
        purchaseUnit: product.purchaseUnit,
        storageUnit: product.storageUnit,
        unitsPerPurchaseUnit: _selectedUnitsPerPurchaseUnit.toDouble(),
      );
    } on ArgumentError {
      return 0;
    }
  }

  double get _previewStorageQuantity =>
      (double.tryParse(_quantityController.text.trim()) ?? 0) *
      _selectedConversionFactor;

  List<String> get _availableInvoiceUnits {
    final product = _selectedProduct;
    if (product == null) return const [];
    return PurchaseInvoiceUnitHelper.availableUnits(
      purchaseUnit: product.purchaseUnit,
      storageUnit: product.storageUnit,
    );
  }

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_handleTotalsChanged);
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
      final products = results[1] as List<Product>;
      final draft = _draftStore.draft;
      _isRestoringDraft = true;
      if (draft != null) {
        _discountController.text = draft.discountText;
        _notesController.text = draft.notes;
        _productSearchController.text = draft.productSearchText;
        _quantityController.text = draft.quantityText;
        _unitPriceController.text = draft.unitPriceText;
        _unitPrices.addAll(draft.unitPrices);
        _items.addAll(draft.items);
        _selectedProduct = products
            .where((product) => product.id == draft.selectedProductId)
            .firstOrNull;
        _selectedInvoiceUnit =
            draft.selectedUnit ?? _selectedProduct?.purchaseUnit;
        _date = DateTime.tryParse(draft.date) ?? _date;
        _paymentType = draft.paymentType;
      }
      _isRestoringDraft = false;
      setState(() {
        _suppliers = suppliers;
        _products = products;
        _invoiceNumber = results[2] as String;
        _selectedSupplier =
            suppliers
                .where((supplier) => supplier.id == draft?.supplierId)
                .firstOrNull ??
            suppliers
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
      _selectedInvoiceUnit = product.purchaseUnit;
      _unitPrices.clear();
      _productSearchController.text = product.name;
      _unitPriceController.text = product.buyPrice.toStringAsFixed(2);
      _unitPrices[product.purchaseUnit] = _unitPriceController.text;
    });
    _saveDraft();
  }

  void _changeInvoiceUnit(String? unit) {
    final product = _selectedProduct;
    if (product == null || unit == null) return;

    final previousUnit = _selectedInvoiceUnit;
    if (previousUnit != null) {
      _unitPrices[previousUnit] = _unitPriceController.text;
    }

    setState(() {
      _selectedInvoiceUnit = unit;
      _unitPriceController.text =
          _unitPrices[unit] ??
          (unit == product.purchaseUnit
              ? product.buyPrice.toStringAsFixed(2)
              : '');
      _unitPrices[unit] = _unitPriceController.text;
    });
    _saveDraft();
  }

  void _addProduct() {
    final product = _selectedProduct;
    final quantity = double.tryParse(_quantityController.text.trim());
    final unitPrice = double.tryParse(_unitPriceController.text.trim());
    if (product?.id == null ||
        _selectedInvoiceUnit == null ||
        _selectedConversionFactor <= 0 ||
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
          purchaseUnit: _selectedInvoiceUnit!,
          conversionFactor: _selectedConversionFactor,
          storageQuantity: quantity * _selectedConversionFactor,
          unitPrice: unitPrice,
          total: quantity * unitPrice,
        ),
      );
      _selectedProduct = null;
      _selectedInvoiceUnit = null;
      _unitPrices.clear();
      _productSearchController.clear();
      _quantityController.text = '1';
      _unitPriceController.clear();
    });
    _saveDraft();
  }

  void _handleTotalsChanged() {
    if (!mounted) return;
    setState(() {});
    _saveDraft();
  }

  void _saveDraft() {
    if (_isRestoringDraft) return;
    if (_selectedInvoiceUnit != null) {
      _unitPrices[_selectedInvoiceUnit!] = _unitPriceController.text;
    }
    _draftStore.save(
      PurchaseInvoiceDraft(
        supplierId: _selectedSupplier?.id,
        date: _date.toIso8601String(),
        paymentType: _paymentType,
        discountText: _discountController.text,
        notes: _notesController.text,
        items: List<PurchaseInvoiceItem>.of(_items),
        selectedProductId: _selectedProduct?.id,
        productSearchText: _productSearchController.text,
        selectedUnit: _selectedInvoiceUnit,
        quantityText: _quantityController.text,
        unitPriceText: _unitPriceController.text,
        unitPrices: Map<String, String>.of(_unitPrices),
      ),
    );
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
    if (picked != null) {
      setState(() => _date = picked);
      _saveDraft();
    }
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
      _draftStore.clear();
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

  Future<void> _confirmClearDraft() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          Directionality(
            textDirection: TextDirection.rtl,
            child: DraggableDialog(
              title: 'تفريغ مسودة الفاتورة',
              width: 420,
              height: 230,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('سيتم حذف جميع بيانات المسودة الحالية.'),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('رجوع'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppStyles.errorColor,
                            ),
                            child: const Text('تفريغ المسودة'),
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
    if (confirmed != true) return;

    setState(() {
      _selectedSupplier = _suppliers
          .where((supplier) => supplier.id == widget.supplierId)
          .firstOrNull;
      _selectedProduct = null;
      _selectedInvoiceUnit = null;
      _date = DateTime.now();
      _paymentType = 'cash';
      _items.clear();
      _unitPrices.clear();
      _productSearchController.clear();
      _quantityController.text = '1';
      _unitPriceController.clear();
      _discountController.text = '0';
      _notesController.clear();
    });
    _draftStore.clear();
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
        appBar: AppBar(
          title: const Text('فاتورة شراء'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'تفريغ المسودة',
              onPressed: _confirmClearDraft,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
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
                                  onChanged: (supplier) {
                                    setState(
                                      () => _selectedSupplier = supplier,
                                    );
                                    _saveDraft();
                                  },
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
                                  onChanged: (_) {
                                    setState(() {
                                      _selectedProduct = null;
                                      _selectedInvoiceUnit = null;
                                      _unitPrices.clear();
                                      _unitPriceController.clear();
                                    });
                                    _saveDraft();
                                  },
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
                                if (_selectedProduct != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppStyles.primaryColor.withValues(
                                        alpha: 0.06,
                                      ),
                                      border: Border.all(
                                        color: AppStyles.primaryColor
                                            .withValues(alpha: 0.2),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'وحدة الشراء: ${_selectedProduct!.purchaseUnit}',
                                        ),
                                        Text(
                                          'وحدة التخزين: ${_selectedProduct!.storageUnit}',
                                        ),
                                        Text(
                                          'تحويل المنتج: 1 ${_selectedProduct!.purchaseUnit} = $_selectedUnitsPerPurchaseUnit ${_selectedProduct!.storageUnit}',
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<String>(
                                          key: ValueKey(
                                            'invoice-unit-${_selectedProduct!.id}',
                                          ),
                                          initialValue: _selectedInvoiceUnit,
                                          decoration: const InputDecoration(
                                            labelText: 'وحدة الفاتورة *',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: _availableInvoiceUnits
                                              .map(
                                                (unit) => DropdownMenuItem(
                                                  value: unit,
                                                  child: Text(unit),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: _changeInvoiceUnit,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'تحويل وحدة الفاتورة: 1 ${_selectedInvoiceUnit ?? ''} = ${formatQuantity(_selectedConversionFactor)} ${_selectedProduct!.storageUnit}',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الكمية التي ستضاف للمخزون: ${formatQuantity(_previewStorageQuantity)} ${_selectedProduct!.storageUnit}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                          labelText: 'الكمية بوحدة الفاتورة',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (_) {
                                          setState(() {});
                                          _saveDraft();
                                        },
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
                                        decoration: InputDecoration(
                                          labelText:
                                              _selectedInvoiceUnit == null
                                              ? 'سعر الوحدة المختارة'
                                              : 'سعر $_selectedInvoiceUnit',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          if (_selectedInvoiceUnit != null) {
                                            _unitPrices[_selectedInvoiceUnit!] =
                                                value;
                                          }
                                          _saveDraft();
                                        },
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
                                        '${formatQuantity(entry.value.quantity)} ${entry.value.purchaseUnit} × ${entry.value.unitPrice.toStringAsFixed(2)} | ${formatQuantity(entry.value.storageQuantity)} مخزون',
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
                                            onPressed: () {
                                              setState(
                                                () =>
                                                    _items.removeAt(entry.key),
                                              );
                                              _saveDraft();
                                            },
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
                                  onChanged: (value) {
                                    setState(
                                      () => _paymentType = value ?? 'cash',
                                    );
                                    _saveDraft();
                                  },
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
                                  onChanged: (_) => _saveDraft(),
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
      ..removeListener(_handleTotalsChanged)
      ..dispose();
    _notesController.dispose();
    _dateDialogController.dispose();
    super.dispose();
  }
}
