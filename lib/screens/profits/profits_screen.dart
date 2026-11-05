import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../database/database_helper.dart';
import '../../models/expense_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/product_sale_unit_model.dart';
import '../../models/purchase_invoice_model.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/purchase_invoice_repository.dart';
import '../../utils/product_cost_calculator.dart';
import '../../utils/sales_cost_summary.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/draggable_dialog.dart';
import '../products/app_styles.dart';

enum ProfitPeriod {
  today,
  yesterday,
  last7Days,
  thisMonth,
  lastMonth,
  thisYear,
  allTime,
  custom,
}

class InvoiceItemProfitData {
  final InvoiceItem item;
  final double? quantityInStorage;
  final double? costPerStorageUnit;
  final double? totalCost;
  final double revenue;
  final double? profit;
  final double? profitMargin;

  InvoiceItemProfitData({
    required this.item,
    required this.quantityInStorage,
    required this.costPerStorageUnit,
    required this.totalCost,
    required this.revenue,
    required this.profit,
    required this.profitMargin,
  });
}

class InvoiceProfitData {
  final Invoice invoice;
  final double revenue;
  final double? cost;
  final double? profit;
  final double? profitMargin;
  final List<InvoiceItemProfitData> items;

  InvoiceProfitData({
    required this.invoice,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.profitMargin,
    required this.items,
  });
}

class ProductProfitData {
  final int productId;
  final String productName;
  final String storageUnit;
  double? totalQuantityInStorage;
  double totalRevenue;
  double? totalCost;
  double? totalProfit;
  int ordersCount;

  ProductProfitData({
    required this.productId,
    required this.productName,
    required this.storageUnit,
    this.totalQuantityInStorage = 0,
    this.totalRevenue = 0,
    this.totalCost = 0,
    this.totalProfit = 0,
    this.ordersCount = 0,
  });

  double? get profitMargin => totalProfit == null
      ? null
      : totalRevenue > 0
      ? (totalProfit! / totalRevenue) * 100
      : 0.0;

  void addCostAndProfit(double? cost, double revenue) {
    if (cost == null || totalCost == null || totalProfit == null) {
      totalCost = null;
      totalProfit = null;
      return;
    }

    totalCost = totalCost! + cost;
    totalProfit = totalProfit! + revenue - cost;
  }
}

class ProfitsScreen extends StatefulWidget {
  const ProfitsScreen({super.key});

  @override
  State<ProfitsScreen> createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends State<ProfitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ProductRepository _productRepository = ProductRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final PurchaseInvoiceRepository _purchaseRepository =
      PurchaseInvoiceRepository();

  bool _isLoading = true;
  ProfitPeriod _selectedPeriod = ProfitPeriod.thisMonth;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Raw fetched data
  List<Invoice> _allInvoices = [];
  Map<int, List<InvoiceItem>> _itemsByInvoiceId = {};
  Map<int, Product> _productsMap = {};
  Map<String, ProductSaleUnit> _saleUnitsMap = {};
  List<Expense> _allExpenses = [];
  List<PurchaseInvoice> _allPurchases = [];

  // Filtered & calculated data
  List<InvoiceProfitData> _filteredInvoiceProfits = [];
  List<ProductProfitData> _productProfitsList = [];
  List<Expense> _filteredExpenses = [];
  List<PurchaseInvoice> _filteredPurchases = [];

  // Financial summary
  double _totalRevenue = 0.0;
  double? _totalCost = 0.0;
  int _unknownCostCount = 0;
  double? _grossProfit = 0.0;
  double? _grossMargin = 0.0;
  double _totalExpenses = 0.0;
  double? _netProfit = 0.0;
  double? _netMargin = 0.0;
  double _totalPurchasesAmount = 0.0;
  double _netCashFlow = 0.0;

