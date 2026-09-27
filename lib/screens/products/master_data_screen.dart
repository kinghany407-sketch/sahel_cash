import 'package:flutter/material.dart';

import 'app_styles.dart';
import 'categories_manager.dart';
import 'conversion_manager.dart';
import 'descriptions_manager.dart';
import 'units_manager.dart';
import 'categories_manager_dialog.dart';
import 'conversion_manager_dialog.dart';
import 'descriptions_manager_dialog.dart';
import 'units_manager_dialog.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  final CategoriesManager _categoriesManager = CategoriesManager();
  final UnitsManager _unitsManager = UnitsManager();
  final ConversionManager _conversionManager = ConversionManager();
  final DescriptionsManager _descriptionsManager = DescriptionsManager();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'البيانات الأساسية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppStyles.spacingLg),
            children: [
              _buildCard(
                title: '📂 إدارة الفئات',
                subtitle: 'إضافة أو تعديل أو حذف الفئات',
                onTap: () async {
                  await showDialog(
                    context: context,
                    builder: (dialogContext) => CategoriesManagerDialog(
                      categoriesManager: _categoriesManager,
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: AppStyles.spacingMd),
              _buildCard(
                title: '📏 إدارة الوحدات',
                subtitle: 'إضافة أو تعديل أو حذف الوحدات',
                onTap: () async {
                  await showDialog(
                    context: context,
                    builder: (dialogContext) =>
                        UnitsManagerDialog(unitsManager: _unitsManager),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: AppStyles.spacingMd),
              _buildCard(
                title: '🔄 إدارة التحويلات',
                subtitle: 'إدارة قوالب التحويل بين الوحدات',
                onTap: () async {
                  await showDialog(
                    context: context,
                    builder: (dialogContext) => ConversionManagerDialog(
                      conversionManager: _conversionManager,
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: AppStyles.spacingMd),
              _buildCard(
                title: '📝 إدارة الأوصاف',
                subtitle: 'إدارة أوصاف المنتجات القابلة لإعادة الاستخدام',
                onTap: () async {
                  await showDialog(
                    context: context,
                    builder: (dialogContext) => DescriptionsManagerDialog(
                      descriptionsManager: _descriptionsManager,
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: AppStyles.elevationMd,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppStyles.fontSizeLg,
          ),
          textAlign: TextAlign.right,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: AppStyles.fontSizeMd,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.right,
        ),
        leading: const Icon(
          Icons.arrow_back_ios,
          size: AppStyles.iconSizeMd,
          color: AppStyles.primaryColor,
        ),
        onTap: onTap,
      ),
    );
  }
}
