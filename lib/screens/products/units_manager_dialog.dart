import 'package:flutter/material.dart';

import 'app_styles.dart';
import 'units_manager.dart';
import '../../widgets/draggable_dialog.dart';

class UnitsManagerDialog extends StatefulWidget {
  final UnitsManager unitsManager;

  const UnitsManagerDialog({super.key, required this.unitsManager});

  @override
  State<UnitsManagerDialog> createState() => _UnitsManagerDialogState();
}

class _UnitsManagerDialogState extends State<UnitsManagerDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _editingUnit;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      await widget.unitsManager.loadUnits();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('تعذر تحميل الوحدات: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveUnit() async {
    if (_isLoading || _isSaving) return;
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

    setState(() => _isSaving = true);
    try {
      final editing = _editingUnit != null;
      if (editing) {
        await widget.unitsManager.updateUnit(_editingUnit!, value);
      } else {
        await widget.unitsManager.addUnit(value);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing ? 'تم تحديث الوحدة بنجاح' : 'تم إضافة الوحدة بنجاح',
          ),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _controller.clear();
      _editingUnit = null;
      setState(() {});
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppStyles.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete(String unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
      try {
        await widget.unitsManager.deleteUnit(unit);
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'إدارة الوحدات',
        width: AppStyles.dialogWidthSm,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(AppStyles.spacingLg),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                textDirection: TextDirection.rtl,
                enabled: !_isLoading && !_isSaving,
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
                      onPressed: _isLoading || _isSaving ? null : _saveUnit,
                      icon: Icon(
                        _editingUnit == null ? Icons.save : Icons.edit,
                      ),
                      label: Text(_editingUnit == null ? 'حفظ' : 'تعديل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppStyles.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppStyles.radiusMd,
                          ),
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
                          borderRadius: BorderRadius.circular(
                            AppStyles.radiusMd,
                          ),
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
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: AppStyles.spacingSm,
                          runSpacing: AppStyles.spacingSm,
                          children: widget.unitsManager.availableUnits.map((
                            unit,
                          ) {
                            final isEditing = _editingUnit == unit;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppStyles.spacingSm,
                                vertical: AppStyles.spacingXs,
                              ),
                              decoration: AppStyles.chipDecoration(
                                isSelected: isEditing,
                              ),
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
      ),
    );
  }
}
