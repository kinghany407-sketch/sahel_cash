import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../database/database_helper.dart';
import '../../models/expense_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/purchase_invoice_model.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_invoice_repository.dart';
import '../products/app_styles.dart';

enum ReportPeriod {
  today,
  yesterday,
  last7Days,
  thisMonth,
  lastMonth,
  thisYear,
  allTime,
  custom,
}

enum ReportType {
  sales,
  inventory,
  expenses,
  profits,
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ProductRepository _productRepository = ProductRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final PurchaseInvoiceRepository _purchaseRepository =
      PurchaseInvoiceRepository();

  bool _isLoading = true;
  ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Raw fetched data
  List<Invoice> _allInvoices = [];
  Map<int, List<InvoiceItem>> _itemsByInvoiceId = {};
  Map<int, Product> _productsMap = {};
  List<Expense> _allExpenses = [];
  List<PurchaseInvoice> _allPurchases = [];

  // Filtered data
  List<Invoice> _filteredInvoices = [];
  List<Expense> _filteredExpenses = [];
  List<PurchaseInvoice> _filteredPurchases = [];

  // Report summaries
  double _totalSales = 0.0;
  double _totalCost = 0.0;
  double _totalExpenses = 0.0;
  double _totalPurchases = 0.0;
  int _totalInvoicesCount = 0;
  int _totalProductsSold = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _applyPeriod(ReportPeriod.thisMonth);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyPeriod(ReportPeriod period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (period) {
      case ReportPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);
        break;
      case ReportPeriod.last7Days:
        final sevenDaysAgo = now.subtract(const Duration(days: 6));
        start = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);
        break;
      case ReportPeriod.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case ReportPeriod.lastMonth:
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        start = DateTime(prevMonth.year, prevMonth.month, 1);
        final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
        end = DateTime(lastDayOfPrevMonth.year, lastDayOfPrevMonth.month, lastDayOfPrevMonth.day, 23, 59, 59, 999);
        break;
      case ReportPeriod.thisYear:
        start = DateTime(now.year, 1, 1);
        break;
      case ReportPeriod.allTime:
        start = DateTime(2020, 1, 1);
        break;
      case ReportPeriod.custom:
        start = _startDate;
        end = _endDate;
        break;
    }

    setState(() {
      _selectedPeriod = period;
      _startDate = start;
      _endDate = end;
    });

    _filterData();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  bool _isDateInRange(String dateStr) {
    final date = _parseDate(dateStr);
    if (date == null) return false;
    return (date.isAfter(_startDate) || date.isAtSameMomentAs(_startDate)) &&
        (date.isBefore(_endDate) || date.isAtSameMomentAs(_endDate));
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      // Fetch Invoices
      final invoices = await _invoiceRepository.getAllInvoices(limit: 100000);

      // Fetch all invoice items
      final itemsMaps = await db.query('invoice_items');
      final allItems = itemsMaps.map(InvoiceItem.fromMap).toList();
      final Map<int, List<InvoiceItem>> itemsByInv = {};
      for (final item in allItems) {
        itemsByInv.putIfAbsent(item.invoiceId, () => []).add(item);
      }

      // Fetch products
      final products = await _productRepository.getProducts();
      final Map<int, Product> prodMap = {};
      for (final p in products) {
        if (p.id != null) prodMap[p.id!] = p;
      }

      // Fetch expenses
      final expenses = await _expenseRepository.getAllExpenses();

      // Fetch purchases
      final purchases = await _purchaseRepository.getAllPurchaseInvoices();

      if (!mounted) return;
      setState(() {
        _allInvoices = invoices;
        _itemsByInvoiceId = itemsByInv;
        _productsMap = prodMap;
        _allExpenses = expenses;
        _allPurchases = purchases;
      });

      _filterData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات التقارير: $e'),
            backgroundColor: AppStyles.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    final filteredInvoices =
        _allInvoices.where((inv) => _isDateInRange(inv.date)).toList();
    final filteredExp =
        _allExpenses.where((exp) => _isDateInRange(exp.date)).toList();
    final filteredPurch =
        _allPurchases.where((p) => _isDateInRange(p.date)).toList();

    double salesSum = 0.0;
    int productsSoldCount = 0;

    for (final inv in filteredInvoices) {
      salesSum += inv.total;
      final items = _itemsByInvoiceId[inv.id] ?? [];
      for (final item in items) {
        productsSoldCount += item.quantity.toInt();
      }
    }

    double costSum = 0.0;
    for (final inv in filteredInvoices) {
      final items = _itemsByInvoiceId[inv.id] ?? [];
      for (final item in items) {
        final product = _productsMap[item.productId];
        final costPerStorage = product?.buyPrice ?? 0.0;
        costSum += item.quantity * costPerStorage;
      }
    }
    final expSum = filteredExp.fold(0.0, (sum, exp) => sum + exp.amount);
    final purchSum = filteredPurch.fold(0.0, (sum, p) => sum + p.totalAmount);

    setState(() {
      _filteredInvoices = filteredInvoices;
      _filteredExpenses = filteredExp;
      _filteredPurchases = filteredPurch;
      _totalSales = salesSum;
      _totalCost = costSum;
      _totalExpenses = expSum;
      _totalPurchases = purchSum;
      _totalInvoicesCount = filteredInvoices.length;
      _totalProductsSold = productsSoldCount;
    });
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppStyles.primaryColor,
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = ReportPeriod.custom;
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        );
      });
      _filterData();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.backgroundColor,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(AppStyles.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppStyles.spacingMd),
                    _buildPeriodFilterBar(),
                    const SizedBox(height: AppStyles.spacingMd),
                    _buildSummaryCards(),
                    const SizedBox(height: AppStyles.spacingMd),
                    _buildTabBar(),
                    const SizedBox(height: AppStyles.spacingMd),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSalesReportTab(),
                          _buildInventoryReportTab(),
                          _buildExpensesReportTab(),
                          _buildProfitsReportTab(),
                        ],
                      ),
                    ),
                  ],
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
          child: const Icon(Icons.bar_chart, color: AppStyles.primaryColor, size: 28),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'التقارير والتحليلات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'تقارير مبيعات، مخزون، مصروفات وأرباح',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _loadAllData,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('تحديث البيانات'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppStyles.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'الفترة:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          _buildPeriodChip('اليوم', ReportPeriod.today),
          _buildPeriodChip('أمس', ReportPeriod.yesterday),
          _buildPeriodChip('آخر 7 أيام', ReportPeriod.last7Days),
          _buildPeriodChip('هذا الشهر', ReportPeriod.thisMonth),
          _buildPeriodChip('الشهر الماضي', ReportPeriod.lastMonth),
          _buildPeriodChip('هذا العام', ReportPeriod.thisYear),
          _buildPeriodChip('الكل', ReportPeriod.allTime),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(
              _selectedPeriod == ReportPeriod.custom
                  ? '${_formatDate(_startDate)} - ${_formatDate(_endDate)}'
                  : 'تحديد فترة مخصصة',
              style: TextStyle(
                color: _selectedPeriod == ReportPeriod.custom
                    ? Colors.white
                    : AppStyles.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _selectedPeriod == ReportPeriod.custom
                ? AppStyles.primaryColor
                : AppStyles.primaryColor.withValues(alpha: 0.08),
            onPressed: _selectCustomDateRange,
          ),
          const SizedBox(width: 8),
          Text(
            '(${_formatDate(_startDate)} إلى ${_formatDate(_endDate)})',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, ReportPeriod period) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppStyles.primaryColor,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade800,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      onSelected: (selected) {
        if (selected) _applyPeriod(period);
      },
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (AppStyles.spacingSm * 4)) / 5;
        final isNarrow = constraints.maxWidth < 900;

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'إجمالي المبيعات',
                      value: '${_totalSales.toStringAsFixed(2)} ج.م',
                      subtitle: '$_totalInvoicesCount فاتورة',
                      color: Colors.indigo,
                      icon: Icons.point_of_sale,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'المنتجات المباعة',
                      value: '$_totalProductsSold',
                      subtitle: 'كمية مبيعة',
                      color: Colors.teal,
                      icon: Icons.inventory_2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'المصروفات',
                      value: '${_totalExpenses.toStringAsFixed(2)} ج.م',
                      subtitle: '${_filteredExpenses.length} سند',
                      color: Colors.deepOrange,
                      icon: Icons.payments,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'المشتريات',
                      value: '${_totalPurchases.toStringAsFixed(2)} ج.م',
                      subtitle: '${_filteredPurchases.length} فاتورة',
                      color: Colors.blueGrey,
                      icon: Icons.shopping_bag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'صافي الربح',
                      value: '${(_totalSales - _totalCost - _totalExpenses).toStringAsFixed(2)} ج.م',
                      subtitle: 'تقديري',
                      color: Colors.green,
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'إجمالي المبيعات',
                value: '${_totalSales.toStringAsFixed(2)} ج.م',
                subtitle: '$_totalInvoicesCount فاتورة',
                color: Colors.indigo,
                icon: Icons.point_of_sale,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'المنتجات المباعة',
                value: '$_totalProductsSold',
                subtitle: 'كمية مبيعة',
                color: Colors.teal,
                icon: Icons.inventory_2,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'المصروفات',
                value: '${_totalExpenses.toStringAsFixed(2)} ج.م',
                subtitle: '${_filteredExpenses.length} سند',
                color: Colors.deepOrange,
                icon: Icons.payments,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'المشتريات',
                value: '${_totalPurchases.toStringAsFixed(2)} ج.م',
                subtitle: '${_filteredPurchases.length} فاتورة',
                color: Colors.blueGrey,
                icon: Icons.shopping_bag,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                title: 'صافي الربح',
                value: '${(_totalSales - _totalCost - _totalExpenses).toStringAsFixed(2)} ج.م',
                subtitle: 'تقديري',
                color: Colors.green,
                icon: Icons.trending_up,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppStyles.primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: AppStyles.primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(icon: Icon(Icons.receipt_long), text: 'تقرير المبيعات'),
          Tab(icon: Icon(Icons.inventory_2), text: 'تقرير المخزون'),
          Tab(icon: Icon(Icons.payments), text: 'تقرير المصروفات'),
          Tab(icon: Icon(Icons.trending_up), text: 'تقرير الأرباح'),
        ],
      ),
    );
  }

  // ================= TAB 1: SALES REPORT =================
  Widget _buildSalesReportTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSalesChartCard(),
          const SizedBox(height: AppStyles.spacingMd),
          _buildSalesDetailsTable(),
        ],
      ),
    );
  }

  Widget _buildSalesChartCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.indigo, size: 20),
                SizedBox(width: 8),
                Text(
                  'توزيع المبيعات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _filteredInvoices.isEmpty
                    ? const Center(child: Text('لا توجد مبيعات في هذه الفترة'))
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _totalSales * 1.15,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${rod.toY.toStringAsFixed(2)} ج.م',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 45,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) return const Text('0');
                                  if (value >= 1000) {
                                    return Text('${(value / 1000).toStringAsFixed(0)}k');
                                  }
                                  return Text(value.toStringAsFixed(0));
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 45,
                                getTitlesWidget: (value, meta) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 8, bottom: 8),
                                    child: Text(
                                      'المبيعات',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _totalSales / 5,
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: _totalSales,
                                  color: Colors.indigo,
                                  width: 60,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesDetailsTable() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تفاصيل الفواتير',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'عدد الفواتير: ${_filteredInvoices.length}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _filteredInvoices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('لا توجد فواتير في هذه الفترة'),
                    ),
                  )
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('رقم الفاتورة')),
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('طريقة الدفع')),
                      DataColumn(label: Text('الإجمالي')),
                      DataColumn(label: Text('الربح')),
                    ],
                    rows: _filteredInvoices.map((invoice) {
                      double invoiceCost = 0.0;
                      final items = _itemsByInvoiceId[invoice.id] ?? [];
                      for (final item in items) {
                        final product = _productsMap[item.productId];
                        final costPerStorage = product?.buyPrice ?? 0.0;
                        invoiceCost += item.quantity * costPerStorage;
                      }
                      final profit = invoice.total - invoiceCost;
                      return DataRow(
                        cells: [
                          DataCell(Text('#${invoice.id}')),
                          DataCell(Text(invoice.date.split('T')[0])),
                          DataCell(Text(invoice.paymentMethod == 'cash' ? 'نقدي' : 'آجل')),
                          DataCell(Text('${invoice.total.toStringAsFixed(2)} ج.م')),
                          DataCell(
                            Text(
                              '${profit.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                color: profit >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 2: INVENTORY REPORT =================
  Widget _buildInventoryReportTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildInventorySummaryCard(),
          const SizedBox(height: AppStyles.spacingMd),
          _buildTopSellingProducts(),
        ],
      ),
    );
  }

  Widget _buildInventorySummaryCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.teal, size: 20),
                SizedBox(width: 8),
                Text(
                  'ملخص حركة المخزون',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInventoryStat(
                    'المنتجات المباعة',
                    '$_totalProductsSold',
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInventoryStat(
                    'إجمالي المبيعات',
                    '${_totalSales.toStringAsFixed(2)} ج.م',
                    Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingProducts() {
    // Calculate top selling products
    final Map<int, double> productSales = {};
    final Map<int, int> productQuantities = {};

    for (final invoice in _filteredInvoices) {
      final items = _itemsByInvoiceId[invoice.id] ?? [];
      for (final item in items) {
        productSales[item.productId] = (productSales[item.productId] ?? 0) + item.total;
        productQuantities[item.productId] = (productQuantities[item.productId] ?? 0) + item.quantity.toInt();
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أكثر المنتجات مبيعاً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            sortedProducts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('لا توجد مبيعات في هذه الفترة'),
                    ),
                  )
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('المنتج')),
                      DataColumn(label: Text('الكمية')),
                      DataColumn(label: Text('الإجمالي')),
                    ],
                    rows: sortedProducts.take(10).map((entry) {
                      final product = _productsMap[entry.key];
                      final quantity = productQuantities[entry.key] ?? 0;
                      return DataRow(
                        cells: [
                          DataCell(Text(product?.name ?? 'غير معروف')),
                          DataCell(Text('$quantity')),
                          DataCell(Text('${entry.value.toStringAsFixed(2)} ج.م')),
                        ],
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 3: EXPENSES REPORT =================
  Widget _buildExpensesReportTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildExpensesChartCard(),
          const SizedBox(height: AppStyles.spacingMd),
          _buildExpensesDetailsTable(),
        ],
      ),
    );
  }

  Widget _buildExpensesChartCard() {
    final totalExpenses = _totalExpenses;
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.deepOrange, size: 20),
                SizedBox(width: 8),
                Text(
                  'توزيع المصروفات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: totalExpenses == 0
                  ? const Center(child: Text('لا توجد مصروفات في هذه الفترة'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            value: 100,
                            title: '${totalExpenses.toStringAsFixed(2)} ج.م',
                            color: Colors.deepOrange,
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesDetailsTable() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تفاصيل المصروفات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'إجمالي: ${_totalExpenses.toStringAsFixed(2)} ج.م',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _filteredExpenses.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('لا توجد مصروفات في هذه الفترة'),
                    ),
                  )
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('الملاحظات')),
                      DataColumn(label: Text('الفئة')),
                      DataColumn(label: Text('المبلغ')),
                    ],
                    rows: _filteredExpenses.map((expense) {
                      return DataRow(
                        cells: [
                          DataCell(Text(expense.date.split('T')[0])),
                          DataCell(Text(expense.notes ?? '-')),
                          DataCell(Text(expense.category)),
                          DataCell(Text('${expense.amount.toStringAsFixed(2)} ج.م')),
                        ],
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 4: PROFITS REPORT =================
  Widget _buildProfitsReportTab() {
    final grossProfit = _totalSales - _totalCost;
    final netProfit = grossProfit - _totalExpenses;
    final profitMargin = _totalSales > 0 ? (netProfit / _totalSales) * 100 : 0.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfitsSummaryCard(grossProfit, netProfit, profitMargin),
          const SizedBox(height: AppStyles.spacingMd),
          _buildProfitsChartCard(),
        ],
      ),
    );
  }

  Widget _buildProfitsSummaryCard(double grossProfit, double netProfit, double profitMargin) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'ملخص الأرباح',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildProfitStat(
                    'مجمل الربح',
                    '${grossProfit.toStringAsFixed(2)} ج.م',
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProfitStat(
                    'صافي الربح',
                    '${netProfit.toStringAsFixed(2)} ج.م',
                    netProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProfitStat(
                    'هامش الربح',
                    '${profitMargin.toStringAsFixed(1)}%',
                    Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitsChartCard() {
    final grossProfit = _totalSales - _totalCost;
    final netProfit = grossProfit - _totalExpenses;

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'مقارنة الأرباح',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _totalSales == 0
                    ? const Center(child: Text('لا توجد بيانات في هذه الفترة'))
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: math.max(_totalSales, math.max(grossProfit.abs(), netProfit.abs())) * 1.15,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                String label = '';
                                switch (rodIndex) {
                                  case 0:
                                    label = 'المبيعات';
                                    break;
                                  case 1:
                                    label = 'مجمل الربح';
                                    break;
                                  case 2:
                                    label = 'صافي الربح';
                                    break;
                                }
                                return BarTooltipItem(
                                  '$label\n${rod.toY.toStringAsFixed(2)} ج.م',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 45,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) return const Text('0');
                                  if (value >= 1000) {
                                    return Text('${(value / 1000).toStringAsFixed(0)}k');
                                  }
                                  return Text(value.toStringAsFixed(0));
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 45,
                                getTitlesWidget: (value, meta) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 8, bottom: 8),
                                    child: Text(
                                      'المقارنة',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: math.max(
                                  1.0,
                                  math.max(_totalSales, math.max(grossProfit.abs(), netProfit.abs())) / 5,
                                ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: _totalSales,
                                  color: Colors.indigo,
                                  width: 30,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                BarChartRodData(
                                  toY: grossProfit,
                                  color: Colors.teal,
                                  width: 30,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                BarChartRodData(
                                  toY: netProfit,
                                  color: netProfit >= 0 ? Colors.green : Colors.red,
                                  width: 30,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ),
              ),
          ],
        ),
      ),
    );
  }
}
