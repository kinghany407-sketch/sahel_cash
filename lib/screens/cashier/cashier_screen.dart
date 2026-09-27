import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/services.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../helpers/selling_helper.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/product_sale_unit_model.dart';
import '../../repositories/product_repository.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/cashier_product_search_card.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

class CartItem {
  final Product product;
  final ProductSaleUnit selectedSaleUnit;
  double quantity;
  bool isWholesale;
  SellingMethod sellingMethod;
  double amount;

  CartItem({
    required this.product,
    required this.selectedSaleUnit,
    this.quantity = 1,
    this.isWholesale = false,
    this.sellingMethod = SellingMethod.quantity,
    this.amount = 0,
  });

  double get unitPrice {
    double rawPrice = selectedSaleUnit.retailPrice;
    final wholesalePrice = selectedSaleUnit.wholesalePrice;

    if (isWholesale && wholesalePrice != null) {
      rawPrice = wholesalePrice;
    }

    final saleUnit = selectedSaleUnit.saleUnit.trim().toLowerCase();
    final factor = selectedSaleUnit.conversionToStorage;
    final saleUnitIsGram = saleUnit.contains('جرام') || saleUnit.contains('gram');

    // Normalize the gram price from the stored conversion factor only when the
    // row is accidentally carrying the storage-scale price (e.g. 120 for kg)
    // instead of the already-converted gram price.
    if (saleUnitIsGram && factor > 0 && rawPrice >= factor) {
      return rawPrice / factor;
    }

    return rawPrice;
  }

  double get total {
    if (sellingMethod == SellingMethod.amount) {
      return amount;
    }
    return quantity * unitPrice;
  }

