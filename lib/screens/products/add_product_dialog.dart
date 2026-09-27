import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/product_model.dart';
import '../../models/product_sale_unit_model.dart';
import '../../repositories/product_repository.dart';
import '../../widgets/draggable_dialog.dart';
import 'access_control.dart';
import 'app_styles.dart';
import 'categories_manager.dart';
import 'categories_manager_dialog.dart';
import 'conversion_manager.dart';
import 'conversion_manager_dialog.dart';
import 'descriptions_manager.dart';
import 'descriptions_manager_dialog.dart';
import 'units_manager.dart';
import 'units_manager_dialog.dart';

class AddProductDialog extends StatefulWidget {
  final Product? product;
  final UserRole role;
  final bool readOnly;

  const AddProductDialog({
    super.key,
    this.product,
    this.role = UserRole.admin,
    this.readOnly = false,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final supplierController = TextEditingController();
  final barcodeController = TextEditingController();
  final skuController = TextEditingController();
  final buyPriceController = TextEditingController();
  final sellPriceController = TextEditingController();
  final quantityController = TextEditingController();
  final minQuantityController = TextEditingController();
  final conversionFactorController = TextEditingController();
  final unitsPerPurchaseUnitController = TextEditingController();
  final imageController = TextEditingController();

  late final UnitsManager _unitsManager;
  late final CategoriesManager _categoriesManager;
  late final ConversionManager _conversionManager;
  late final DescriptionsManager _descriptionsManager;
  final ProductRepository _productRepository = ProductRepository();
  final ImagePicker _imagePicker = ImagePicker();
  final DraggableDialogController _dialogController =
      DraggableDialogController();

  String? _selectedCategory;
  String? _selectedStorageUnit;
  String? _selectedPurchaseUnit;
  String? _selectedSaleUnit;
  String? _selectedDescription;
  bool _isSaving = false;
  File? _selectedImageFile;

  final List<ProductSaleUnit> _saleUnits = [];

  bool get _isEditing => widget.product != null;
  bool get _isViewOnly => widget.readOnly;

  @override
  void initState() {
    super.initState();
    _unitsManager = UnitsManager();
    _categoriesManager = CategoriesManager();
    _conversionManager = ConversionManager();
    _descriptionsManager = DescriptionsManager();

    final product = widget.product;
    if (product != null) {
      nameController.text = product.name;
      brandController.text = product.brand;
      _selectedCategory = product.category.isEmpty ? 'أخرى' : product.category;
      supplierController.text = product.supplier;
      barcodeController.text = product.barcode;
      skuController.text = product.sku;
      buyPriceController.text = product.buyPrice.toString();
      sellPriceController.text = product.sellPrice.toString();
      quantityController.text = product.quantity.toString();
      minQuantityController.text = product.minQuantity.toString();
      conversionFactorController.text = product.conversionFactor.toString();
      unitsPerPurchaseUnitController.text = product.unitsPerPurchaseUnit.toString();
      imageController.text = product.imagePath;
      _selectedDescription = product.description.isEmpty
          ? null
          : product.description;
      _unitsManager.addUnit(product.storageUnit);
      _unitsManager.addUnit(product.purchaseUnit);
      _unitsManager.addUnit(product.saleUnit);
      _selectedStorageUnit = product.storageUnit.isEmpty
          ? 'قطعة'
          : product.storageUnit;
      _selectedPurchaseUnit = product.purchaseUnit.isEmpty
          ? 'قطعة'
          : product.purchaseUnit;
      _selectedSaleUnit = product.saleUnit.isEmpty ? 'قطعة' : product.saleUnit;
      _updateUnitsPerPurchaseUnit();
      _loadConversionFactor();

      // Load existing sale units
      if (product.id != null) {
        _loadSaleUnits(product.id!);
      }

      // Load existing image if editing
      if (product.imagePath.isNotEmpty) {
        try {
          _selectedImageFile = File(product.imagePath);
        } catch (e) {
          // If file doesn't exist, clear the path
          imageController.clear();
        }
      }
      return;
    }

    _selectedCategory = 'أخرى';
    _selectedStorageUnit = 'قطعة';
    _selectedPurchaseUnit = 'قطعة';
    _selectedSaleUnit = 'قطعة';
    unitsPerPurchaseUnitController.text = '1';
    _loadConversionFactor();
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    supplierController.dispose();
    barcodeController.dispose();
    skuController.dispose();
    buyPriceController.dispose();
    sellPriceController.dispose();
    quantityController.dispose();
    minQuantityController.dispose();
    conversionFactorController.dispose();
    unitsPerPurchaseUnitController.dispose();
    imageController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  void _syncSelectedValues() {
    final fallbackCategory = _categoriesManager.categories.contains('أخرى')
        ? 'أخرى'
        : (_categoriesManager.categories.isNotEmpty
              ? _categoriesManager.categories.first
              : null);
    if (_selectedCategory == null ||
        !_categoriesManager.categories.contains(_selectedCategory!)) {
      _selectedCategory = fallbackCategory;
    }

    final fallbackUnit = _unitsManager.availableUnits.contains('قطعة')
        ? 'قطعة'
        : (_unitsManager.availableUnits.isNotEmpty
              ? _unitsManager.availableUnits.first
              : null);

    if (_selectedStorageUnit == null ||
        !_unitsManager.availableUnits.contains(_selectedStorageUnit!)) {
      _selectedStorageUnit = fallbackUnit;
    }
    if (_selectedPurchaseUnit == null ||
        !_unitsManager.availableUnits.contains(_selectedPurchaseUnit!)) {
      _selectedPurchaseUnit = fallbackUnit;
    }
    if (_selectedSaleUnit == null ||
        !_unitsManager.availableUnits.contains(_selectedSaleUnit!)) {
      _selectedSaleUnit = fallbackUnit;
    }

    _loadConversionFactor();
    _updateUnitsPerPurchaseUnit();
  }

  void _updateUnitsPerPurchaseUnit({bool clearWhenDifferent = false}) {
    final purchaseUnit = (_selectedPurchaseUnit ?? '').trim();
    final storageUnit = (_selectedStorageUnit ?? '').trim();

    if (purchaseUnit.isEmpty || storageUnit.isEmpty) {
      return;
    }

    if (purchaseUnit == storageUnit) {
      unitsPerPurchaseUnitController.text = '1';
    } else if (clearWhenDifferent) {
      unitsPerPurchaseUnitController.clear();
    }
  }

  void _loadConversionFactor() {
    final fromUnit = (_selectedPurchaseUnit ?? '').trim();
    final toUnit = (_selectedSaleUnit ?? '').trim();
    if (fromUnit.isEmpty || toUnit.isEmpty) {
      conversionFactorController.clear();
      return;
    }

    // conversionFactor remains the existing purchase-to-sale conversion.
    if (fromUnit == toUnit) {
      conversionFactorController.text = '1';
      return;
    }

    // Search for saved conversion template only when units are different
    final savedFactor = _conversionManager.findFactor(fromUnit, toUnit);
    if (savedFactor != null) {
      conversionFactorController.text = savedFactor.toString();
    } else {
      conversionFactorController.clear();
    }
  }

  Future<void> _loadSaleUnits(int productId) async {
    try {
      final units = await _productRepository.getSaleUnits(productId);
      setState(() {
        _saleUnits.clear();
        _saleUnits.addAll(units);
      });
    } catch (e) {
      // If loading fails, continue with empty list
      setState(() {
        _saleUnits.clear();
      });
    }
  }

  void _addSaleUnit() {
    // Show dialog to add a new sale unit
    _showSaleUnitDialog();
  }

  void _editSaleUnit(ProductSaleUnit saleUnit) {
    // Show dialog to edit the sale unit
    _showSaleUnitDialog(saleUnit: saleUnit);
  }

  void _deleteSaleUnit(ProductSaleUnit saleUnit) {
    setState(() {
      _saleUnits.remove(saleUnit);
    });
  }

  void _showSaleUnitDialog({ProductSaleUnit? saleUnit}) {
    final unitController = TextEditingController(text: saleUnit?.saleUnit ?? '');
    final retailPriceController = TextEditingController(
      text: saleUnit?.retailPrice.toString() ?? '',
    );
    final wholesalePriceController = TextEditingController(
      text: saleUnit?.wholesalePrice?.toString() ?? '',
    );
    final conversionController = TextEditingController(
      text: saleUnit?.conversionToStorage.toString() ?? '1',
    );
    bool allowSellingByAmount = saleUnit?.allowSellingByAmount ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(saleUnit == null ? 'إضافة وحدة بيع' : 'تعديل وحدة بيع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: unitController.text.isEmpty ? null : unitController.text,
                  decoration: const InputDecoration(
                    labelText: 'وحدة البيع',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: _unitsManager.availableUnits.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      unitController.text = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: retailPriceController,
                  decoration: const InputDecoration(
                    labelText: 'سعر القطاعي',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: wholesalePriceController,
                  decoration: const InputDecoration(
                    labelText: 'سعر الجملة (اختياري)',
                    prefixIcon: Icon(Icons.money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: conversionController,
                  decoration: const InputDecoration(
                    labelText: 'معامل التحويل إلى وحدة التخزين',
                    prefixIcon: Icon(Icons.swap_horiz),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('السماح بالبيع بالمبلغ'),
                  value: allowSellingByAmount,
                  onChanged: (value) {
                    setDialogState(() {
                      allowSellingByAmount = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final unit = unitController.text.trim();
                if (unit.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء اختيار وحدة البيع')),
                  );
                  return;
                }

                final retailPrice = double.tryParse(retailPriceController.text);
                if (retailPrice == null || retailPrice <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال سعر قطاعي صحيح')),
                  );
                  return;
                }

                final conversion = double.tryParse(conversionController.text);
                if (conversion == null || conversion <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال معامل تحويل صحيح')),
                  );
                  return;
                }

                // Check for duplicate unit
                if (_saleUnits.any((u) => u.saleUnit == unit && u.id != saleUnit?.id)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('هذه الوحدة موجودة بالفعل')),
                  );
                  return;
                }

                final newSaleUnit = ProductSaleUnit(
                  id: saleUnit?.id,
                  productId: widget.product?.id ?? 0,
                  saleUnit: unit,
                  retailPrice: retailPrice,
                  wholesalePrice: wholesalePriceController.text.trim().isEmpty
                      ? null
                      : double.tryParse(wholesalePriceController.text),
                  conversionToStorage: conversion,
                  allowSellingByAmount: allowSellingByAmount,
                );

                setState(() {
                  if (saleUnit == null) {
                    _saleUnits.add(newSaleUnit);
                  } else {
                    final index = _saleUnits.indexOf(saleUnit);
                    if (index != -1) {
                      _saleUnits[index] = newSaleUnit;
                    }
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          imageController.text = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصورة: $e'),
            backgroundColor: AppStyles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageFile = null;
      imageController.clear();
    });
  }

  String? _validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'أدخل رقمًا صحيحًا';
    }
    if (parsed < 0) {
      return '$fieldName يجب أن يكون رقمًا موجبًا';
    }
    return null;
  }

  String? _validateNonNegativeNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'أدخل رقمًا صحيحًا';
    }
    if (parsed < 0) {
      return '$fieldName لا يمكن أن يكون سالبًا';
    }
    return null;
  }

  String? _validateUnitsPerPurchaseUnit(String? value) {
    if (_selectedPurchaseUnit == _selectedStorageUnit) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'أدخل عدد وحدات التخزين في وحدة الشراء';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'أدخل عددًا صحيحًا موجبًا أكبر من صفر';
    }
    return null;
  }

  String? _validateRequiredUnit(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (!_formKey.currentState!.validate()) return;

      final product = Product(
        id: widget.product?.id,
        name: nameController.text.trim(),
        brand: brandController.text.trim(),
        category: _selectedCategory ?? 'أخرى',
        supplier: supplierController.text.trim(),
        barcode: barcodeController.text.trim(),
        sku: skuController.text.trim(),
        buyPrice: double.tryParse(buyPriceController.text) ?? 0,
        sellPrice: double.tryParse(sellPriceController.text) ?? 0,
        quantity: double.tryParse(quantityController.text) ?? 0,
        minQuantity: double.tryParse(minQuantityController.text) ?? 0,
        conversionFactor: double.tryParse(conversionFactorController.text) ?? 1,
        storageUnit: _selectedStorageUnit ?? 'قطعة',
        purchaseUnit: _selectedPurchaseUnit ?? 'قطعة',
        saleUnit: _selectedSaleUnit ?? 'قطعة',
        unitsPerPurchaseUnit: int.parse(unitsPerPurchaseUnitController.text.trim()),
        description: _selectedDescription ?? '',
        imagePath: imageController.text.trim(),
      );

      // Save product
      if (widget.product != null) {
        await _productRepository.updateProduct(product);
        // Delete all existing sale units and re-add them
        await _productRepository.deleteSaleUnitsByProductId(product.id!);
      } else {
        await _productRepository.addProduct(product);
      }

      // Save sale units
      for (final saleUnit in _saleUnits) {
        final saleUnitToSave = ProductSaleUnit(
          productId: product.id!,
          saleUnit: saleUnit.saleUnit,
          retailPrice: saleUnit.retailPrice,
          wholesalePrice: saleUnit.wholesalePrice,
          conversionToStorage: saleUnit.conversionToStorage,
          allowSellingByAmount: saleUnit.allowSellingByAmount,
        );
        await _productRepository.addSaleUnit(saleUnitToSave);
      }

      if (mounted) {
        Navigator.pop(context, product);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAccessAdvanced = ProductAccess.canAccessAdvancedSettings(widget.role);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 600
        ? screenWidth - AppStyles.spacingXxl * 2
        : AppStyles.dialogWidthMd;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        controller: _dialogController,
        child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: _dialogController.dragHandle(
                  child: Row(
                    children: [
                      Icon(
                        _isViewOnly
                            ? Icons.visibility
                            : (_isEditing
                                  ? Icons.edit
                                  : Icons.add_circle_outline),
                        color: AppStyles.primaryColor,
                      ),
                      const SizedBox(width: AppStyles.spacingSm),
                      Text(
                        _isViewOnly
                            ? 'عرض الصنف'
                            : (_isEditing ? 'تعديل الصنف' : 'إضافة صنف جديد'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  buildField(
                    controller: nameController,
                    label: 'اسم الصنف',
                    icon: Icons.inventory_2,
                  ),
                  buildField(
                    controller: brandController,
                    label: 'العلامة التجارية',
                    icon: Icons.business_center,
                    required: false,
                  ),
                  buildDropdown(
                    label: 'الفئة',
                    value: _selectedCategory,
                    items: _categoriesManager.categories,
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                    icon: Icons.category,
                    onManagePressed: () async {
                      await showDialog(
                        context: context,
                        builder: (dialogContext) => CategoriesManagerDialog(
                          categoriesManager: _categoriesManager,
                        ),
                      );
                      if (mounted) {
                        setState(() {
                          _syncSelectedValues();
                        });
                      }
                    },
                  ),
                  buildField(
                    controller: skuController,
                    label: 'SKU',
                    icon: Icons.numbers,
                    required: false,
                  ),
                  buildField(
                    controller: barcodeController,
                    label: 'الباركود',
                    icon: Icons.qr_code,
                    required: false,
                  ),
                  buildField(
                    controller: sellPriceController,
                    label: 'سعر البيع',
                    icon: Icons.attach_money,
                    keyboard: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => _validatePositiveNumber(value, 'سعر البيع'),
                  ),
                  buildField(
                    controller: quantityController,
                    label: 'الكمية الحالية',
                    icon: Icons.production_quantity_limits,
                    keyboard: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) => _validateNonNegativeNumber(value, 'الكمية'),
                  ),
                  buildDropdown(
                    label: 'وحدة البيع',
                    value: _selectedSaleUnit,
                    items: _unitsManager.availableUnits,
                    onChanged: (value) {
                      setState(() {
                        _selectedSaleUnit = value;
                        _loadConversionFactor();
                      });
                    },
                    icon: Icons.straighten,
                    onManagePressed: () async {
                      await showDialog(
                        context: context,
                        builder: (dialogContext) =>
                            UnitsManagerDialog(unitsManager: _unitsManager),
                      );
                      if (mounted) {
                        setState(() {
                          _syncSelectedValues();
                        });
                      }
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppStyles.spacingSm),
                    decoration: BoxDecoration(
                      color: AppStyles.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: AppStyles.iconSizeMd,
                          color: AppStyles.primaryColor,
                        ),
                        const SizedBox(width: AppStyles.spacingSm),
                        Expanded(
                          child: Text(
                            'المخزون يُحفظ باستخدام وحدة التخزين',
                            style: TextStyle(
                              fontSize: AppStyles.fontSizeMd,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppStyles.spacingMd),
                  ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.settings),
                        const SizedBox(width: AppStyles.spacingSm),
                        const Text('الإعدادات المتقدمة'),
                      ],
                    ),
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacingXs,
                    ),
                    childrenPadding: const EdgeInsets.only(
                      top: AppStyles.spacingMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                    children: canAccessAdvanced
                        ? [
                            buildField(
                              controller: buyPriceController,
                              label: 'سعر الشراء',
                              icon: Icons.money,
                              keyboard: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (value) => _validatePositiveNumber(value, 'سعر الشراء'),
                            ),
                            buildField(
                              controller: minQuantityController,
                              label: 'الحد الأدنى',
                              icon: Icons.warning_amber_rounded,
                              keyboard: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (value) => _validateNonNegativeNumber(value, 'الحد الأدنى'),
                            ),
                            buildDropdown(
                              label: 'وحدة التخزين',
                              value: _selectedStorageUnit,
                              items: _unitsManager.availableUnits,
                              validator: _validateRequiredUnit,
                              onChanged: (value) {
                                setState(() {
                                  _selectedStorageUnit = value;
                                  _updateUnitsPerPurchaseUnit(
                                    clearWhenDifferent: true,
                                  );
                                });
                              },
                              icon: Icons.inventory,
                              onManagePressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (dialogContext) =>
                                      UnitsManagerDialog(
                                        unitsManager: _unitsManager,
                                      ),
                                );
                                if (mounted) {
                                  setState(() {
                                    _syncSelectedValues();
                                  });
                                }
                              },
                            ),
                            buildDropdown(
                              label: 'وحدة الشراء',
                              value: _selectedPurchaseUnit,
                              items: _unitsManager.availableUnits,
                              validator: _validateRequiredUnit,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPurchaseUnit = value;
                                  _updateUnitsPerPurchaseUnit(
                                    clearWhenDifferent: true,
                                  );
                                  _loadConversionFactor();
                                });
                              },
                              icon: Icons.shopping_cart,
                              onManagePressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (dialogContext) =>
                                      UnitsManagerDialog(
                                        unitsManager: _unitsManager,
                                      ),
                                );
                                if (mounted) {
                                  setState(() {
                                    _syncSelectedValues();
                                  });
                                }
                              },
                            ),
                            buildField(
                              controller: unitsPerPurchaseUnitController,
                              label: 'عدد وحدات التخزين داخل وحدة الشراء',
                              icon: Icons.format_list_numbered,
                              keyboard: TextInputType.number,
                              helperText: 'مثال: 1 عمود = 100 قطعة',
                              readOnly: _selectedPurchaseUnit == _selectedStorageUnit,
                              validator: _validateUnitsPerPurchaseUnit,
                            ),
                            buildField(
                              controller: conversionFactorController,
                              label: 'معامل التحويل',
                              icon: Icons.swap_horiz,
                              keyboard: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (value) {
                                // The purchase-to-sale factor is optional when
                                // unitsPerPurchaseUnit defines the purchase size.
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                final parsed = double.tryParse(value);
                                if (parsed == null || parsed <= 0) {
                                  return 'أدخل رقمًا صحيحًا أكبر من صفر';
                                }
                                return null;
                              },
                              trailingAction: IconButton(
                                tooltip: 'إدارة قوالب التحويل',
                                icon: const Icon(Icons.settings),
                                splashRadius: AppStyles.iconSizeLg,
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      AppStyles.primaryColor.withValues(alpha: 0.1),
                                  foregroundColor: AppStyles.primaryColor,
                                ),
                                onPressed: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (dialogContext) =>
                                        ConversionManagerDialog(
                                          conversionManager: _conversionManager,
                                        ),
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _syncSelectedValues();
                                    });
                                  }
                                },
                              ),
                            ),
                            _buildImageField(),
                            buildDropdown(
                              label: 'الوصف',
                              value: _selectedDescription,
                              items: _descriptionsManager.descriptions,
                              onChanged: (value) =>
                                  setState(() => _selectedDescription = value),
                              icon: Icons.description,
                              onManagePressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (dialogContext) =>
                                      DescriptionsManagerDialog(
                                        descriptionsManager: _descriptionsManager,
                                      ),
                                );
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            ),
                            if (_selectedDescription != null &&
                                _selectedDescription!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(AppStyles.spacingSm),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(AppStyles.radiusSm),
                                ),
                                child: Text(
                                  _selectedDescription!,
                                  style: TextStyle(
                                    fontSize: AppStyles.fontSizeMd,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            if (ProductAccess.canAccessSuppliers(widget.role))
                              buildField(
                                controller: supplierController,
                                label: 'المورد',
                                icon: Icons.business,
                                required: false,
                              ),
                          ]
                        : [
                          Padding(
                            padding: const EdgeInsets.all(AppStyles.spacingLg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock,
                                  color: AppStyles.errorColor,
                                ),
                                const SizedBox(width: AppStyles.spacingSm),
                                Text(
                                  ProductAccess.restrictedMessage,
                                  style: const TextStyle(
                                    color: AppStyles.errorColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                  const SizedBox(height: AppStyles.spacingMd),
                  ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.sell),
                        const SizedBox(width: AppStyles.spacingSm),
                        const Text('وحدات البيع والأسعار'),
                      ],
                    ),
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacingXs,
                    ),
                    childrenPadding: const EdgeInsets.only(
                      top: AppStyles.spacingMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppStyles.spacingSm),
                        decoration: BoxDecoration(
                          color: AppStyles.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: AppStyles.iconSizeMd,
                              color: AppStyles.primaryColor,
                            ),
                            const SizedBox(width: AppStyles.spacingSm),
                            Expanded(
                              child: Text(
                                'يمكنك إضافة أكثر من وحدة بيع لنفس المنتج مع أسعار مختلفة',
                                style: TextStyle(
                                  fontSize: AppStyles.fontSizeMd,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppStyles.spacingMd),
                      if (_saleUnits.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppStyles.spacingLg),
                          child: Text(
                            'لا توجد وحدات بيع مضافة',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ..._saleUnits.map((saleUnit) {
                          return Card(
                            key: ObjectKey(saleUnit),
                            margin: const EdgeInsets.symmetric(
                              vertical: AppStyles.spacingXs,
                            ),
                            child: ListTile(
                              title: Text(saleUnit.saleUnit),
                              subtitle: Text(
                                'قطاعي: ${saleUnit.retailPrice.toStringAsFixed(2)}${saleUnit.wholesalePrice != null ? ' | جملة: ${saleUnit.wholesalePrice!.toStringAsFixed(2)}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _editSaleUnit(saleUnit),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () => _deleteSaleUnit(saleUnit),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: AppStyles.spacingSm),
                      ElevatedButton.icon(
                        onPressed: _addSaleUnit,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة وحدة بيع'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('رجوع'),
          ),
          if (!_isViewOnly)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProduct,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppStyles.spacingLg,
                  vertical: AppStyles.spacingSm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                ),
              ),
            ),
        ],
        actionsPadding: const EdgeInsets.all(AppStyles.spacingLg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        ),
        ),
      ),
    );
  }

  Widget _buildImageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppStyles.spacingMd),
        Text(
          'صورة المنتج',
          style: TextStyle(
            fontSize: AppStyles.fontSizeLg,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: AppStyles.spacingSm),
        if (_selectedImageFile != null)
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppStyles.radiusLg),
                  child: Image.file(
                    _selectedImageFile!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    // ignore: unnecessary_underscores
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.broken_image,
                        size: AppStyles.iconSizeXl,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: AppStyles.spacingSm,
                  right: AppStyles.spacingSm,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _clearImage,
                      tooltip: 'حذف الصورة',
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: AppStyles.iconSizeXl,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: AppStyles.spacingSm),
                  Text(
                    'لا توجد صورة',
                    style: TextStyle(
                      fontSize: AppStyles.fontSizeMd,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppStyles.spacingMd),
        TextButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('اختر صورة'),
          style: TextButton.styleFrom(
            foregroundColor: AppStyles.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool required = true,
    String? initialValue,
    Widget? trailingAction,
    FormFieldValidator<String>? validator,
    bool? readOnly,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyles.spacingMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  keyboardType: keyboard,
                  textDirection: TextDirection.rtl,
                  readOnly: readOnly ?? _isViewOnly,
                  validator: validator ??
                      (required
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'هذا الحقل مطلوب';
                              }
                              return null;
                            }
                          : null),
                  decoration: AppStyles.inputDecoration(
                    labelText: label,
                    prefixIcon: icon,
                    suffixIcon: trailingAction,
                  ),
                ),
                if (helperText != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppStyles.spacingXs,
                      right: AppStyles.spacingSm,
                    ),
                    child: Text(
                      helperText,
                      style: TextStyle(
                        fontSize: AppStyles.fontSizeSm,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData icon = Icons.list,
    VoidCallback? onManagePressed,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppStyles.spacingMd),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: items.contains(value) ? value : null,
              decoration: AppStyles.inputDecoration(
                labelText: label,
                prefixIcon: icon,
              ),
              validator: validator,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    textDirection: TextDirection.rtl,
                  ),
                );
              }).toList(),
              onChanged: _isViewOnly ? null : onChanged,
            ),
          ),
          if (onManagePressed != null && !_isViewOnly) ...[
            const SizedBox(width: AppStyles.spacingSm),
            IconButton(
              tooltip: 'إدارة $label',
              onPressed: onManagePressed,
              icon: const Icon(Icons.settings),
              splashRadius: AppStyles.iconSizeLg,
              style: IconButton.styleFrom(
                backgroundColor: AppStyles.primaryColor.withValues(alpha: 0.1),
                foregroundColor: AppStyles.primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
