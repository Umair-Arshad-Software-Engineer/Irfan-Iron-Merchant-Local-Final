// lib/screens/profit_loss_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sale_provider.dart';
import '../providers/purchase_receipt_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/product_provider.dart';
import '../models/purchase_order_model.dart';
import '../models/product_model.dart';

class ProfitLossDashboardScreen extends StatefulWidget {
  const ProfitLossDashboardScreen({super.key});

  @override
  State<ProfitLossDashboardScreen> createState() =>
      _ProfitLossDashboardScreenState();
}

class _ProfitLossDashboardScreenState
    extends State<ProfitLossDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profitData = {};

  // ── Period / Date-range state ───────────────────────────────────────────────
  String _selectedPeriod = 'month'; // week | month | quarter | year | custom
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customRange;       // only used when _selectedPeriod == 'custom'

  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');
  final DateFormat _displayFormat    = DateFormat('MMM dd, yyyy');

  // ── Derived helpers ─────────────────────────────────────────────────────────
  DateTimeRange get _effectiveRange =>
      _selectedPeriod == 'custom' && _customRange != null
          ? _customRange!
          : _getDateRange();

  String get _rangeLabel {
    if (_selectedPeriod == 'custom' && _customRange != null) {
      return '${_displayFormat.format(_customRange!.start)}  →  '
          '${_displayFormat.format(_customRange!.end)}';
    }
    final r = _getDateRange();
    return '${_displayFormat.format(r.start)}  →  ${_displayFormat.format(r.end)}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfitData());
  }

  // ── Date-range picker ───────────────────────────────────────────────────────
  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF2D3142),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _customRange   = picked;
        _selectedPeriod = 'custom';
      });
      _loadProfitData();
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────────
  Future<void> _loadProfitData() async {
    setState(() => _isLoading = true);

    try {
      final saleProvider =
      Provider.of<SaleProvider>(context, listen: false);
      final purchaseReceiptProvider =
      Provider.of<PurchaseReceiptProvider>(context, listen: false);
      final purchaseOrderProvider =
      Provider.of<PurchaseOrderProvider>(context, listen: false);
      final productProvider =
      Provider.of<ProductProvider>(context, listen: false);

      await Future.wait([
        saleProvider.fetchSales(),
        purchaseOrderProvider.fetchPurchaseOrders(),
        productProvider.fetchProducts(),
      ]);

      final range = _effectiveRange;

      // ── Sales ───────────────────────────────────────────────────────────────
      final filteredSales = saleProvider.sales.where((sale) =>
      !sale.saleDate.isBefore(range.start) &&
          !sale.saleDate.isAfter(range.end)).toList();

      double totalSalesRevenue    = 0;
      double totalCostOfGoodsSold = 0;
      double totalCustomerDiscounts = 0;
      double totalSalesProfit     = 0;

      Map<String, double> profitByCustomer = {};
      Map<String, double> profitByProduct  = {};

      for (final sale in filteredSales) {
        double saleRevenue = 0;
        double saleCost    = 0;
        final saleDiscount = sale.discountAmount ?? 0;

        if (sale.items != null) {
          for (final item in sale.items!) {
            final product = productProvider.products.firstWhere(
                  (p) => p.id == item.productId,
              orElse: () => ProductModel(
                id: 0, itemName: 'Unknown', costPrice: 0, salePrice: 0,
                physicalQty: 0, availableQty: 0, minStock: 0, categoryId: 0,
                unitId: 0, isActive: true, createdAt: DateTime.now(),
                updatedAt: DateTime.now(), barcode: null, description: null,
                category: null, subcategory: null, unit: null,
              ),
            );

            final itemRevenue = item.unitPrice * item.quantity;
            final itemCost    = product.costPrice * item.quantity;
            saleRevenue += itemRevenue;
            saleCost    += itemCost;

            final productProfit = itemRevenue - itemCost;
            profitByProduct[product.itemName] =
                (profitByProduct[product.itemName] ?? 0) + productProfit;
          }
        }

        saleRevenue -= saleDiscount;
        totalCustomerDiscounts += saleDiscount;

        final saleProfit = saleRevenue - saleCost;
        totalSalesRevenue    += saleRevenue;
        totalCostOfGoodsSold += saleCost;
        totalSalesProfit     += saleProfit;

        if (sale.customer != null) {
          profitByCustomer[sale.customer!.name] =
              (profitByCustomer[sale.customer!.name] ?? 0) + saleProfit;
        }
      }

      // ── Purchases ───────────────────────────────────────────────────────────
      final filteredPOs = purchaseOrderProvider.purchaseOrders.where((po) =>
      !po.orderDate.isBefore(range.start) &&
          !po.orderDate.isAfter(range.end)).toList();

      double totalPurchaseSpend   = 0;
      double totalSupplierSavings = 0;
      Map<String, double> savingsBySupplier = {};

      for (final po in filteredPOs) {
        await purchaseReceiptProvider.fetchReceiptsByPurchaseOrder(po.id);

        for (final receipt in purchaseReceiptProvider.receipts) {
          if (receipt.receiptDate.isBefore(range.start) ||
              receipt.receiptDate.isAfter(range.end)) continue;

          double receiptTotal        = 0;
          double receiptSavings      = 0;

          if (receipt.items != null) {
            for (final item in receipt.items!) {
              if (item.purchaseOrderItemId != null &&
                  item.purchaseOrderItemId! > 0) {
                final poItem = po.items?.firstWhere(
                      (poi) => poi.id == item.purchaseOrderItemId,
                  orElse: () => PurchaseOrderItemModel(
                    id: 0, purchaseOrderId: 0, productId: 0,
                    quantityOrdered: 0, quantityReceived: 0, unitCost: 0,
                    lineTotal: 0, discountPercent: 0, taxPercent: 0,
                  ),
                );
                final original   = item.unitCost * item.quantityReceived;
                final discounted = original * (1 - ((poItem?.discountPercent ?? 0) / 100));
                receiptTotal   += discounted;
                receiptSavings += (original - discounted);
              } else {
                receiptTotal += item.unitCost * item.quantityReceived;
              }
            }
          }

          if (po.discountAmount > 0 && receiptTotal > 0) {
            final poTotal  = po.totalAmount > 0 ? po.totalAmount : 1;
            final portion  = receiptTotal / poTotal;
            final discount = po.discountAmount * portion;
            receiptTotal   -= discount;
            receiptSavings += discount;
          }

          totalPurchaseSpend   += receiptTotal;
          totalSupplierSavings += receiptSavings;

          if (po.supplier != null) {
            savingsBySupplier[po.supplier!.name] =
                (savingsBySupplier[po.supplier!.name] ?? 0) + receiptSavings;
          }
        }
      }

      final netProfit = totalSalesProfit + totalSupplierSavings;

      final sortedCustomers = profitByCustomer.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedProducts = profitByProduct.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedSuppliers = savingsBySupplier.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _profitData = {
          'totalSalesRevenue':      totalSalesRevenue,
          'totalCostOfGoodsSold':   totalCostOfGoodsSold,
          'totalSalesProfit':       totalSalesProfit,
          'totalCustomerDiscounts': totalCustomerDiscounts,
          'totalPurchaseSpend':     totalPurchaseSpend,
          'totalSupplierSavings':   totalSupplierSavings,
          'netProfit':              netProfit,
          'profitMargin': totalSalesRevenue > 0
              ? (totalSalesProfit / totalSalesRevenue * 100)
              : 0.0,
          'topCustomers': sortedCustomers,
          'topProducts':  sortedProducts,
          'topSuppliers': sortedSuppliers,
          'salesCount':   filteredSales.length,
          'purchaseCount': filteredPOs.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profit data: $e');
      setState(() => _isLoading = false);
    }
  }

  DateTimeRange _getDateRange() {
    final now = _selectedDate;
    switch (_selectedPeriod) {
      case 'week':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'quarter':
        final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(
          start: DateTime(now.year, qStart, 1),
          end: DateTime(now.year, qStart + 3, 0, 23, 59, 59),
        );
      case 'year':
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case 'month':
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profit & Loss',
          style: TextStyle(
              color: Color(0xFF2D3142),
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
            onPressed: _loadProfitData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF7C3AED)))
                : RefreshIndicator(
              onRefresh: _loadProfitData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKpiCards(),
                    const SizedBox(height: 20),
                    _buildProfitSummaryCard(),
                    const SizedBox(height: 20),
                    _buildTopPerformers(),
                    const SizedBox(height: 20),
                    _buildDetailedBreakdown(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    const periods = [
      {'value': 'week',    'label': 'This Week'},
      {'value': 'month',   'label': 'This Month'},
      {'value': 'quarter', 'label': 'Quarter'},
      {'value': 'year',    'label': 'This Year'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period chips ────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...periods.map((p) {
                  final selected = _selectedPeriod == p['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(p['label']!),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedPeriod = p['value']!);
                        _loadProfitData();
                      },
                      selectedColor:
                      const Color(0xFF7C3AED).withOpacity(0.15),
                      checkmarkColor: const Color(0xFF7C3AED),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF6B7280),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFE5E7EB),
                      ),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0),
                    ),
                  );
                }),
                // ── Custom range chip ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      Icons.date_range,
                      size: 16,
                      color: _selectedPeriod == 'custom'
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF6B7280),
                    ),
                    label: const Text('Custom'),
                    selected: _selectedPeriod == 'custom',
                    onSelected: (_) => _pickCustomRange(),
                    selectedColor:
                    const Color(0xFF7C3AED).withOpacity(0.15),
                    checkmarkColor: const Color(0xFF7C3AED),
                    labelStyle: TextStyle(
                      color: _selectedPeriod == 'custom'
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF6B7280),
                      fontWeight: _selectedPeriod == 'custom'
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: _selectedPeriod == 'custom'
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFFE5E7EB),
                    ),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 0),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Active date-range display ────────────────────────────────
          GestureDetector(
            onTap: _selectedPeriod == 'custom' ? _pickCustomRange : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rangeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  if (_selectedPeriod == 'custom') ...[
                    const Icon(Icons.edit_outlined,
                        size: 14, color: Color(0xFF7C3AED)),
                  ],
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_profitData['salesCount'] ?? 0} sales',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI cards ────────────────────────────────────────────────────────────────
  Widget _buildKpiCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildKpiCard(
          title: 'Sales Revenue',
          value: _currencyFormat.format(
              _profitData['totalSalesRevenue'] ?? 0),
          icon: Icons.trending_up,
          color: const Color(0xFF7C3AED),
          subtitle: 'Total sales',
        ),
        _buildKpiCard(
          title: 'Cost of Goods',
          value: _currencyFormat.format(
              _profitData['totalCostOfGoodsSold'] ?? 0),
          icon: Icons.shopping_bag,
          color: const Color(0xFFEF4444),
          subtitle: 'Product costs',
        ),
        _buildKpiCard(
          title: 'Sales Profit',
          value: _currencyFormat.format(
              _profitData['totalSalesProfit'] ?? 0),
          icon: Icons.account_balance_wallet,
          color: const Color(0xFF10B981),
          subtitle: 'Revenue - Cost',
        ),
        _buildKpiCard(
          title: 'Supplier Savings',
          value: _currencyFormat.format(
              _profitData['totalSupplierSavings'] ?? 0),
          icon: Icons.savings,
          color: const Color(0xFFF59E0B),
          subtitle: 'From receipts',
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF5)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142))),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────────
  Widget _buildProfitSummaryCard() {
    final netProfit         = _profitData['netProfit']              ?? 0;
    final profitMargin      = _profitData['profitMargin']           ?? 0;
    final customerDiscounts = _profitData['totalCustomerDiscounts'] ?? 0;
    final supplierSavings   = _profitData['totalSupplierSavings']   ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NET PROFIT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(profitMargin as double).toStringAsFixed(1)}% Margin',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Active range shown in the card too
          Text(
            _rangeLabel,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(netProfit),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Customer Discounts',
                    _currencyFormat.format(customerDiscounts),
                    Icons.local_offer),
              ),
              Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: _buildSummaryItem('Supplier Savings',
                    _currencyFormat.format(supplierSavings),
                    Icons.savings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.8), fontSize: 11)),
      ],
    );
  }

  // ── Top performers ───────────────────────────────────────────────────────────
  Widget _buildTopPerformers() {
    final topCustomers =
        _profitData['topCustomers'] as List<MapEntry<String, double>>? ?? [];
    final topProducts =
        _profitData['topProducts'] as List<MapEntry<String, double>>? ?? [];
    final topSuppliers =
        _profitData['topSuppliers'] as List<MapEntry<String, double>>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Performers',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142))),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTopList(
                title: 'Most Profitable Customers',
                items: topCustomers,
                icon: Icons.people,
                color: const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTopList(
                title: 'Most Profitable Products',
                items: topProducts,
                icon: Icons.inventory,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTopList(
                title: 'Top Suppliers by Savings',
                items: topSuppliers,
                icon: Icons.business,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopList({
    required String title,
    required List<MapEntry<String, double>> items,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No data available',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ),
            )
          else
            ...items.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.key.length > 25
                          ? '${item.key.substring(0, 25)}...'
                          : item.key,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151)),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(item.value),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  // ── Detailed breakdown ───────────────────────────────────────────────────────
  Widget _buildDetailedBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profit & Loss Breakdown',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142))),
          const SizedBox(height: 20),
          _buildBreakdownRow(
            'Sales Revenue',
            _profitData['totalSalesRevenue'] ?? 0,
            Icons.trending_up,
            const Color(0xFF7C3AED),
          ),
          _buildBreakdownRow(
            'Less: Cost of Goods Sold',
            _profitData['totalCostOfGoodsSold'] ?? 0,
            Icons.remove,
            const Color(0xFFEF4444),
            isNegative: true,
          ),
          const Divider(height: 24),
          _buildBreakdownRow(
            'Gross Profit from Sales',
            _profitData['totalSalesProfit'] ?? 0,
            Icons.calculate,
            const Color(0xFF10B981),
            isBold: true,
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            'Add: Supplier Discounts Earned',
            _profitData['totalSupplierSavings'] ?? 0,
            Icons.add,
            const Color(0xFF10B981),
          ),
          _buildBreakdownRow(
            'Less: Customer Discounts Given',
            _profitData['totalCustomerDiscounts'] ?? 0,
            Icons.remove,
            const Color(0xFFEF4444),
            isNegative: true,
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NET PROFIT',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED))),
                Text(
                  _currencyFormat.format(_profitData['netProfit'] ?? 0),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
      String label,
      double value,
      IconData icon,
      Color color, {
        bool isNegative = false,
        bool isBold = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    isBold ? FontWeight.bold : FontWeight.normal,
                    color: const Color(0xFF374151))),
          ),
          Text(
            isNegative
                ? '-${_currencyFormat.format(value)}'
                : _currencyFormat.format(value),
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                isBold ? FontWeight.bold : FontWeight.w600,
                color: isNegative ? const Color(0xFFEF4444) : color),
          ),
        ],
      ),
    );
  }
}