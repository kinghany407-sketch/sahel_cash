import 'package:flutter/material.dart';

import 'app_styles.dart';
import 'units_manager.dart';

class UnitsManagerDialog extends StatefulWidget {
  final UnitsManager unitsManager;

  const UnitsManagerDialog({super.key, required this.unitsManager});

  @override
  State<UnitsManagerDialog> createState() => _UnitsManagerDialogState();
}

class _UnitsManagerDialogState extends State<UnitsManagerDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _editingUnit;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveUnit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال اسم الوحدة'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.unitsManager.availableUnits.contains(value) &&
        _editingUnit != value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الوحدة موجودة بالفعل'),
          backgroundColor: AppStyles.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_editingUnit == null) {
      widget.unitsManager.addUnit(value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة الوحدة بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      widget.unitsManager.updateUnit(_editingUnit!, value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الوحدة بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _controller.clear();
    _editingUnit = null;
    setState(() {});
  }

  Future<void> _confirmDelete(String unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف الوحدة "$unit"؟'),
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
      widget.unitsManager.deleteUnit(unit);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.straighten, color: AppStyles.primaryColor),
            const SizedBox(width: AppStyles.spacingSm),
            const Text(
              'إدارة الوحدات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: AppStyles.dialogWidthSm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                textDirection: TextDirection.rtl,
                decoration: AppStyles.inputDecoration(
                  labelText: _editingUnit == null
                      ? 'اسم الوحدة الجديدة'
                      : 'تعديل الوحدة',
                  prefixIcon: Icons.edit,
                ),
                onSubmitted: (_) => _saveUnit(),
              ),
              const SizedBox(height: AppStyles.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveUnit,
                      icon: Icon(_editingUnit == null ? Icons.save : Icons.edit),
                      label: Text(_editingUnit == null ? 'حفظ' : 'تعديل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppStyles.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  if (_editingUnit != null) ...[
                    const SizedBox(width: AppStyles.spacingSm),
                    OutlinedButton(
                      onPressed: () {
                        _controller.clear();
                        _editingUnit = null;
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppStyles.spacingMd),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الوحدات المتاحة',
                  style: TextStyle(
                    fontSize: AppStyles.fontSizeLg,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: AppStyles.spacingSm),
              SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: AppStyles.spacingSm,
                    runSpacing: AppStyles.spacingSm,
                    children: widget.unitsManager.availableUnits.map((unit) {
                      final isEditing = _editingUnit == unit;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppStyles.spacingSm,
                          vertical: AppStyles.spacingXs,
                        ),
                        decoration: AppStyles.chipDecoration(isSelected: isEditing),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _controller.text = unit;
                                _editingUnit = unit;
                                setState(() {});
                              },
                              child: Text(
                                unit,
                                style: TextStyle(
                                  fontWeight: isEditing
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isEditing
                                      ? AppStyles.primaryColor
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppStyles.spacingXs),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: AppStyles.iconSizeMd,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                _controller.text = unit;
                                _editingUnit = unit;
                                setState(() {});
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              splashRadius: AppStyles.iconSizeLg,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: AppStyles.iconSizeMd,
                                color: AppStyles.errorColor,
                              ),
                              onPressed: () => _confirmDelete(unit),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              splashRadius: AppStyles.iconSizeLg,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
            child: const Text('إغلاق'),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppStyles.spacingLg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        ),
      ),
    );
  }
}
