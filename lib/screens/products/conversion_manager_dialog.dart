import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_styles.dart';
import 'conversion_manager.dart';
import 'units_manager.dart';
import '../../widgets/draggable_dialog.dart';

class ConversionManagerDialog extends StatefulWidget {
  final ConversionManager conversionManager;

  const ConversionManagerDialog({super.key, required this.conversionManager});

  @override
  State<ConversionManagerDialog> createState() =>
      _ConversionManagerDialogState();
}

class _ConversionManagerDialogState extends State<ConversionManagerDialog> {
  String? _fromUnit;
  String? _toUnit;
  ConversionTemplate? _editingTemplate;
  final TextEditingController _factorController = TextEditingController();

  Future<void> _showUnitDialog({
    required String title,
    String? initialValue,
    required bool isEdit,
    required bool isPurchaseDropdown,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم الوحدة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                Navigator.pop(dialogContext);
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: Text(isEdit ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final unitsManager = UnitsManager();
    if (isEdit) {
      if (initialValue == null || initialValue.isEmpty) return;
      unitsManager.updateUnit(initialValue, result);
    } else {
      unitsManager.addUnit(result);
    }

    if (isPurchaseDropdown) {
      _fromUnit = result;
    } else {
      _toUnit = result;
    }
    setState(() {});
  }

  Future<void> _handleUnitAction({
    required bool isPurchaseDropdown,
    required String action,
  }) async {
    final unitsManager = UnitsManager();
    final currentValue = isPurchaseDropdown ? _fromUnit : _toUnit;

    if (action == 'add') {
      await _showUnitDialog(
        title: 'إضافة وحدة جديدة',
        isEdit: false,
        isPurchaseDropdown: isPurchaseDropdown,
      );
      return;
    }

    if (currentValue == null || currentValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار وحدة أولاً')),
      );
      return;
    }

    if (action == 'edit') {
      await _showUnitDialog(
        title: 'تعديل الوحدة',
        initialValue: currentValue,
        isEdit: true,
        isPurchaseDropdown: isPurchaseDropdown,
      );
      return;
    }

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل تريد حذف الوحدة "$currentValue"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        unitsManager.deleteUnit(currentValue);
        if (isPurchaseDropdown) {
          if (_fromUnit == currentValue) {
            _fromUnit = null;
          }
        } else if (_toUnit == currentValue) {
          _toUnit = null;
        }
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _factorController.dispose();
    super.dispose();
  }

  void _submitConversion() {
    final factorText = _factorController.text.trim();
    final factor = double.tryParse(factorText);

    if (_fromUnit == null || _toUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار وحدتي شراء وبيع'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (factor == null || factor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال معامل تحويل رقمي صحيح'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_editingTemplate == null) {
      widget.conversionManager.addTemplate(_fromUnit!, _toUnit!, factor);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة قالب التحويل بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      widget.conversionManager.deleteTemplate(
        _editingTemplate!.fromUnit,
        _editingTemplate!.toUnit,
      );
      widget.conversionManager.addTemplate(_fromUnit!, _toUnit!, factor);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث قالب التحويل بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _clearForm();
    setState(() {});
  }

  void _clearForm() {
    _factorController.clear();
    _fromUnit = null;
    _toUnit = null;
    _editingTemplate = null;
  }

  void _startEdit(ConversionTemplate template) {
    _editingTemplate = template;
    _fromUnit = template.fromUnit;
    _toUnit = template.toUnit;
    _factorController.text = template.factor.toString();
    setState(() {});
  }

  Future<void> _confirmDelete(ConversionTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل تريد حذف قالب التحويل ${template.fromUnit} → ${template.toUnit}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.conversionManager.deleteTemplate(
        template.fromUnit,
        template.toUnit,
      );
      if (_editingTemplate != null &&
          _editingTemplate!.fromUnit == template.fromUnit &&
          _editingTemplate!.toUnit == template.toUnit) {
        _clearForm();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableUnits = UnitsManager().availableUnits;
    final templates = widget.conversionManager.templates;

    Widget buildUnitDropdown({
      required String label,
      required String? selectedUnit,
      required bool isPurchaseDropdown,
    }) {
      final unitItems = <DropdownMenuItem<String>>[];
      for (final unit in availableUnits) {
        unitItems.add(
          DropdownMenuItem<String>(
            value: unit,
            child: Text(
              unit,
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }

      unitItems.add(
        const DropdownMenuItem<String>(
          value: '__divider__',
          enabled: false,
          child: Divider(height: 1),
        ),
      );
      unitItems.add(
        DropdownMenuItem<String>(
          value: '__add_unit__',
          child: Row(
            children: const [
              Icon(Icons.add_circle_outline, color: AppStyles.successColor),
              SizedBox(width: 8),
              Text('➕ إضافة وحدة جديدة'),
            ],
          ),
        ),
      );
      unitItems.add(
        DropdownMenuItem<String>(
          value: '__edit_unit__',
          child: Row(
            children: const [
              Icon(Icons.edit_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Text('✏️ تعديل الوحدة المحددة'),
            ],
          ),
        ),
      );
      unitItems.add(
        DropdownMenuItem<String>(
          value: '__delete_unit__',
          child: Row(
            children: const [
              Icon(Icons.delete_outline, color: AppStyles.errorColor),
              SizedBox(width: 8),
              Text('🗑️ حذف الوحدة المحددة'),
            ],
          ),
        ),
      );

      return DropdownButtonFormField<String>(
        initialValue: availableUnits.contains(selectedUnit) ? selectedUnit : null,
        decoration: AppStyles.inputDecoration(
          labelText: label,
          prefixIcon: isPurchaseDropdown
              ? Icons.shopping_cart_outlined
              : Icons.sell_outlined,
        ),
        items: unitItems,
        onChanged: (value) async {
          if (value == '__add_unit__') {
            await _handleUnitAction(
              isPurchaseDropdown: isPurchaseDropdown,
              action: 'add',
            );
            return;
          }
          if (value == '__edit_unit__') {
            await _handleUnitAction(
              isPurchaseDropdown: isPurchaseDropdown,
              action: 'edit',
            );
            return;
          }
          if (value == '__delete_unit__') {
            await _handleUnitAction(
              isPurchaseDropdown: isPurchaseDropdown,
              action: 'delete',
            );
            return;
          }
          if (isPurchaseDropdown) {
            setState(() {
              _fromUnit = value;
              // Auto-set factor to 1 if units are the same
              if (_fromUnit == _toUnit && _fromUnit != null) {
                _factorController.text = '1';
              }
            });
          } else {
            setState(() {
              _toUnit = value;
              // Auto-set factor to 1 if units are the same
              if (_fromUnit == _toUnit && _toUnit != null) {
                _factorController.text = '1';
              }
            });
          }
        },
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'إدارة التحويلات',
        width: AppStyles.dialogWidthLg,
        height: 700,
        child: Padding(
          padding: const EdgeInsets.all(AppStyles.spacingLg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: buildUnitDropdown(
                        label: 'وحدة الشراء',
                        selectedUnit: _fromUnit,
                        isPurchaseDropdown: true,
                      ),
                    ),
                    const SizedBox(width: AppStyles.spacingSm),
                    Expanded(
                      child: buildUnitDropdown(
                        label: 'وحدة البيع',
                        selectedUnit: _toUnit,
                        isPurchaseDropdown: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppStyles.spacingMd),
                TextFormField(
                  controller: _factorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.rtl,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: AppStyles.inputDecoration(
                    labelText: 'معامل التحويل',
                    prefixIcon: Icons.calculate_outlined,
                  ),
                  onFieldSubmitted: (_) => _submitConversion(),
                ),
                const SizedBox(height: AppStyles.spacingMd),
                Wrap(
                  spacing: AppStyles.spacingSm,
                  runSpacing: AppStyles.spacingSm,
                  alignment: WrapAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _submitConversion,
                      icon: Icon(
                        _editingTemplate == null ? Icons.add : Icons.save,
                      ),
                      label: Text(_editingTemplate == null ? 'إضافة' : 'حفظ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _clearForm();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('مسح النموذج'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppStyles.spacingLg),
                Text(
                  'قوالب التحويل المحفوظة',
                  style: TextStyle(
                    fontSize: AppStyles.fontSizeLg,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.primaryColor,
                  ),
                ),
                const SizedBox(height: AppStyles.spacingSm),
                if (templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppStyles.spacingXxl),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.swap_horiz_outlined,
                            size: AppStyles.iconSizeXl,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: AppStyles.spacingSm),
                          const Text(
                            'لا توجد قوالب تحويل محفوظة بعد',
                            style: TextStyle(
                              fontSize: AppStyles.fontSizeLg,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: AppStyles.elevationSm,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.radiusLg),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppStyles.primaryColor.withValues(alpha: 0.05),
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'وحدة الشراء',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'وحدة البيع',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'معامل التحويل',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'تعديل',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'حذف',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                          ),
                        ],
                        rows: templates.map((template) {
                          return DataRow(
                            cells: [
                              DataCell(Text(template.fromUnit)),
                              DataCell(Text(template.toUnit)),
                              DataCell(Text(template.factor.toString())),
                              DataCell(
                                IconButton(
                                  tooltip: 'تعديل',
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _startEdit(template),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'حذف',
                                  icon: const Icon(Icons.delete, color: AppStyles.errorColor),
                                  onPressed: () => _confirmDelete(template),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