  // Search queries for tables
  String _invoiceSearchQuery = '';
  String _productSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _applyPeriod(ProfitPeriod.thisMonth);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyPeriod(ProfitPeriod period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (period) {
      case ProfitPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case ProfitPeriod.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
          999,
        );
        break;
      case ProfitPeriod.last7Days:
        final sevenDaysAgo = now.subtract(const Duration(days: 6));
        start = DateTime(
          sevenDaysAgo.year,
          sevenDaysAgo.month,
          sevenDaysAgo.day,
        );
        break;
      case ProfitPeriod.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case ProfitPeriod.lastMonth:
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        start = DateTime(prevMonth.year, prevMonth.month, 1);
        final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
        end = DateTime(
          lastDayOfPrevMonth.year,
          lastDayOfPrevMonth.month,
          lastDayOfPrevMonth.day,
          23,
          59,
          59,
          999,
        );
        break;
      case ProfitPeriod.thisYear:
        start = DateTime(now.year, 1, 1);
        break;
      case ProfitPeriod.allTime:
        start = DateTime(2020, 1, 1);
        break;
      case ProfitPeriod.custom:
        start = _startDate;
        end = _endDate;
        break;
    }

    setState(() {
      _selectedPeriod = period;
      _startDate = start;
      _endDate = end;
    });

    _recalculateProfits();
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

      // 1. Fetch Invoices
      final invoices = await _invoiceRepository.getAllInvoices(
        limit: 100000,
        includeVoided: false,
      );

      // 2. Fetch all invoice items
      final itemsMaps = await db.query('invoice_items');
      final allItems = itemsMaps.map(InvoiceItem.fromMap).toList();
      final Map<int, List<InvoiceItem>> itemsByInv = {};
      for (final item in allItems) {
        itemsByInv.putIfAbsent(item.invoiceId, () => []).add(item);
      }

      // 3. Fetch products
      final products = await _productRepository.getProducts();
      final Map<int, Product> prodMap = {};
      for (final p in products) {
        if (p.id != null) prodMap[p.id!] = p;
      }

      // 4. Fetch product sale units for accurate conversion
      final unitsMaps = await db.query('product_sale_units');
      final allUnits = unitsMaps.map(ProductSaleUnit.fromMap).toList();
      final Map<String, ProductSaleUnit> unitMap = {};
      for (final u in allUnits) {
        final key = '${u.productId}_${u.saleUnit.trim().toLowerCase()}';
        unitMap[key] = u;
      }

      // 5. Fetch expenses
      final expenses = await _expenseRepository.getAllExpenses();

      // 6. Fetch purchases
      final purchases = await _purchaseRepository.getAllPurchaseInvoices(
        includeVoided: false,
      );

      if (!mounted) return;
      setState(() {
        _allInvoices = invoices;
        _itemsByInvoiceId = itemsByInv;
        _productsMap = prodMap;
        _saleUnitsMap = unitMap;
        _allExpenses = expenses;
        _allPurchases = purchases;
      });

      _recalculateProfits();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات الأرباح: $e'),
            backgroundColor: AppStyles.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isSubUnit(String candidateSub, String candidateSuper) {
    final sub = candidateSub.trim().toLowerCase();
    final sup = candidateSuper.trim().toLowerCase();
    if (sub == sup || sub.isEmpty || sup.isEmpty) return false;

    const smallUnits = [
      'قطعة',
      'قطعه',
      'حبه',
      'حبة',
      'طبق',
      'كوب',
      'قرص',
      'علبة',
      'علبه',
      'جرام',
      'جم',
      'piece',
      'unit',
      'item',
      'plate',
      'cup',
      'gram',
      'g',
    ];
    const largeUnits = [
      'كرتونة',
      'كرتونه',
      'كرتون',
      'لفة',
      'لفه',
      'عامود',
      'عمود',
      'باكت',
      'بكت',
      'صندوق',
      'شيكارة',
      'شكارة',
      'شوال',
      'دسته',
      'دستة',
      'طرد',
      'كيلو',
      'كجم',
      'box',
      'carton',
      'pack',
      'package',
      'bundle',
      'roll',
      'bag',
      'sack',
      'kg',
      'kilo',
    ];

    final isSmall = smallUnits.any((u) => sub.contains(u));
    final isLarge = largeUnits.any((u) => sup.contains(u));
    return isSmall && isLarge;
  }

  double? _getCostPerStorageUnit(Product? product) =>
      ProductCostCalculator.costPerStorageUnit(product, _saleUnitsMap);

  double? _calculateStorageQuantity(
    Product? product,
    String saleUnit,
    double quantity,{double? savedConversionToStorage}
  ) {
    if (product == null) return quantity;
    final sUnit = saleUnit.trim().toLowerCase();
    final pStorage = product.storageUnit.trim().toLowerCase();

    if (sUnit == pStorage) return quantity;

    // Use saved conversionToStorage from invoice if available
    if (savedConversionToStorage != null && savedConversionToStorage > 0) {
      return quantity * savedConversionToStorage;
    }

    // If no saved conversionToStorage, return null to indicate incomplete data
    // Do NOT use fallback from current product settings
    return null;
  }

