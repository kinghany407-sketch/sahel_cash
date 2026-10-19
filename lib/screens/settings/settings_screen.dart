import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../products/app_styles.dart';
import '../../database/database_helper.dart';
import '../users/users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Store Settings
  final TextEditingController _storeNameController = TextEditingController(text: 'سهل كاش');
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _storePhoneController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();

  // Invoice Settings
  String _paperSize = '80mm'; // 80mm or 58mm
  final TextEditingController _invoiceHeaderController = TextEditingController();
  final TextEditingController _invoiceFooterController = TextEditingController();
  bool _printLogo = true;

  // Language Settings
  String _selectedLanguage = 'ar'; // ar or en

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _taxIdController.dispose();
    _invoiceHeaderController.dispose();
    _invoiceFooterController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeNameController.text = prefs.getString('store_name') ?? 'سهل كاش';
      _storeAddressController.text = prefs.getString('store_address') ?? '';
      _storePhoneController.text = prefs.getString('store_phone') ?? '';
      _taxIdController.text = prefs.getString('tax_id') ?? '';
      _paperSize = prefs.getString('paper_size') ?? '80mm';
      _printLogo = prefs.getBool('print_logo') ?? true;
      _invoiceHeaderController.text = prefs.getString('invoice_header') ?? '';
      _invoiceFooterController.text = prefs.getString('invoice_footer') ?? '';
      _selectedLanguage = prefs.getString('language') ?? 'ar';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', _storeNameController.text);
    await prefs.setString('store_address', _storeAddressController.text);
    await prefs.setString('store_phone', _storePhoneController.text);
    await prefs.setString('tax_id', _taxIdController.text);
    await prefs.setString('paper_size', _paperSize);
    await prefs.setBool('print_logo', _printLogo);
    await prefs.setString('invoice_header', _invoiceHeaderController.text);
    await prefs.setString('invoice_footer', _invoiceFooterController.text);
    await prefs.setString('language', _selectedLanguage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الإعدادات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _createBackup() async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final defaultFileName = 'sahel_cash_backup_$timestamp.db';

      // Use file picker to save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null) {
        // Copy database file to selected location
        final db = DatabaseHelper.instance;
        final dbPath = await db.getDatabasePath();
        final dbFile = File(dbPath);

        if (await dbFile.exists()) {
          await dbFile.copy(result);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنشاء النسخة الاحتياطية بنجاح'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لم يتم العثور على ملف قاعدة البيانات'),
                backgroundColor: AppStyles.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء النسخة الاحتياطية: $e'),
            backgroundColor: AppStyles.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null && result.files.single.path != null) {
        final backupPath = result.files.single.path!;
        final backupFile = File(backupPath);

        if (await backupFile.exists()) {
          // Confirm restore
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تأكيد الاستعادة'),
              content: const Text('سيتم استبدال قاعدة البيانات الحالية بالنسخة الاحتياطية. هل أنت متأكد؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('استعادة'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            final db = DatabaseHelper.instance;
            final dbPath = await db.getDatabasePath();

            // Close database connection
            await db.close();

            // Replace database file
            await backupFile.copy(dbPath);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم استعادة النسخة الاحتياطية بنجاح. يرجى إعادة تشغيل التطبيق.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في استعادة النسخة الاحتياطية: $e'),
            backgroundColor: AppStyles.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.backgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(AppStyles.spacingLg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: AppStyles.spacingLg),
                _buildStoreSettingsCard(),
                const SizedBox(height: AppStyles.spacingMd),
                _buildInvoiceSettingsCard(),
                const SizedBox(height: AppStyles.spacingMd),
                _buildBackupRestoreCard(),
                const SizedBox(height: AppStyles.spacingMd),
                _buildUserManagementCard(),
                const SizedBox(height: AppStyles.spacingMd),
                _buildLanguageSettingsCard(),
                const SizedBox(height: AppStyles.spacingLg),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppStyles.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.settings, color: AppStyles.primaryColor, size: 28),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإعدادات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'تخصيص إعدادات المتجر والفواتير',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStoreSettingsCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.store, color: AppStyles.primaryColor, size: 20),
        title: const Text(
          'إعدادات المتجر',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _storeNameController,
                  label: 'اسم النشاط',
                  icon: Icons.business,
                  required: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _storeAddressController,
                  label: 'العنوان',
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _storePhoneController,
                  label: 'رقم الهاتف',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _taxIdController,
                  label: 'رقم التسجيل الضريبي',
                  icon: Icons.receipt_long,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSettingsCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.print, color: AppStyles.primaryColor, size: 20),
        title: const Text(
          'إعدادات الفواتير والطباعة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPaperSizeSelector(),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('طباعة اللوجو'),
                  subtitle: const Text('إظهار لوجو المتجر في الفاتورة'),
                  value: _printLogo,
                  onChanged: (value) {
                    setState(() {
                      _printLogo = value;
                    });
                  },
                  activeTrackColor: AppStyles.primaryColor.withValues(alpha: 0.5),
                  activeThumbColor: AppStyles.primaryColor,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _invoiceHeaderController,
                  label: 'رأس الفاتورة',
                  icon: Icons.text_fields,
                  maxLines: 3,
                  hintText: 'نص يظهر في أعلى الفاتورة',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _invoiceFooterController,
                  label: 'ذيل الفاتورة',
                  icon: Icons.text_fields,
                  maxLines: 3,
                  hintText: 'نص يظهر في أسفل الفاتورة',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حجم الورق',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _paperSize,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppStyles.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: const [
            DropdownMenuItem(value: '80mm', child: Text('80mm')),
            DropdownMenuItem(value: '58mm', child: Text('58mm')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _paperSize = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildBackupRestoreCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.backup, color: AppStyles.primaryColor, size: 20),
        title: const Text(
          'النسخ الاحتياطي واستعادة البيانات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _createBackup,
                        icon: const Icon(Icons.cloud_upload, size: 18),
                        label: const Text('نسخ احتياطي الآن'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _restoreBackup,
                        icon: const Icon(Icons.cloud_download, size: 18),
                        label: const Text('استعادة نسخة احتياطية'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppStyles.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ينصح بإنشاء نسخة احتياطية بشكل دوري لحماية بياناتك',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagementCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UsersScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppStyles.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people, color: AppStyles.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إدارة المستخدمين',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إضافة وتعديل المستخدمين والصلاحيات',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSettingsCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.language, color: AppStyles.primaryColor, size: 20),
        title: const Text(
          'إعدادات اللغة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختر اللغة',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppStyles.primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLanguage = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppStyles.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _saveSettings,
      icon: const Icon(Icons.save, size: 18),
      label: const Text('حفظ الإعدادات'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
