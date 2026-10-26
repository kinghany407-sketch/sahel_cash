import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../screens/cashier/cashier_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/invoices/invoices_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/profits/profits_screen.dart';
import '../screens/purchases/purchase_invoices_list_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';

enum DesktopPage {
  home,
  cashier,
  products,
  inventory,
  customers,
  suppliers,
  purchaseInvoices,
  profits,
  expenses,
  reports,
  invoices,
  settings,
}

class DesktopLayout extends StatefulWidget {
  final DesktopPage initialPage;

  const DesktopLayout({super.key, this.initialPage = DesktopPage.home});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  DesktopPage _currentPage = DesktopPage.home;
  bool _isSidebarExpanded = true;
  UserRole _currentUserRole = UserRole.admin;
  String _currentUserName = 'مدير النظام';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('user_role');
    final nameStr = prefs.getString('user_fullName');

    if (mounted) {
      setState(() {
        _currentUserRole =
            roleStr == 'cashier' ? UserRole.cashier : UserRole.admin;
        _currentUserName = nameStr ??
            (_currentUserRole == UserRole.admin ? 'مدير النظام' : 'كاشير');

        if (_currentUserRole == UserRole.cashier && _isRestrictedPage(_currentPage)) {
          _currentPage = DesktopPage.cashier;
        }
      });
    }
  }

  bool _isRestrictedPage(DesktopPage page) {
    return page == DesktopPage.reports ||
        page == DesktopPage.profits ||
        page == DesktopPage.settings ||
        page == DesktopPage.suppliers ||
        page == DesktopPage.purchaseInvoices ||
        page == DesktopPage.expenses;
  }

  void _navigateTo(DesktopPage page) {
    if (_currentUserRole == UserRole.cashier && _isRestrictedPage(page)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، هذه الشاشة مخصصة لمدير النظام فقط'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من النظام والعودة لشاشة الدخول؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_role');
      await prefs.remove('user_fullName');

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      body: Row(
        children: [
          // Main content area
          Expanded(child: _buildCurrentPage()),
          // Right sidebar (RTL)
          _buildSidebar(),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final sidebarWidth = _isSidebarExpanded ? 230.0 : 70.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // App title
          Container(
            padding: EdgeInsets.all(_isSidebarExpanded ? 20 : 12),
            decoration: BoxDecoration(color: Colors.indigo),
            child: _isSidebarExpanded
                ? const Column(
                    children: [
                      Text(
                        'سهل كاش',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'نظام إدارة النقاط البيع',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  )
                : const Icon(Icons.store, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  title: 'الرئيسية',
                  page: DesktopPage.home,
                ),
                _buildNavItem(
                  icon: Icons.point_of_sale,
                  title: 'الكاشير',
                  page: DesktopPage.cashier,
                ),
                _buildNavItem(
                  icon: Icons.inventory_2,
                  title: 'الأصناف',
                  page: DesktopPage.products,
                ),
                _buildNavItem(
                  icon: Icons.warehouse,
                  title: 'المخزون',
                  page: DesktopPage.inventory,
                ),
                _buildNavItem(
                  icon: Icons.people,
                  title: 'العملاء',
                  page: DesktopPage.customers,
                ),
                if (_currentUserRole == UserRole.admin)
                  _buildNavItem(
                    icon: Icons.local_shipping,
                    title: 'الموردون',
                    page: DesktopPage.suppliers,
                  ),
                if (_currentUserRole == UserRole.admin)
                  _buildNavItem(
                    icon: Icons.shopping_bag,
                    title: 'فواتير الشراء',
                    page: DesktopPage.purchaseInvoices,
                  ),
                if (_currentUserRole == UserRole.admin)
                  _buildNavItem(
                    icon: Icons.attach_money,
                    title: 'الأرباح',
                    page: DesktopPage.profits,
                  ),
                if (_currentUserRole == UserRole.admin)
                  _buildNavItem(
                    icon: Icons.payments,
                    title: 'المصروفات',
                    page: DesktopPage.expenses,
                  ),
                if (_currentUserRole == UserRole.admin)
                  _buildNavItem(
                    icon: Icons.bar_chart,
                    title: 'التقارير',
                    page: DesktopPage.reports,
                  ),
                _buildNavItem(
                  icon: Icons.receipt_long,
                  title: 'الفواتير',
                  page: DesktopPage.invoices,
                ),
                if (_currentUserRole == UserRole.admin)
                  _buildNavItem(
                    icon: Icons.settings,
                    title: 'الإعدادات',
                    page: DesktopPage.settings,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // User Profile & Logout section
          Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _currentUserRole == UserRole.admin
                        ? Colors.indigo
                        : Colors.teal,
                    child: Icon(
                      _currentUserRole == UserRole.admin
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  if (_isSidebarExpanded) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentUserName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _currentUserRole == UserRole.admin
                                ? 'مدير النظام'
                                : 'كاشير',
                            style: TextStyle(
                              fontSize: 10,
                              color: _currentUserRole == UserRole.admin
                                  ? Colors.indigo
                                  : Colors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 20, color: Colors.red),
                      tooltip: 'تسجيل الخروج',
                      onPressed: _logout,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!_isSidebarExpanded)
            IconButton(
              icon: const Icon(Icons.logout, size: 20, color: Colors.red),
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
            ),
          // Collapse/Expand button
          Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleSidebar,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isSidebarExpanded
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required DesktopPage page,
  }) {
    final isSelected = _currentPage == page;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateTo(page),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 16 : 6,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.indigo.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: Colors.indigo.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Expanded(
                    child: Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.indigo : Colors.grey.shade600,
                    ),
                  ),
                  if (_isSidebarExpanded) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.indigo
                              : Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    if (_currentUserRole == UserRole.cashier && _isRestrictedPage(_currentPage)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'عذراً، لا تملك الصلاحية للوصول إلى هذه الشاشة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'هذه الشاشة مخصصة لمدير النظام فقط',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _navigateTo(DesktopPage.cashier),
              child: const Text('العودة إلى الكاشير'),
            ),
          ],
        ),
      );
    }

    switch (_currentPage) {
      case DesktopPage.home:
        return const HomeScreen();
      case DesktopPage.cashier:
        return const CashierScreen();
      case DesktopPage.products:
        return const ProductsScreen();
      case DesktopPage.inventory:
        return const InventoryScreen();
      case DesktopPage.customers:
        return const CustomersScreen();
      case DesktopPage.suppliers:
        return const SuppliersScreen();
      case DesktopPage.purchaseInvoices:
        return const PurchaseInvoicesListScreen();
      case DesktopPage.profits:
        return const ProfitsScreen();
      case DesktopPage.expenses:
        return const ExpensesScreen();
      case DesktopPage.reports:
        return const ReportsScreen();
      case DesktopPage.invoices:
        return const InvoicesScreen();
      case DesktopPage.settings:
        return const SettingsScreen();
    }
  }
}
