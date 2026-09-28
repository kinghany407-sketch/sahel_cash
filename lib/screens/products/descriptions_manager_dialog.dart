import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_styles.dart';
import 'descriptions_manager.dart';
import '../../widgets/draggable_dialog.dart';

class DescriptionsManagerDialog extends StatefulWidget {
  final DescriptionsManager descriptionsManager;

  const DescriptionsManagerDialog({
    super.key,
    required this.descriptionsManager,
  });

  @override
  State<DescriptionsManagerDialog> createState() =>
      _DescriptionsManagerDialogState();
}

class _DescriptionsManagerDialogState extends State<DescriptionsManagerDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _editingDescription;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveDescription() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال وصف'),
          backgroundColor: AppStyles.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.descriptionsManager.descriptions.contains(value) &&
        _editingDescription != value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الوصف موجود بالفعل'),
          backgroundColor: AppStyles.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_editingDescription == null) {
      widget.descriptionsManager.addDescription(value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة الوصف بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      widget.descriptionsManager.updateDescription(_editingDescription!, value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الوصف بنجاح'),
          backgroundColor: AppStyles.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _controller.clear();
    _editingDescription = null;
    setState(() {});
  }

  Future<void> _confirmDelete(String description) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف الوصف؟'),
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
      widget.descriptionsManager.deleteDescription(description);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableDialog(
        title: 'إدارة الأوصاف',
        width: AppStyles.dialogWidthSm,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(AppStyles.spacingLg),
          child: Column(
            children: [
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      // Check if Shift is pressed for multi-line
                      if (!HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shift)) {
                        _saveDescription();
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.pop(context);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _controller,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: AppStyles.inputDecoration(
                    labelText: _editingDescription == null
                        ? 'وصف جديد'
                        : 'تعديل الوصف',
                    prefixIcon: Icons.edit,
                  ),
                  onSubmitted: (_) => _saveDescription(),
                ),
              ),
              const SizedBox(height: AppStyles.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveDescription,
                      icon: Icon(
                        _editingDescription == null ? Icons.save : Icons.edit,
                      ),
                      label: Text(_editingDescription == null ? 'حفظ' : 'تعديل'),
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
                  if (_editingDescription != null) ...[
                    const SizedBox(width: AppStyles.spacingSm),
                    OutlinedButton(
                      onPressed: () {
                        _controller.clear();
                        _editingDescription = null;
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
                  'الأوصاف المتاحة',
                  style: TextStyle(
                    fontSize: AppStyles.fontSizeLg,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: AppStyles.spacingSm),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.descriptionsManager.descriptions.length,
                  itemBuilder: (context, index) {
                    final description =
                        widget.descriptionsManager.descriptions[index];
                    final isEditing = _editingDescription == description;
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppStyles.spacingSm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppStyles.spacingSm,
                        vertical: AppStyles.spacingSm,
                      ),
                      decoration: AppStyles.chipDecoration(isSelected: isEditing),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _controller.text = description;
                                _editingDescription = description;
                                setState(() {});
                              },
                              child: Text(
                                description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
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
                          ),
                          if (isEditing) ...[
                            const SizedBox(width: AppStyles.spacingSm),
                            IconButton(
                              icon: const Icon(Icons.check, color: AppStyles.successColor),
                              onPressed: _saveDescription,
                              tooltip: 'حفظ',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppStyles.errorColor),
                              onPressed: () {
                                _controller.clear();
                                _editingDescription = null;
                                setState(() {});
                              },
                              tooltip: 'إلغاء',
                            ),
                          ] else ...[
                            const SizedBox(width: AppStyles.spacingSm),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () {
                                _controller.text = description;
                                _editingDescription = description;
                                setState(() {});
                              },
                              tooltip: 'تعديل',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppStyles.errorColor),
                              onPressed: () => _confirmDelete(description),
                              tooltip: 'حذف',
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