  void _recalculateProfits() {
    final filteredInvoices = _allInvoices
        .where((inv) => _isDateInRange(inv.date))
        .toList();

    double revenueSum = 0.0;
    final costSummary = SalesCostSummary();

    final List<InvoiceProfitData> invoiceProfits = [];
    final Map<int, ProductProfitData> productProfitMap = {};

    for (final inv in filteredInvoices) {
      final items = _itemsByInvoiceId[inv.id] ?? [];
      double invRevenue = inv.total;
      final invoiceCostSummary = SalesCostSummary();
      if (items.isEmpty) {
        costSummary.addCost(null);
        invoiceCostSummary.addCost(null);
      }
      final List<InvoiceItemProfitData> itemProfits = [];

      for (final item in items) {
        final product = _productsMap[item.productId];
        final costPerStorage = _getCostPerStorageUnit(product);
        final storageQty = _calculateStorageQuantity(
          product,
          item.saleUnit,
          item.quantity,
          savedConversionToStorage: item.conversionToStorage,
        );
        var itemCost = ProductCostCalculator.itemCost(
          product,
          item.saleUnit,
          item.quantity,
          _saleUnitsMap,
          savedConversionToStorage: item.conversionToStorage,
        );
        final itemRevenue = item.total;

        final itemProfit = itemCost == null ? null : itemRevenue - itemCost;
        final itemMargin = itemProfit == null
            ? null
            : itemRevenue > 0
            ? (itemProfit / itemRevenue) * 100
            : 0.0;

        costSummary.addCost(itemCost);
        invoiceCostSummary.addCost(itemCost);
        itemProfits.add(
          InvoiceItemProfitData(
            item: item,
            quantityInStorage: storageQty,
            costPerStorageUnit: costPerStorage,
            totalCost: itemCost,
            revenue: itemRevenue,
            profit: itemProfit,
            profitMargin: itemMargin,
          ),
        );

        // Aggregate product stats
        final pData = productProfitMap.putIfAbsent(
          item.productId,
          () => ProductProfitData(
            productId: item.productId,
            productName: item.productName,
            storageUnit: product?.storageUnit ?? 'وحدة غير معروفة',
          ),
        );
        if (storageQty == null) {
          pData.totalQuantityInStorage = null;
        } else if (pData.totalQuantityInStorage != null) {
          pData.totalQuantityInStorage = pData.totalQuantityInStorage! + storageQty;
        }
        pData.totalRevenue += itemRevenue;
        pData.addCostAndProfit(itemCost, itemRevenue);
        pData.ordersCount += 1;
      }

      revenueSum += invRevenue;

      final invoiceCost = invoiceCostSummary.totalCost;
      final invProfit = invoiceCostSummary.profitFor(invRevenue);
      final invMargin = invProfit == null
          ? null
          : invRevenue > 0
          ? (invProfit / invRevenue) * 100
          : 0.0;

      invoiceProfits.add(
        InvoiceProfitData(
          invoice: inv,
          revenue: invRevenue,
          cost: invoiceCost,
          profit: invProfit,
          profitMargin: invMargin,
          items: itemProfits,
        ),
      );
    }

    // Filter expenses
    final filteredExp = _allExpenses
        .where((exp) => _isDateInRange(exp.date))
        .toList();
    final expSum = filteredExp.fold(0.0, (sum, exp) => sum + exp.amount);

    // Filter purchases
    final filteredPurch = _allPurchases
        .where((p) => _isDateInRange(p.date))
        .toList();
    final purchSum = filteredPurch.fold(0.0, (sum, p) => sum + p.totalAmount);

    final grossProfit = costSummary.profitFor(revenueSum);
    final grossMargin = grossProfit == null
        ? null
        : revenueSum > 0
        ? (grossProfit / revenueSum) * 100
        : 0.0;
    final netProfit = grossProfit == null ? null : grossProfit - expSum;
    final netMargin = netProfit == null
        ? null
        : revenueSum > 0
        ? (netProfit / revenueSum) * 100
        : 0.0;
    final netCashFlow = revenueSum - purchSum - expSum;

    final sortedProductProfits = productProfitMap.values.toList()
      ..sort((a, b) {
        if (a.totalProfit == null) return b.totalProfit == null ? 0 : 1;
        if (b.totalProfit == null) return -1;
        return b.totalProfit!.compareTo(a.totalProfit!);
      });

    setState(() {
      _filteredInvoiceProfits = invoiceProfits;
      _productProfitsList = sortedProductProfits;
      _filteredExpenses = filteredExp;
      _filteredPurchases = filteredPurch;

      _totalRevenue = revenueSum;
      _totalCost = costSummary.totalCost;
      _unknownCostCount = costSummary.unknownCostCount;
      _grossProfit = grossProfit;
      _grossMargin = grossMargin;
      _totalExpenses = expSum;
      _netProfit = netProfit;
      _netMargin = netMargin;
      _totalPurchasesAmount = purchSum;
      _netCashFlow = netCashFlow;
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
        _selectedPeriod = ProfitPeriod.custom;
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
      _recalculateProfits();
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  String _formatCost(double? value) {
    return value == null ? 'غير مكتملة' : '${value.toStringAsFixed(2)} ج.م';
  }

  String _formatProfit(double? value) {
    return value == null ? 'غير مكتمل' : '${value.toStringAsFixed(2)} ج.م';
  }

  String _formatMargin(double? value) {
    return value == null ? 'غير مكتمل' : '${value.toStringAsFixed(1)}%';
  }

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
                    _buildKpiCards(),
                    const SizedBox(height: AppStyles.spacingMd),
                    _buildTabBar(),
                    const SizedBox(height: AppStyles.spacingMd),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildInvoicesProfitTab(),
                          _buildProductsProfitTab(),
                          _buildExpensesAndCashFlowTab(),
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
          child: const Icon(
            Icons.attach_money,
            color: AppStyles.primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الأرباح وتحليل الأداء المالي',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'متابعة الإيرادات، تكاليف البضاعة، المصروفات التشغيلية، وصافي الأرباح',
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
          _buildPeriodChip('اليوم', ProfitPeriod.today),
          _buildPeriodChip('أمس', ProfitPeriod.yesterday),
          _buildPeriodChip('آخر 7 أيام', ProfitPeriod.last7Days),
          _buildPeriodChip('هذا الشهر', ProfitPeriod.thisMonth),
          _buildPeriodChip('الشهر الماضي', ProfitPeriod.lastMonth),
          _buildPeriodChip('هذا العام', ProfitPeriod.thisYear),
          _buildPeriodChip('الكل', ProfitPeriod.allTime),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(
              _selectedPeriod == ProfitPeriod.custom
                  ? '${_formatDate(_startDate)} - ${_formatDate(_endDate)}'
                  : 'تحديد فترة مخصصة',
              style: TextStyle(
                color: _selectedPeriod == ProfitPeriod.custom
                    ? Colors.white
                    : AppStyles.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _selectedPeriod == ProfitPeriod.custom
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

  Widget _buildPeriodChip(String label, ProfitPeriod period) {
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

  Widget _buildKpiCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (AppStyles.spacingSm * 4)) / 5;
        final isNarrow = constraints.maxWidth < 900;

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'إجمالي المبيعات',
                      value: '${_totalRevenue.toStringAsFixed(2)} ج.م',
                      subtitle: '${_filteredInvoiceProfits.length} فاتورة',
                      color: Colors.indigo,
                      icon: Icons.point_of_sale,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'تكلفة المبيعات (COGS)',
                      value: _formatCost(_totalCost),
                      subtitle: _totalCost == null
                          ? 'غير مكتملة ($_unknownCostCount بند)'
                          : 'تكلفة شراء البضاعة',
                      color: Colors.blueGrey,
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'مجمل الربح',
                      value: _formatProfit(_grossProfit),
                      subtitle: 'هامش: ${_formatMargin(_grossMargin)}',
                      color: _grossProfit == null
                          ? Colors.blueGrey
                          : Colors.teal,
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'المصروفات التشغيلية',
                      value: '${_totalExpenses.toStringAsFixed(2)} ج.م',
                      subtitle: '${_filteredExpenses.length} سند صرف',
                      color: Colors.deepOrange,
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'صافي الربح الفعلي',
                      value: _formatProfit(_netProfit),
                      subtitle: 'هامش: ${_formatMargin(_netMargin)}',
                      color: _netProfit == null
                          ? Colors.blueGrey
                          : _netProfit! >= 0
                          ? Colors.green
                          : Colors.red,
                      icon: _netProfit == null
                          ? Icons.info_outline
                          : _netProfit! >= 0
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      isHighlighted: true,
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
              child: _buildKpiCard(
                title: 'إجمالي المبيعات',
                value: '${_totalRevenue.toStringAsFixed(2)} ج.م',
                subtitle: '${_filteredInvoiceProfits.length} فاتورة مبيعات',
                color: Colors.indigo,
                icon: Icons.point_of_sale,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'تكلفة المبيعات (COGS)',
                value: _formatCost(_totalCost),
                subtitle: _totalCost == null
                    ? 'غير مكتملة ($_unknownCostCount بند)'
                    : 'تكلفة شراء البضاعة المباعة',
                color: Colors.blueGrey,
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'مجمل الربح التجاري',
                value: _formatProfit(_grossProfit),
                subtitle: 'هامش مجمل الربح: ${_formatMargin(_grossMargin)}',
                color: _grossProfit == null ? Colors.blueGrey : Colors.teal,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'المصروفات التشغيلية',
                value: '${_totalExpenses.toStringAsFixed(2)} ج.م',
                subtitle: '${_filteredExpenses.length} سند صرف',
                color: Colors.deepOrange,
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: AppStyles.spacingSm),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'صافي الربح الفعلي',
                value: _formatProfit(_netProfit),
                subtitle: 'هامش الصافي: ${_formatMargin(_netMargin)}',
                color: _netProfit == null
                    ? Colors.blueGrey
                    : _netProfit! >= 0
                    ? Colors.green
                    : Colors.red,
                icon: _netProfit == null
                    ? Icons.info_outline
                    : _netProfit! >= 0
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                isHighlighted: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? color : Colors.grey.shade200,
          width: isHighlighted ? 1.5 : 1.0,
        ),
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          Tab(icon: Icon(Icons.bar_chart), text: 'نظرة عامة والرسوم'),
          Tab(icon: Icon(Icons.receipt_long), text: 'ربحية الفواتير'),
          Tab(icon: Icon(Icons.inventory_2), text: 'ربحية الأصناف'),
          Tab(
            icon: Icon(Icons.account_balance_wallet),
            text: 'المصروفات والتدفق النقدي',
          ),
        ],
      ),
    );
  }

  // ================= TAB 1: OVERVIEW & CHARTS =================
  Widget _buildOverviewTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 950;
        return SingleChildScrollView(
          child: Column(
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildBarChartCard()),
                    const SizedBox(width: AppStyles.spacingMd),
                    Expanded(flex: 2, child: _buildPieChartCard()),
                  ],
                )
              else ...[
                _buildBarChartCard(),
                const SizedBox(height: AppStyles.spacingMd),
                _buildPieChartCard(),
              ],
              const SizedBox(height: AppStyles.spacingMd),
              _buildFinancialSummaryDetails(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarChartCard() {
    final totalCost = _totalCost;
    final netProfit = _netProfit;
    if (totalCost == null || netProfit == null) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'تعذر رسم التكلفة والأرباح لأن تكلفة المبيعات غير مكتملة '
            '($_unknownCostCount بند).',
          ),
        ),
      );
    }

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
                  'مقارنة الإيرادات والتكاليف والأرباح',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLegendItem('المبيعات', Colors.indigo),
                const SizedBox(width: 12),
                _buildLegendItem('التكلفة', Colors.blueGrey),
                const SizedBox(width: 12),
                _buildLegendItem('المصروفات', Colors.deepOrange),
                const SizedBox(width: 12),
                _buildLegendItem('صافي الربح', Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: _totalRevenue == 0 && _totalExpenses == 0
                  ? const Center(child: Text('لا توجد بيانات للفترة المحددة'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            math.max(
                              _totalRevenue,
                              math.max(
                                totalCost,
                                math.max(_totalExpenses, netProfit),
                              ),
                            ) *
                            1.15,
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
                                  label = 'التكلفة';
                                  break;
                                case 2:
                                  label = 'المصروفات';
                                  break;
                                case 3:
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
                                  return Text(
                                    '${(value / 1000).toStringAsFixed(0)}k',
                                  );
                                }
                                return Text(value.toStringAsFixed(0));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'إجمالي الفترة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                            math.max(
                                  _totalRevenue,
                                  math.max(totalCost, _totalExpenses),
                                ) /
                                5,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: _totalRevenue,
                                color: Colors.indigo,
                                width: 22,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: totalCost,
                                color: Colors.blueGrey,
                                width: 22,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: _totalExpenses,
                                color: Colors.deepOrange,
                                width: 22,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: math.max(0.0, netProfit),
                                color: Colors.green,
                                width: 22,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
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

  Widget _buildPieChartCard() {
    final totalCost = _totalCost;
    final netProfit = _netProfit;
    if (totalCost == null || netProfit == null) {
      return Card(
        color: Colors.white,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('تعذر عرض نسب الأرباح لأن تكلفة المبيعات غير مكتملة.'),
        ),
      );
    }

    final hasData = _totalRevenue > 0;
    final costRatio = hasData ? (totalCost / _totalRevenue) * 100 : 0.0;
    final expRatio = hasData ? (_totalExpenses / _totalRevenue) * 100 : 0.0;
    final profitRatio = hasData
        ? math.max(0.0, (netProfit / _totalRevenue) * 100)
        : 0.0;

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
                Icon(Icons.pie_chart_outline, color: Colors.indigo, size: 20),
                SizedBox(width: 8),
                Text(
                  'توزيع إيرادات المبيعات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: !hasData
                  ? const Center(child: Text('لا توجد مبيعات في هذه الفترة'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            value: costRatio,
                            title: '${costRatio.toStringAsFixed(1)}%',
                            color: Colors.blueGrey,
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          PieChartSectionData(
                            value: expRatio,
                            title: '${expRatio.toStringAsFixed(1)}%',
                            color: Colors.deepOrange,
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          PieChartSectionData(
                            value: profitRatio,
                            title: '${profitRatio.toStringAsFixed(1)}%',
                            color: Colors.green,
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('تكلفة البضاعة', Colors.blueGrey),
                _buildLegendItem('المصروفات', Colors.deepOrange),
                _buildLegendItem('صافي الربح', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryDetails() {
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
              'بيان الدخل التفصيلي للفترة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              'إجمالي إيرادات المبيعات (+)',
              '${_totalRevenue.toStringAsFixed(2)} ج.م',
              Colors.indigo,
              isBold: true,
            ),
            const Divider(),
            _buildSummaryRow(
              'تكلفة البضاعة المباعة (COGS) (-)',
              _formatCost(_totalCost),
              Colors.blueGrey,
            ),
            const Divider(),
            _buildSummaryRow(
              'مجمل الربح التجاري (=)',
              '${_formatProfit(_grossProfit)}'
                  '${_grossMargin == null ? '' : ' (هامش ${_formatMargin(_grossMargin)})'}',
              _grossProfit == null ? Colors.blueGrey : Colors.teal,
              isBold: true,
            ),
            const Divider(),
            _buildSummaryRow(
              'إجمالي المصروفات التشغيلية (-)',
              '${_totalExpenses.toStringAsFixed(2)} ج.م',
              Colors.deepOrange,
            ),
            const Divider(thickness: 1.5),
            _buildSummaryRow(
              'صافي الربح الفعلي (=)',
              '${_formatProfit(_netProfit)}'
                  '${_netMargin == null ? '' : ' (هامش ${_formatMargin(_netMargin)})'}',
              _netProfit == null
                  ? Colors.blueGrey
                  : _netProfit! >= 0
                  ? Colors.green
                  : Colors.red,
              isBold: true,
              fontSize: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 2: INVOICES PROFITABILITY =================
  Widget _buildInvoicesProfitTab() {
    final filtered = _filteredInvoiceProfits.where((p) {
      if (_invoiceSearchQuery.isEmpty) return true;
      final q = _invoiceSearchQuery.toLowerCase();
      return p.invoice.invoiceNumber.toLowerCase().contains(q) ||
          p.invoice.paymentMethod.toLowerCase().contains(q);
    }).toList();

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث برقم الفاتورة أو طريقة الدفع...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _invoiceSearchQuery = val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'عدد الفواتير: ${filtered.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('لا توجد فواتير مطابقة'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                columnSpacing: 16,
                                horizontalMargin: 12,
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade100,
                                ),
                                columns: const [
                                  DataColumn(label: Text('رقم الفاتورة')),
                                  DataColumn(label: Text('التاريخ والوقت')),
                                  DataColumn(label: Text('طريقة الدفع')),
                                  DataColumn(label: Text('قيمة الفاتورة')),
                                  DataColumn(label: Text('التكلفة')),
                                  DataColumn(label: Text('الربح')),
                                  DataColumn(label: Text('نسبة الربح')),
                                  DataColumn(label: Text('معاينة')),
                                ],
                                rows: filtered.map((invData) {
                                  final profit = invData.profit;
                                  final isProfitable =
                                      profit != null && profit >= 0;
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          invData.invoice.invoiceNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          invData.invoice.date.length > 16
                                              ? invData.invoice.date.substring(
                                                  0,
                                                  16,
                                                )
                                              : invData.invoice.date,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          invData.invoice.paymentMethod ==
                                                  'cash'
                                              ? 'نقدي'
                                              : invData.invoice.paymentMethod,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${invData.revenue.toStringAsFixed(2)} ج.م',
                                        ),
                                      ),
                                      DataCell(Text(_formatCost(invData.cost))),
                                      DataCell(
                                        Text(
                                          _formatProfit(profit),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: profit == null
                                                ? Colors.blueGrey
                                                : isProfitable
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: profit == null
                                                ? Colors.blueGrey.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : isProfitable
                                                ? Colors.green.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.red.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _formatMargin(invData.profitMargin),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: profit == null
                                                  ? Colors.blueGrey
                                                  : isProfitable
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(
                                            Icons.info_outline,
                                            color: Colors.indigo,
                                          ),
                                          tooltip: 'تفاصيل الأصناف والربحية',
                                          onPressed: () =>
                                              _showInvoiceProfitDetails(
                                                invData,
                                              ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceProfitDetails(InvoiceProfitData data) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DraggableDialog(
          title: 'ربحية الفاتورة ${data.invoice.invoiceNumber}',
          width: 650,
          height: 520,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('الإيراد: ${data.revenue.toStringAsFixed(2)} ج.م'),
                        Text('التكلفة: ${_formatCost(data.cost)}'),
                        Text(
                          'الربح: ${_formatProfit(data.profit)}'
                          '${data.profitMargin == null ? '' : ' (${_formatMargin(data.profitMargin)})'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: data.profit == null
                                ? Colors.blueGrey
                                : data.profit! >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تفاصيل الأصناف المباعة وتكاليفها:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: data.items.isEmpty
                        ? const Center(
                            child: Text('لا توجد بنود مسجلة لهذه الفاتورة'),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: DataTable(
                                      columnSpacing: 14,
                                      horizontalMargin: 8,
                                      headingRowColor: WidgetStateProperty.all(
                                        Colors.grey.shade200,
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('الصنف')),
                                        DataColumn(label: Text('الكمية')),
                                        DataColumn(label: Text('الوحدة')),
                                        DataColumn(label: Text('سعر البيع')),
                                        DataColumn(label: Text('التكلفة')),
                                        DataColumn(label: Text('الربح')),
                                      ],
                                      rows: data.items.map((it) {
                                        final profit = it.profit;
                                        final isProfit =
                                            profit != null && profit >= 0;
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(it.item.productName)),
                                            DataCell(
                                              Text(
                                                formatQuantity(
                                                  it.item.quantity,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(it.item.saleUnit)),
                                            DataCell(
                                              Text(
                                                '${it.revenue.toStringAsFixed(2)} ج.م',
                                              ),
                                            ),
                                            DataCell(
                                              Text(_formatCost(it.totalCost)),
                                            ),
                                            DataCell(
                                              Text(
                                                '${_formatProfit(profit)}'
                                                '${it.profitMargin == null ? '' : ' (${it.profitMargin!.toStringAsFixed(0)}%)'}',
                                                style: TextStyle(
                                                  color: profit == null
                                                      ? Colors.blueGrey
                                                      : isProfit
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= TAB 3: PRODUCTS PROFITABILITY =================
  Widget _buildProductsProfitTab() {
    final filtered = _productProfitsList.where((p) {
      if (_productSearchQuery.isEmpty) return true;
      return p.productName.toLowerCase().contains(
        _productSearchQuery.toLowerCase(),
      );
    }).toList();

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث باسم الصنف...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _productSearchQuery = val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'عدد الأصناف المباعة: ${filtered.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('لا توجد بيانات للأصناف'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                columnSpacing: 18,
                                horizontalMargin: 12,
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade100,
                                ),
                                columns: const [
                                  DataColumn(label: Text('اسم الصنف')),
                                  DataColumn(
                                    label: Text('الكمية المباعة (تخزين)'),
                                  ),
                                  DataColumn(label: Text('إجمالي المبيعات')),
                                  DataColumn(label: Text('إجمالي التكلفة')),
                                  DataColumn(label: Text('صافي الربح')),
                                  DataColumn(label: Text('هامش الربح')),
                                  DataColumn(label: Text('عمليات البيع')),
                                ],
                                rows: filtered.map((prod) {
                                  final profit = prod.totalProfit;
                                  final isProfit =
                                      profit != null && profit >= 0;
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          prod.productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${prod.totalQuantityInStorage == null ? 'غير محدد' : formatQuantity(prod.totalQuantityInStorage!)} ${prod.storageUnit}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${prod.totalRevenue.toStringAsFixed(2)} ج.م',
                                        ),
                                      ),
                                      DataCell(
                                        Text(_formatCost(prod.totalCost)),
                                      ),
                                      DataCell(
                                        Text(
                                          _formatProfit(profit),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: profit == null
                                                ? Colors.blueGrey
                                                : isProfit
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: profit == null
                                                ? Colors.blueGrey.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : isProfit
                                                ? Colors.green.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.red.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _formatMargin(prod.profitMargin),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: profit == null
                                                  ? Colors.blueGrey
                                                  : isProfit
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text('${prod.ordersCount}')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 4: EXPENSES & CASH FLOW =================
  Widget _buildExpensesAndCashFlowTab() {
    // Group expenses by category
    final Map<String, double> expensesByCategory = {};
    for (final exp in _filteredExpenses) {
      expensesByCategory[exp.category] =
          (expensesByCategory[exp.category] ?? 0.0) + exp.amount;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 950;
        return SingleChildScrollView(
          child: Column(
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildExpensesBreakdownCard(expensesByCategory),
                    ),
                    const SizedBox(width: AppStyles.spacingMd),
                    Expanded(flex: 2, child: _buildCashFlowCard()),
                  ],
                )
              else ...[
                _buildExpensesBreakdownCard(expensesByCategory),
                const SizedBox(height: AppStyles.spacingMd),
                _buildCashFlowCard(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpensesBreakdownCard(Map<String, double> expensesByCategory) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.deepOrange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'توزيع المصروفات التشغيلية حسب الفئة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  'الإجمالي: ${_totalExpenses.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (expensesByCategory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لا توجد مصروفات مسجلة في هذه الفترة'),
                ),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'الفئة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'المبلغ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'النسبة من المصروفات',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...expensesByCategory.entries.map((entry) {
                    final percent = _totalExpenses > 0
                        ? (entry.value / _totalExpenses) * 100
                        : 0.0;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('${entry.value.toStringAsFixed(2)} ج.م'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('${percent.toStringAsFixed(1)}%'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFlowCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Colors.teal,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'تقرير السيولة والتدفق النقدي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يوضح حركة السيولة النقدية الفعلية (المقبوض والمصروف للموردين والتشغيل)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              'المقبوضات النقدية من المبيعات (+)',
              '${_totalRevenue.toStringAsFixed(2)} ج.م',
              Colors.indigo,
            ),
            const Divider(),
            _buildSummaryRow(
              'المدفوع لفواتير المشتريات (-) (${_filteredPurchases.length} فاتورة)',
              '${_totalPurchasesAmount.toStringAsFixed(2)} ج.م',
              Colors.blueGrey,
            ),
            const Divider(),
            _buildSummaryRow(
              'المدفوع للمصروفات التشغيلية (-)',
              '${_totalExpenses.toStringAsFixed(2)} ج.م',
              Colors.deepOrange,
            ),
            const Divider(thickness: 1.5),
            _buildSummaryRow(
              'صافي التدفق النقدي (=)',
              '${_netCashFlow.toStringAsFixed(2)} ج.م',
              _netCashFlow >= 0 ? Colors.teal : Colors.red,
              isBold: true,
              fontSize: 16,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'ملاحظة: صافي الربح المحاسبي يختلف عن التدفق النقدي لأن بضاعة المشتريات تظل أصلاً في المخزن ولا تخصم من الأرباح إلا عند بيعها.',
                style: TextStyle(fontSize: 12, color: Colors.brown),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