  double get stockReduction {
    return quantity * selectedSaleUnit.conversionToStorage;
  }
}

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final ProductRepository _repository = ProductRepository();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final DraggableDialogController _dialogController = DraggableDialogController();

  static final List<CartItem> cartItems = [];
  List<Product> searchResults = [];

  String searchText = '';
  bool _isLoading = false;
  bool _isSearchingByImage = false;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  final int _batchSize = 20;
  String? _currentSearchQuery;
  bool _isImageSearchMode = false;
  double _cartSidebarWidth = 300.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreSearchResults();
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults.clear();
        _currentSearchQuery = null;
        _currentOffset = 0;
        _isImageSearchMode = false;
      });
      return;
    }

    if (_currentSearchQuery != query) {
      // New search query, reset pagination
      setState(() {
        _currentSearchQuery = query;
        _currentOffset = 0;
        searchResults.clear();
        _isLoading = true;
        _isImageSearchMode = false;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final results = await _repository.searchProducts(
        query: query,
        limit: _batchSize,
        offset: _currentOffset,
      );

      if (!mounted) return;

      setState(() {
        if (_currentOffset == 0) {
          searchResults = results;
        } else {
          searchResults.addAll(results);
        }
        _currentOffset += results.length;
        _isLoading = false;
        _isLoadingMore = results.length >= _batchSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في البحث: $e'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreSearchResults() async {
    if (_isLoadingMore) return;

    if (_isImageSearchMode) {
      await _loadMoreImageResults();
    } else if (_currentSearchQuery != null) {
      await _performSearch(_currentSearchQuery!);
    }
  }

  Future<void> _loadMoreImageResults() async {
    setState(() => _isLoadingMore = true);

    try {
      final results = await _repository.getProductsWithImages(
        limit: _batchSize,
        offset: _currentOffset,
      );

      if (!mounted) return;

      setState(() {
        searchResults.addAll(results);
        _currentOffset += results.length;
        _isLoadingMore = results.length >= _batchSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المزيد: $e'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _searchByImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isSearchingByImage = true;
        _isImageSearchMode = true;
        _currentOffset = 0;
        searchResults.clear();
        _isLoading = true;
      });

      // Search for products with images using pagination
      final imageResults = await _repository.getProductsWithImages(
        limit: _batchSize,
        offset: 0,
      );

      if (!mounted) return;

      setState(() {
        searchResults = imageResults;
        _currentOffset = imageResults.length;
        _isLoading = false;
        _isSearchingByImage = false;
        _isLoadingMore = imageResults.length >= _batchSize;
      });

      if (imageResults.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على أصناف لديها صور'),
              backgroundColor: AppStyles.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingByImage = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في البحث بالصورة: $e'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  ProductSaleUnit _buildFallbackSaleUnit(Product product) {
    return ProductSaleUnit(
      productId: product.id ?? 0,
      saleUnit: product.storageUnit.isEmpty ? 'قطعة' : product.storageUnit,
      retailPrice: product.sellPrice,
      wholesalePrice: null,
      conversionToStorage: product.conversionFactor,
      allowSellingByAmount: false,
    );
  }

  bool _isCompatibleWithStorageUnit(Product product, ProductSaleUnit unit) {
    final storageUnit = product.storageUnit.trim().toLowerCase();
    final saleUnit = unit.saleUnit.trim().toLowerCase();
    
    print('DEBUG: _isCompatibleWithStorageUnit - storageUnit: $storageUnit, saleUnit: $saleUnit');

    if (storageUnit.contains('كيلو') || storageUnit.contains('kg')) {
      final result = saleUnit.contains('كيلو') || saleUnit.contains('kg');
      print('DEBUG: _isCompatibleWithStorageUnit - Result (kg): $result');
      return result;
    }

    if (storageUnit.contains('جرام') || storageUnit.contains('gram')) {
      final result = saleUnit.contains('جرام') || saleUnit.contains('gram');
      print('DEBUG: _isCompatibleWithStorageUnit - Result (gram): $result');
      return result;
    }

    final result = saleUnit.contains('قطعة') ||
        saleUnit.contains('عمود') ||
        saleUnit.contains('عامود') ||
        saleUnit.contains('piece') ||
        saleUnit.contains('column');
    print('DEBUG: _isCompatibleWithStorageUnit - Result (piece): $result');
    return result;
  }

  double _stockReductionInStorageUnit(
    Product product,
    ProductSaleUnit selectedUnit,
    double quantity,
  ) {
    final storageUnit = product.storageUnit.trim().toLowerCase();
    final saleUnit = selectedUnit.saleUnit.trim().toLowerCase();

    if (saleUnit == storageUnit) {
      return quantity;
    }

    if ((storageUnit.contains('كيلو') || storageUnit.contains('kg')) &&
        (saleUnit.contains('جرام') || saleUnit.contains('gram'))) {
      return quantity * 0.001;
    }

    if ((storageUnit.contains('جرام') || storageUnit.contains('gram')) &&
        (saleUnit.contains('كيلو') || saleUnit.contains('kg'))) {
      return quantity * 1000;
    }

    return quantity * selectedUnit.conversionToStorage;
  }

  Future<void> _handleProductCardTap(Product product) async {
    if (product.quantity <= 0) {
      await _showNoStockDialog(product);
      return;
    }

    await _openProductSelectionDialog(product);
  }

  Future<void> _showNoStockDialog(Product product) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) {
        return DraggableDialog(
          title: 'لا يوجد مخزون',
          width: 400,
          height: 250,
          child: AlertDialog(
            title: const Text(
              'لا يوجد مخزون',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('المنتج غير متوفر حالياً. الكمية المتاحة: ${formatQuantity(0.0)}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showInsufficientStockDialog(
    Product product,
    double requestedQuantity,
    double availableQuantity,
  ) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) {
        return DraggableDialog(
          title: 'الكمية غير متوفرة',
          width: 400,
          height: 280,
          child: AlertDialog(
            title: const Text(
              'الكمية غير متوفرة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('الكمية المطلوبة: ${formatQuantity(requestedQuantity)} ${product.storageUnit}'),
                  Text('الكمية المتاحة: ${formatQuantity(availableQuantity)} ${product.storageUnit}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProductSelectionDialog(Product product) async {
    List<ProductSaleUnit> saleUnits = await _repository.getSaleUnits(product.id ?? 0);
    print('DEBUG: _openProductSelectionDialog - saleUnits.length from DB: ${saleUnits.length}');
    print('DEBUG: _openProductSelectionDialog - saleUnits from DB: ${saleUnits.map((u) => u.saleUnit).toList()}');
    
    print('DEBUG: saleUnits.length before filter: ${saleUnits.length}');
    print('DEBUG: saleUnits: ${saleUnits.map((u) => u.saleUnit).toList()}');
    
    saleUnits = saleUnits
        .where((unit) => _isCompatibleWithStorageUnit(product, unit))
        .toList();
    
    print('DEBUG: saleUnits.length after filter: ${saleUnits.length}');
    print('DEBUG: filtered saleUnits: ${saleUnits.map((u) => u.saleUnit).toList()}');

    if (saleUnits.isEmpty) {
      saleUnits = [_buildFallbackSaleUnit(product)];
    }

    if (!mounted) return;

    ProductSaleUnit selectedUnit = saleUnits.first;
    bool isWholesale = selectedUnit.saleUnit.contains('عمود') ||
                       selectedUnit.saleUnit.contains('عامود');
    SellingMethod selectedMethod = selectedUnit.allowSellingByAmount
        ? SellingMethod.quantity
        : SellingMethod.quantity;
    final quantityController = TextEditingController(text: '1');
    final amountController = TextEditingController(text: '');
    final quantityFocusNode = FocusNode();
    final amountFocusNode = FocusNode();

    quantityFocusNode.addListener(() {
      if (quantityFocusNode.hasFocus) {
        quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: quantityController.text.length,
        );
      }
    });

    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus) {
        amountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: amountController.text.length,
        );
      }
    });

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, __, ___) {
        return DraggableDialog(
          controller: _dialogController,
          title: product.name,
          width: 500,
          height: 600,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final unitPrice = isWholesale && selectedUnit.wholesalePrice != null
                  ? selectedUnit.wholesalePrice!
                  : selectedUnit.retailPrice;
              final quantity = double.tryParse(quantityController.text) ?? 1;
              final amount = double.tryParse(amountController.text) ?? 0;
              final isKilogramUnit = selectedUnit.saleUnit.trim().toLowerCase().contains('كيلو') ||
                  selectedUnit.saleUnit.trim().toLowerCase().contains('kg');
              final displayTotal = selectedMethod == SellingMethod.amount
                  ? amount
                  : quantity * unitPrice;
              final displayQuantity = selectedMethod == SellingMethod.amount
                  ? amount / unitPrice
                  : quantity;
              final displayGrams = isKilogramUnit
                  ? displayQuantity * 1000
                  : 0.0;

              void addToCart() async {
                final parsedQuantity = selectedMethod == SellingMethod.amount
                    ? SellingHelper.calculateQuantityFromAmount(
                        double.tryParse(amountController.text) ?? 0,
                        unitPrice,
                      )
                    : double.tryParse(quantityController.text) ?? 1;

                final parsedAmount = selectedMethod == SellingMethod.amount
                    ? double.tryParse(amountController.text) ?? 0
                    : 0.0;

                if (selectedMethod == SellingMethod.amount && parsedAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل مبلغًا صحيحًا')),
                  );
                  return;
                }

                if (selectedMethod == SellingMethod.quantity && parsedQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل كمية صحيحة')),
                  );
                  return;
                }

                final requestedStockReduction = _stockReductionInStorageUnit(
                  product,
                  selectedUnit,
                  parsedQuantity,
                );
                if (requestedStockReduction > product.quantity) {
                  _showInsufficientStockDialog(
                    product,
                    requestedStockReduction,
                    product.quantity,
                  );
                  return;
                }

                // خصم المخزون فوراً
                product.quantity -= requestedStockReduction;
                await _repository.updateProduct(product);

                final productSaleUnit = selectedUnit;
                final newCartItem = CartItem(
                  product: product,
                  selectedSaleUnit: productSaleUnit,
                  quantity: parsedQuantity,
                  isWholesale: isWholesale,
                  sellingMethod: selectedMethod,
                  amount: parsedAmount,
                );

                setState(() {
                  cartItems.add(newCartItem);
                  searchController.clear();
                  searchText = '';
                  searchResults.clear();
                  _currentSearchQuery = null;
                  _currentOffset = 0;
                  _isImageSearchMode = false;
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم إضافة ${product.name} للفاتورة المعلقة'),
                    backgroundColor: AppStyles.successColor,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }

              return Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                    Navigator.pop(context);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  if (product.imagePath.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.file(
                                        File(product.imagePath),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.inventory_2),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.inventory_2),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.arrow_back, size: 16),
                                    label: const Text('رجوع'),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              if (saleUnits.length > 1)
                                DropdownButtonFormField<ProductSaleUnit>(
                                  value: selectedUnit,
                                  decoration: const InputDecoration(labelText: 'وحدة البيع'),
                                  items: saleUnits.map((unit) {
                                    return DropdownMenuItem<ProductSaleUnit>(
                                      value: unit,
                                      child: Text(unit.saleUnit),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        selectedUnit = value;
                                        isWholesale = value.saleUnit.contains('عمود') ||
                                                      value.saleUnit.contains('عامود');
                                        if (!selectedUnit.allowSellingByAmount) {
                                          selectedMethod = SellingMethod.quantity;
                                        }
                                      });
                                    }
                                  },
                                )
                              else
                                Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    const Text('وحدة البيع: '),
                                    Text(selectedUnit.saleUnit),
                                  ],
                                ),
                              const SizedBox(height: 12),
                              // عرض المخزون
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  const Icon(Icons.inventory_2, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'الكمية في المخزن: ${formatQuantity(product.quantity)} ${product.storageUnit}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // عرض الحالة
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Icon(
                                    product.quantity > product.minQuantity
                                        ? Icons.circle
                                        : product.quantity > 0
                                            ? Icons.circle
                                            : Icons.circle,
                                    size: 12,
                                    color: product.quantity > product.minQuantity
                                        ? Colors.green
                                        : product.quantity > 0
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    product.quantity > product.minQuantity
                                        ? 'متوفر'
                                        : product.quantity > 0
                                            ? 'منخفض'
                                            : 'نفد',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: product.quantity > product.minQuantity
                                          ? Colors.green
                                          : product.quantity > 0
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                textDirection: TextDirection.rtl,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  const Text('نوع السعر:  '),
                                  // Check if unit is "عمود" or "عامود"
                                  if (selectedUnit.wholesalePrice != null && 
                                      !selectedUnit.saleUnit.contains('عمود') && 
                                      !selectedUnit.saleUnit.contains('عامود'))
                                    ChoiceChip(
                                      label: const Text('قطاعي'),
                                      selected: !isWholesale,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          isWholesale = false;
                                          selectedMethod = selectedUnit.allowSellingByAmount
                                              ? SellingMethod.amount
                                              : SellingMethod.quantity;
                                          quantityController.clear();
                                          amountController.clear();
                                        });
                                      },
                                    ),
                                  if (selectedUnit.wholesalePrice != null)
                                    ChoiceChip(
                                      label: const Text('جملة'),
                                      selected: isWholesale,
                                      onSelected: (_) {
                                        setDialogState(() {
                                          isWholesale = true;
                                          selectedMethod = SellingMethod.quantity;
                                          amountController.clear();
                                        });
                                      },
                                    ),
                                  if (selectedUnit.wholesalePrice == null)
                                    const Text('قطاعي'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (isWholesale)
                                const Text('طريقة البيع: بالكمية')
                              else if (selectedUnit.allowSellingByAmount)
                                const Text('طريقة البيع: بالمبلغ')
                              else
                                const Text('طريقة البيع: بالكمية'),
                              const SizedBox(height: 12),
                              if (selectedMethod == SellingMethod.quantity)
                                TextField(
                                  controller: quantityController,
                                  focusNode: quantityFocusNode,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    labelText: 'الكمية',
                                    labelStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: const BorderSide(width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  autofocus: true,
                                  onChanged: (_) => setDialogState(() {}),
                                  onSubmitted: (_) => addToCart(),
                                  textInputAction: TextInputAction.done,
                                )
                              else
                                TextField(
                                  controller: amountController,
                                  focusNode: amountFocusNode,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    labelText: 'المبلغ',
                                    labelStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: const BorderSide(width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  autofocus: true,
                                  onChanged: (_) => setDialogState(() {}),
                                  onSubmitted: (_) => addToCart(),
                                  textInputAction: TextInputAction.done,
                                ),
                              const SizedBox(height: 12),
                              Text(
                                'وحدة البيع: ${selectedUnit.saleUnit}\n'
                                'نوع السعر: ${isWholesale ? 'جملة' : 'قطاعي'}\n'
                                'سعر الكيلو: ${unitPrice.toStringAsFixed(2)}\n'
                                '${selectedMethod == SellingMethod.amount ? 'المبلغ: ${formatQuantity(amount)}\n' : ''}'
                                'الكمية بالكيلو: ${formatQuantity(displayQuantity)}${isKilogramUnit ? ' كيلو' : ''}\n'
                                '${isKilogramUnit ? 'ما يعادلها بالجرام: ${displayGrams.round()} جرام\n' : ''}'
                                'الإجمالي: ${displayTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: addToCart,
                              child: const Text('إضافة'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openProductSearchDialog() async {
    final pickerController = TextEditingController(text: searchText);
    List<Product> pickerResults = List<Product>.from(searchResults);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DraggableDialog(
          title: 'اختر صنف',
          width: 500,
          height: 600,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: pickerController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'ابحث بالاسم، SKU، أو الباركود...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) async {
                                final results = await _repository.searchProducts(
                                  query: value,
                                  limit: _batchSize,
                                  offset: 0,
                                );

                                if (!mounted) return;

                                setDialogState(() {
                                  pickerResults = results;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: pickerResults.isEmpty
                                  ? Center(
                                      child: Text(
                                        'لا توجد نتائج',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: pickerResults.length,
                                      itemBuilder: (context, index) {
                                        final product = pickerResults[index];
                                        return ListTile(
                                          leading: product.imagePath.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.file(
                                                    File(product.imagePath),
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Icon(Icons.inventory_2),
                                                  ),
                                                )
                                              : const Icon(Icons.inventory_2),
                                          title: Text(product.name),
                                          subtitle: Text(
                                              'SKU: ${product.sku} | ${product.sellPrice.toStringAsFixed(2)} ${product.saleUnit}'),
                                          onTap: () async {
                                            Navigator.pop(dialogContext);
                                            await _openProductSelectionDialog(product);
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('إلغاء'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openQuickSellDialog() async {
    final pickerController = TextEditingController();
    List<Product> pickerResults = [];
    Product? selectedProduct;
    List<ProductSaleUnit> availableSaleUnits = [];
    ProductSaleUnit? selectedUnit;
    bool isWholesale = false;
    final quantityController = TextEditingController(text: '1');
    final amountController = TextEditingController(text: '');
    final quantityFocusNode = FocusNode();
    final amountFocusNode = FocusNode();
    SellingMethod selectedMethod = SellingMethod.quantity;

    quantityFocusNode.addListener(() {
      if (quantityFocusNode.hasFocus) {
        quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: quantityController.text.length,
        );
      }
    });

    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus) {
        amountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: amountController.text.length,
        );
      }
    });

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DraggableDialog(
          controller: _dialogController,
          title: 'بيع سريع',
          width: 500,
          height: 600,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final unitPrice = isWholesale && selectedUnit?.wholesalePrice != null
                  ? selectedUnit!.wholesalePrice!
                  : selectedUnit?.retailPrice ?? 0;
              final quantity = double.tryParse(quantityController.text) ?? 1;
              final amount = double.tryParse(amountController.text) ?? 0;
              final isKilogramUnit = selectedUnit?.saleUnit.trim().toLowerCase().contains('كيلو') == true ||
                  selectedUnit?.saleUnit.trim().toLowerCase().contains('kg') == true;
              final displayTotal = selectedMethod == SellingMethod.amount
                  ? amount
                  : quantity * unitPrice;
              final displayQuantity = selectedMethod == SellingMethod.amount
                  ? amount / unitPrice
                  : quantity;
              final displayGrams = isKilogramUnit
                  ? displayQuantity * 1000
                  : 0.0;

              void addToCart() async {
                final parsedQuantity = selectedMethod == SellingMethod.amount
                    ? SellingHelper.calculateQuantityFromAmount(
                        double.tryParse(amountController.text) ?? 0,
                        unitPrice,
                      )
                    : double.tryParse(quantityController.text) ?? 1;

                final parsedAmount = selectedMethod == SellingMethod.amount
                    ? double.tryParse(amountController.text) ?? 0
                    : 0.0;

                if (selectedMethod == SellingMethod.amount && parsedAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل مبلغًا صحيحًا')),
                  );
                  return;
                }

                if (selectedMethod == SellingMethod.quantity && parsedQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل كمية صحيحة')),
                  );
                  return;
                }

                final requestedStockReduction = _stockReductionInStorageUnit(
                  selectedProduct!,
                  selectedUnit!,
                  parsedQuantity,
                );
                if (requestedStockReduction > selectedProduct!.quantity) {
                  await _showInsufficientStockDialog(
                    selectedProduct!,
                    requestedStockReduction,
                    selectedProduct!.quantity,
                  );
                  return;
                }

                selectedProduct!.quantity -= requestedStockReduction;
                await _repository.updateProduct(selectedProduct!);

                final newCartItem = CartItem(
                  product: selectedProduct!,
                  selectedSaleUnit: selectedUnit!,
                  quantity: parsedQuantity,
                  isWholesale: isWholesale,
                  sellingMethod: selectedMethod,
                  amount: parsedAmount,
                );

                setState(() {
                  cartItems.add(newCartItem);
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم إضافة ${selectedProduct!.name} للفاتورة المعلقة'),
                    backgroundColor: AppStyles.successColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              return Focus(
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                    Navigator.pop(context);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      Expanded(
                        child: selectedProduct == null
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: pickerController,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: 'ابحث عن منتج...',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (value) async {
                                        if (value.isEmpty) {
                                          setDialogState(() {
                                            pickerResults.clear();
                                            selectedProduct = null;
                                          });
                                          return;
                                        }
                                        final results = await _repository.searchProducts(
                                          query: value,
                                          limit: 10,
                                          offset: 0,
                                        );
                                        if (!mounted) return;
                                        setDialogState(() {
                                          pickerResults = results;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: pickerResults.isEmpty
                                          ? Center(
                                              child: Text(
                                                pickerController.text.isEmpty
                                                    ? 'ابدأ بكتابة اسم المنتج للبحث'
                                                    : 'لا توجد نتائج',
                                                style: TextStyle(color: Colors.grey.shade600),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: EdgeInsets.zero,
                                              itemCount: pickerResults.length,
                                              itemBuilder: (context, index) {
                                                final product = pickerResults[index];
                                                return ListTile(
                                                  leading: product.imagePath.isNotEmpty
                                                      ? ClipRRect(
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: Image.file(
                                                            File(product.imagePath),
                                                            width: 40,
                                                            height: 40,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) =>
                                                                const Icon(Icons.inventory_2),
                                                          ),
                                                        )
                                                      : const Icon(Icons.inventory_2),
                                                  title: Text(product.name),
                                                  subtitle: Text(
                                                      '${product.sellPrice.toStringAsFixed(2)} ${product.saleUnit}'),
                                                  onTap: () async {
                                                    List<ProductSaleUnit> saleUnits =
                                                        await _repository.getSaleUnits(product.id ?? 0);
                                                    print('DEBUG: saleUnits.length before filter: ${saleUnits.length}');
                                                    print('DEBUG: saleUnits before filter: ${saleUnits.map((u) => u.saleUnit).toList()}');
                                                    
                                                    saleUnits = saleUnits
                                                        .where((unit) =>
                                                            _isCompatibleWithStorageUnit(product, unit))
                                                        .toList();
                                                    
                                                    print('DEBUG: saleUnits.length after filter: ${saleUnits.length}');
                                                    print('DEBUG: saleUnits after filter: ${saleUnits.map((u) => u.saleUnit).toList()}');
                                                    
                                                    if (saleUnits.isEmpty) {
                                                      saleUnits = [_buildFallbackSaleUnit(product)];
                                                    }
                                                    if (!mounted) return;
                                                    setDialogState(() {
                                                      selectedProduct = product;
                                                      availableSaleUnits = saleUnits;
                                                      selectedUnit = saleUnits.first;
                                                      isWholesale = false;
                                                      selectedMethod = selectedUnit!.allowSellingByAmount
                                                          ? SellingMethod.amount
                                                          : SellingMethod.quantity;
                                                      quantityController.text = '1';
                                                      amountController.clear();
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        if (selectedProduct!.imagePath.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.file(
                                              File(selectedProduct!.imagePath),
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.inventory_2),
                                            ),
                                          )
                                        else
                                          const Icon(Icons.inventory_2),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            selectedProduct!.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            setDialogState(() {
                                              selectedProduct = null;
                                              selectedUnit = null;
                                            });
                                          },
                                          icon: const Icon(Icons.arrow_back, size: 16),
                                          label: const Text('رجوع'),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    // عرض المخزون
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        const Icon(Icons.inventory_2, size: 20, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          'الكمية في المخزن: ${formatQuantity(selectedProduct!.quantity)} ${selectedProduct!.storageUnit}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // عرض الحالة
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Icon(
                                          selectedProduct!.quantity > selectedProduct!.minQuantity
                                              ? Icons.circle
                                              : selectedProduct!.quantity > 0
                                                  ? Icons.circle
                                                  : Icons.circle,
                                          size: 12,
                                          color: selectedProduct!.quantity > selectedProduct!.minQuantity
                                              ? Colors.green
                                              : selectedProduct!.quantity > 0
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedProduct!.quantity > selectedProduct!.minQuantity
                                              ? 'متوفر'
                                              : selectedProduct!.quantity > 0
                                                  ? 'منخفض'
                                                  : 'نفد',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: selectedProduct!.quantity > selectedProduct!.minQuantity
                                                ? Colors.green
                                                : selectedProduct!.quantity > 0
                                                    ? Colors.orange
                                                    : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // وحدة البيع
                                    DropdownButtonFormField<ProductSaleUnit>(
                                      value: selectedUnit,
                                      decoration: const InputDecoration(labelText: 'وحدة البيع'),
                                      items: availableSaleUnits.map((unit) {
                                        return DropdownMenuItem<ProductSaleUnit>(
                                          value: unit,
                                          child: Text(unit.saleUnit),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            selectedUnit = value;
                                            isWholesale = value.saleUnit.contains('عمود') ||
                                                          value.saleUnit.contains('عامود');
                                            if (!selectedUnit!.allowSellingByAmount) {
                                              selectedMethod = SellingMethod.quantity;
                                            }
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    // نوع السعر
                                    Wrap(
                                      textDirection: TextDirection.rtl,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        const Text('نوع السعر:  '),
                                        // Check if unit is "عمود" or "عامود"
                                        if (selectedUnit!.wholesalePrice != null && 
                                            !selectedUnit!.saleUnit.contains('عمود') && 
                                            !selectedUnit!.saleUnit.contains('عامود'))
                                          ChoiceChip(
                                            label: const Text('قطاعي'),
                                            selected: !isWholesale,
                                            onSelected: (_) {
                                              setDialogState(() {
                                                isWholesale = false;
                                                selectedMethod = selectedUnit!.allowSellingByAmount
                                                    ? SellingMethod.amount
                                                    : SellingMethod.quantity;
                                                quantityController.clear();
                                                amountController.clear();
                                              });
                                            },
                                          ),
                                        if (selectedUnit!.wholesalePrice != null)
                                          ChoiceChip(
                                            label: const Text('جملة'),
                                            selected: isWholesale,
                                            onSelected: (_) {
                                              setDialogState(() {
                                                isWholesale = true;
                                                selectedMethod = SellingMethod.quantity;
                                                amountController.clear();
                                              });
                                            },
                                          ),
                                        if (selectedUnit!.wholesalePrice == null)
                                          const Text('قطاعي'),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // طريقة البيع
                                    if (isWholesale)
                                      const Text('طريقة البيع: بالكمية')
                                    else if (selectedUnit!.allowSellingByAmount)
                                      const Text('طريقة البيع: بالمبلغ')
                                    else
                                      const Text('طريقة البيع: بالكمية'),
                                    const SizedBox(height: 12),
                                    // الحقل المناسب
                                    if (selectedMethod == SellingMethod.quantity)
                                      TextField(
                                        controller: quantityController,
                                        focusNode: quantityFocusNode,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          labelText: 'الكمية',
                                          labelStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          border: OutlineInputBorder(
                                            borderSide: const BorderSide(width: 2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        autofocus: true,
                                        onChanged: (_) => setDialogState(() {}),
                                        onSubmitted: (_) => addToCart(),
                                        textInputAction: TextInputAction.done,
                                      )
                                    else
                                      TextField(
                                        controller: amountController,
                                        focusNode: amountFocusNode,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          labelText: 'المبلغ',
                                          labelStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          border: OutlineInputBorder(
                                            borderSide: const BorderSide(width: 2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        autofocus: true,
                                        onChanged: (_) => setDialogState(() {}),
                                        onSubmitted: (_) => addToCart(),
                                        textInputAction: TextInputAction.done,
                                      ),
                                    const SizedBox(height: 12),
                                    // الملخص
                                    Text(
                                      'وحدة البيع: ${selectedUnit!.saleUnit}\n'
                                      'نوع السعر: ${isWholesale ? 'جملة' : 'قطاعي'}\n'
                                      'سعر الكيلو: ${unitPrice.toStringAsFixed(2)}\n'
                                      '${selectedMethod == SellingMethod.amount ? 'المبلغ: ${formatQuantity(amount)}\n' : ''}'
                                      'الكمية بالكيلو: ${formatQuantity(displayQuantity)}${isKilogramUnit ? ' كيلو' : ''}\n'
                                      '${isKilogramUnit ? 'ما يعادلها بالجرام: ${displayGrams.round()} جرام\n' : ''}'
                                      'الإجمالي: ${displayTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                            const SizedBox(width: 8),
                            if (selectedProduct != null && selectedUnit != null)
                              ElevatedButton(
                                onPressed: addToCart,
                                child: const Text('إضافة'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _addToCart(Product product) {
    _openProductSelectionDialog(product);
  }

  Future<void> _increaseQuantity(CartItem item) async {
    final newQuantity = item.quantity + 1;
    final newStockReduction = _stockReductionInStorageUnit(
      item.product,
      item.selectedSaleUnit,
      newQuantity,
    );

    if (newStockReduction > item.product.quantity) {
      await _showInsufficientStockDialog(
        item.product,
        newStockReduction,
        item.product.quantity,
      );
      return;
    }

    setState(() {
      if (item.sellingMethod == SellingMethod.amount) {
        item.amount += item.unitPrice;
        item.quantity = SellingHelper.calculateQuantityFromAmount(item.amount, item.unitPrice);
      } else {
        item.quantity = newQuantity;
      }
    });
  }

  void _decreaseQuantity(CartItem item) {
    setState(() {
      if (item.sellingMethod == SellingMethod.amount) {
        if (item.amount > item.unitPrice) {
          item.amount -= item.unitPrice;
          item.quantity = SellingHelper.calculateQuantityFromAmount(item.amount, item.unitPrice);
        } else {
          cartItems.remove(item);
        }
      } else {
        if (item.quantity > 1) {
          item.quantity -= 1;
        } else {
          cartItems.remove(item);
        }
      }
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      cartItems.remove(item);
    });
  }

  void _clearSearch() {
    setState(() {
      searchController.clear();
      searchText = '';
      searchResults.clear();
      _currentSearchQuery = null;
      _currentOffset = 0;
      _isImageSearchMode = false;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // Main content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // Header with search
                      _buildSearchSection(),
                      const SizedBox(height: 12),

                      // Content area
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : searchResults.isEmpty
                                ? _buildEmptyState()
                                : _buildSearchResults(),
                      ),
                    ],
                  ),
                ),
              ),

              // Fixed cart sidebar
              _buildCartSidebar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        const Text(
          '🛒 الكاشير',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppStyles.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم، SKU، أو الباركود...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchText = value;
              });
              _performSearch(value);
            },
            onSubmitted: (value) {
              if (searchResults.isNotEmpty) {
                _addToCart(searchResults.first);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () async {
            if (searchResults.isNotEmpty) {
              await _openProductSelectionDialog(searchResults.first);
              return;
            }

            if (searchText.trim().isNotEmpty) {
              await _performSearch(searchText.trim());
              if (searchResults.isNotEmpty) {
                await _openProductSelectionDialog(searchResults.first);
                return;
              }
            }

            await _openProductSearchDialog();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('+ إضافة صنف'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppStyles.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isSearchingByImage ? null : _searchByImage,
          icon: _isSearchingByImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.camera_alt, size: 18),
          label: const Text('بحث بالصورة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppStyles.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _isLoading ? null : _clearSearch,
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'ابدأ البحث عن منتج',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'نتائج البحث (${searchResults.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: searchResults.length + (_isLoadingMore ? 1 : 0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index == searchResults.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final product = searchResults[index];
                return CashierProductSearchCard(
                  product: product,
                  onTap: () => _handleProductCardTap(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSidebar() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        // Draggable handle
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _cartSidebarWidth += details.delta.dx;
                _cartSidebarWidth = _cartSidebarWidth.clamp(250.0, 500.0);
              });
            },
            child: Container(
              width: 8,
              height: double.infinity,
              color: Colors.grey.shade300,
              child: Center(
                child: Container(
                  width: 2,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Cart sidebar
        Container(
          width: _cartSidebarWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Cart header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppStyles.primaryColor,
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'السلة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cartItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cart items
              Expanded(
                child: cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'السلة فارغة',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          return _buildCartItem(item);
                        },
                      ),
              ),
              // Quick sell button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openQuickSellDialog,
                    icon: const Icon(Icons.flash_on, size: 18),
                    label: const Text('بيع سريع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // Cart footer
              if (cartItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المجموع:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _calculateTotal().toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppStyles.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleCheckoutButton,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('إتمام البيع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              cartItems.clear();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppStyles.errorColor,
                          ),
                          child: const Text('إفراغ السلة'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Product image
          item.product.imagePath.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(item.product.imagePath),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.inventory_2,
                      size: 20,
                      color: AppStyles.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Icon(
                  Icons.inventory_2,
                  size: 20,
                  color: AppStyles.primaryColor.withValues(alpha: 0.5),
                ),
          const SizedBox(width: 8),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${item.selectedSaleUnit.saleUnit} ${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Quantity controls
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 14),
                  onPressed: () => _decreaseQuantity(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  formatQuantity(item.quantity),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 14),
                  onPressed: () => _increaseQuantity(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Item total
          Flexible(
            child: Text(
              item.total.toStringAsFixed(2),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppStyles.primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          // Remove button
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => _removeFromCart(item),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckoutButton() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('السلة فارغة'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final total = _calculateTotal();
    await _confirmCheckout(total);
  }

  Future<void> _confirmCheckout(double total) async {
    final invoiceNumber = _generateInvoiceNumber();
    final now = DateTime.now().toIso8601String();
    final invoice = Invoice(
      invoiceNumber: invoiceNumber,
      date: now,
      total: total,
      paymentMethod: 'cash',
      customerId: null,
      notes: null,
    );

    final invoiceId = await _invoiceRepository.createInvoice(invoice);

    // إنشاء نسخة من cartItems للتكرار عليها
    final itemsToProcess = List<CartItem>.from(cartItems);

    for (final item in itemsToProcess) {
      final invoiceItem = InvoiceItem(
        invoiceId: invoiceId,
        productId: item.product.id ?? 0,
        productName: item.product.name,
        saleUnit: item.selectedSaleUnit.saleUnit,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        total: item.total,
        isWholesale: item.isWholesale,
      );

      await _invoiceRepository.createInvoiceItem(invoiceItem);
    }

    setState(() {
      cartItems.clear();
    });

    await _showSuccessDialog(invoiceNumber);
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '$datePart-$timePart';
  }

  Future<void> _showSuccessDialog(String invoiceNumber) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DraggableDialog(
          title: 'تمت العملية بنجاح',
          width: 400,
          height: 220,
          child: AlertDialog(
            title: const Text(
              'تمت العملية بنجاح',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('رقم الفاتورة: $invoiceNumber'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
    );
  }

  double _calculateTotal() {
    return cartItems.fold(0.0, (sum, item) => sum + item.total);
  }
}
