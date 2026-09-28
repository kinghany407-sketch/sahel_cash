import 'package:flutter/material.dart';

import 'app_styles.dart';
import 'categories_manager.dart';
import '../../widgets/draggable_dialog.dart';

class CategoriesManagerDialog extends StatefulWidget {
  final CategoriesManager categoriesManager;

  const CategoriesManagerDialog({super.key, required this.categoriesManager});

  @override
  State<CategoriesManagerDialog> createState() =>
      _CategoriesManagerDialogState();
}

class _CategoriesManagerDialogState extends State<CategoriesManagerDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _editingCategory;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveCategory() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال اسم الفئة'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.categoriesManager.categories.contains(value) &&
        _editingCategory != value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الفئة موجودة بالفعل'),
          backgroundColor: AppStyles.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_editingCategory == null) {
      widget.categoriesManager.addCategory(value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة الفئة بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      widget.categoriesManager.updateCategory(_editingCategory!, value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الفئة بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _controller.clear();
    _editingCategory = null;
    setState(() {});
  }

  Future<void> _confirmDelete(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف الفئة "$category"؟'),
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
      widget.categoriesManager.deleteCategory(category);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'إدارة الفئات',
        width: AppStyles.dialogWidthSm,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(AppStyles.spacingLg),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                textDirection: TextDirection.rtl,
                decoration: AppStyles.inputDecoration(
                  labelText: _editingCategory == null
                      ? 'اسم الفئة الجديدة'
                      : 'تعديل الفئة',
                  prefixIcon: Icons.edit,
                ),
                onSubmitted: (_) => _saveCategory(),
              ),
              const SizedBox(height: AppStyles.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveCategory,
                      icon: Icon(
                        _editingCategory == null ? Icons.save : Icons.edit,
                      ),
                      label: Text(_editingCategory == null ? 'حفظ' : 'تعديل'),
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
                  if (_editingCategory != null) ...[
                    const SizedBox(width: AppStyles.spacingSm),
                    OutlinedButton(
                      onPressed: () {
                        _controller.clear();
                        _editingCategory = null;
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
                  'الفئات المتاحة',
                  style: TextStyle(
                    fontSize: AppStyles.fontSizeLg,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: AppStyles.spacingSm),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: AppStyles.spacingSm,
                    runSpacing: AppStyles.spacingSm,
                    children: widget.categoriesManager.categories.map((category) {
                      final isEditing = _editingCategory == category;
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
                                _controller.text = category;
                                _editingCategory = category;
                                setState(() {});
                              },
                              child: Text(
                                category,
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
                                _controller.text = category;
                                _editingCategory = category;
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
                              onPressed: () => _confirmDelete(category),
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
      ),
    );
  }
}
