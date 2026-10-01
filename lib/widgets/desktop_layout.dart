import 'package:flutter/material.dart';
import '../screens/cashier/cashier_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/invoices/invoices_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';

enum DesktopPage {
  home,
  cashier,
  products,
  inventory,
  customers,
  suppliers,
  profits,
  expenses,
  reports,
  invoices,
  settings,
}

class DesktopLayout extends StatefulWidget {
  final DesktopPage initialPage;

  const DesktopLayout({
    super.key,
    this.initialPage = DesktopPage.home,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  DesktopPage _currentPage = DesktopPage.home;
  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
  }

  void _navigateTo(DesktopPage page) {
    setState(() {
      _currentPage = page;
    });
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
          Expanded(
            child: _buildCurrentPage(),
          ),
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
            decoration: BoxDecoration(
              color: Colors.indigo,
            ),
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
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : const Icon(
                    Icons.store,
                    color: Colors.white,
                    size: 32,
                  ),
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
                _buildNavItem(
                  icon: Icons.local_shipping,
                  title: 'الموردون',
                  page: DesktopPage.suppliers,
                ),
                _buildNavItem(
                  icon: Icons.attach_money,
                  title: 'الأرباح',
                  page: DesktopPage.profits,
                ),
                _buildNavItem(
                  icon: Icons.payments,
                  title: 'المصروفات',
                  page: DesktopPage.expenses,
                ),
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
                _buildNavItem(
                  icon: Icons.settings,
                  title: 'الإعدادات',
                  page: DesktopPage.settings,
                ),
              ],
            ),
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
                    _isSidebarExpanded ? Icons.chevron_right : Icons.chevron_left,
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
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.indigo : Colors.grey.shade700,
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
      case DesktopPage.profits:
        return const _PlaceholderScreen(title: 'الأرباح');
      case DesktopPage.expenses:
        return const _PlaceholderScreen(title: 'المصروفات');
      case DesktopPage.reports:
        return const _PlaceholderScreen(title: 'التقارير');
      case DesktopPage.invoices:
        return const InvoicesScreen();
      case DesktopPage.settings:
        return const _PlaceholderScreen(title: 'الإعدادات');
    }
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'قيد التطوير',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
