// lib/screens/sales/sale_report_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../models/sale_model.dart';
import '../../providers/sale_provider.dart';
import '../../models/product_model.dart';
import '../../models/customer.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';


// ─────────────────────────────────────────────
//  REPORT TAB ENUM
// ─────────────────────────────────────────────

enum ReportTab { overview, daily, byType, byPayment, topProducts, topCustomers, creditDue }

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────

class SaleReportScreen extends StatefulWidget {
  const SaleReportScreen({super.key});

  @override
  State<SaleReportScreen> createState() => _SaleReportScreenState();
}

class _SaleReportScreenState extends State<SaleReportScreen>
    with SingleTickerProviderStateMixin {
  ReportTab _activeTab = ReportTab.overview;

  // Date range
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _toDate = DateTime.now();


  // Add these with the other data variables
  String _customerSearchQuery = '';
  String _productSearchQuery = '';

  // Data
  bool _isLoading = false;
  Map<String, dynamic> _overviewData = {};
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _byTypeData = [];
  List<Map<String, dynamic>> _byPaymentData = [];
  List<Map<String, dynamic>> _topProductsData = [];
  List<Map<String, dynamic>> _topCustomersData = [];
  List<SaleModel> _creditDueSales = [];



  @override
  void initState() {
    super.initState();
    // Defer until after first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllReports();
    });
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<Map<String, String>> _getHeaders() async {
    // Mirror SaleProvider header logic
    try {
      final prefs = await _prefsInstance();
      final token = prefs.getString('auth_token');
      return {
        'Content-Type': 'application/json',
        'Authorization': token != null ? 'Bearer $token' : '',
      };
    } catch (_) {
      return {'Content-Type': 'application/json'};
    }
  }

  // Lazy SharedPreferences (avoids direct dependency if not imported)
  dynamic _prefs;
  Future<dynamic> _prefsInstance() async {
    _prefs ??= await _loadPrefs();
    return _prefs;
  }

  Future<dynamic> _loadPrefs() async {
    // Use SharedPreferences if available
    try {
      // ignore: deprecated_member_use
      return await (throw UnimplementedError());
    } catch (_) {
      return _FakePrefs();
    }
  }


  Future<void> _loadAllReports() async {
    setState(() {
      _isLoading = true;
      _customerSearchQuery = '';   // ← reset searches on refresh
      _productSearchQuery = '';    // ← reset searches on refresh
    });
    try {
      // First, ensure we have fresh sales data
      await _loadSalesData();

      // Now fetch all reports using the loaded data
      await Future.wait([
        _fetchOverview(),
        _fetchDaily(),
        _fetchByType(),
        _fetchByPayment(),
        _fetchTopProducts(),
        _fetchTopCustomers(),
        _fetchCreditDue(),
      ]);
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSalesData() async {
    try {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);

      // Force refresh sales data with a large limit
      await saleProvider.fetchSales(
        refresh: true,
        limit: 1000, // Load a large number to get all data
      );

      debugPrint('Loaded ${saleProvider.sales.length} sales');
    } catch (e) {
      debugPrint('Error loading sales data: $e');
    }
  }


  String get _dateQuery =>
      'date_from=${_fromDate.toIso8601String().split('T').first}'
          '&date_to=${_toDate.toIso8601String().split('T').first}';

  Future<void> _fetchOverview() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.salesUrl}/reports/overview?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _overviewData = j['data'] ?? {});
          return;
        }
      }
    } catch (_) {}
    // Fallback: compute from SaleProvider sales list
    _computeOverviewFromProvider();
  }

  void _computeOverviewFromProvider() {
    final provider = Provider.of<SaleProvider>(context, listen: false);

    debugPrint('Computing overview from ${provider.sales.length} sales');

    final sales = provider.sales.where((s) {
      final d = s.saleDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    debugPrint('Filtered ${sales.length} sales for date range');

    double totalRevenue = 0, totalDiscount = 0, totalPaid = 0, totalCredit = 0;
    int posCount = 0, invoiceCount = 0, creditCount = 0;

    for (final s in sales) {
      totalRevenue += s.grandTotal;
      totalDiscount += s.discountAmount;
      totalPaid += s.amountPaid;
      if (s.paymentStatus == 'unpaid' || s.paymentStatus == 'partial') {
        totalCredit += (s.grandTotal - s.amountPaid);
        creditCount++;
      }
      if (s.saleType == 'pos') posCount++;
      if (s.saleType == 'invoice') invoiceCount++;
    }

    setState(() {
      _overviewData = {
        'total_sales': sales.length,
        'total_revenue': totalRevenue,
        'total_discount': totalDiscount,
        'total_paid': totalPaid,
        'total_credit': totalCredit,
        'pos_count': posCount,
        'invoice_count': invoiceCount,
        'credit_count': creditCount,
        'net_revenue': totalRevenue - totalDiscount,
      };
    });
  }

  Future<void> _fetchDaily() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.salesUrl}/reports/daily?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _dailyData =
          List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeDailyFromProvider();
  }

  void _computeDailyFromProvider() {
    final provider = Provider.of<SaleProvider>(context, listen: false);
    final sales = provider.sales.where((s) {
      final d = s.saleDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byDay = {};
    for (final s in sales) {
      final key = s.saleDate.toIso8601String().split('T').first;
      byDay[key] ??= {'date': key, 'count': 0, 'revenue': 0.0, 'discount': 0.0};
      byDay[key]!['count'] = (byDay[key]!['count'] as int) + 1;
      byDay[key]!['revenue'] =
          (byDay[key]!['revenue'] as double) + s.grandTotal ;
      byDay[key]!['discount'] =
          (byDay[key]!['discount'] as double) + s.discountAmount;
    }

    final sorted = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    setState(() => _dailyData = sorted.map((e) => e.value).toList());
  }

  Future<void> _fetchByType() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.salesUrl}/reports/by-type?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _byTypeData =
          List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeByTypeFromProvider();
  }

  void _computeByTypeFromProvider() {
    final provider = Provider.of<SaleProvider>(context, listen: false);
    final sales = provider.sales.where((s) {
      final d = s.saleDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byType = {};
    for (final s in sales) {
      final t = s.saleType;
      byType[t] ??= {'type': t, 'count': 0, 'revenue': 0.0};
      byType[t]!['count'] = (byType[t]!['count'] as int) + 1;
      byType[t]!['revenue'] = (byType[t]!['revenue'] as double) + s.grandTotal ;
    }
    setState(() => _byTypeData = byType.values.toList());
  }

  Future<void> _fetchByPayment() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.salesUrl}/reports/by-payment?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _byPaymentData =
          List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeByPaymentFromProvider();
  }

  void _computeByPaymentFromProvider() {
    final provider = Provider.of<SaleProvider>(context, listen: false);
    final sales = provider.sales.where((s) {
      final d = s.saleDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byMethod = {};
    for (final s in sales) {
      final m = s.paymentMethod ?? 'unknown';
      byMethod[m] ??= {'method': m, 'count': 0, 'revenue': 0.0};
      byMethod[m]!['count'] = (byMethod[m]!['count'] as int) + 1;
      byMethod[m]!['revenue'] =
          (byMethod[m]!['revenue'] as double) + s.amountPaid;
    }
    setState(() => _byPaymentData = byMethod.values.toList());
  }

  Future<void> _fetchTopProducts() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.salesUrl}/reports/top-products?$_dateQuery&limit=10');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _topProductsData =
          List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeTopProductsFromProvider(); // fallback
  }

  void _computeTopProductsFromProvider() {
    final provider = Provider.of<SaleProvider>(context, listen: false);
    final sales = provider.sales.where((s) {
      final d = s.saleDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byProduct = {};
    for (final s in sales) {
      for (final item in s.items!) {
        final key = item.productId.toString();
        byProduct[key] ??= {
          'product_name': item.productName ?? 'Unknown',
          'barcode': item.barcode ?? '',
          'total_quantity': 0,
          'total_revenue': 0.0,
        };
        byProduct[key]!['total_quantity'] =
            (byProduct[key]!['total_quantity'] as int) + item.quantity;
        byProduct[key]!['total_revenue'] =
            (byProduct[key]!['total_revenue'] as double) + item.totalPrice;
      }
    }

    final sorted = byProduct.values.toList()
      ..sort((a, b) =>
          (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));

    setState(() => _topProductsData = sorted.take(10).toList());
  }

  Future<void> _fetchTopCustomers() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.salesUrl}/reports/top-customers?$_dateQuery&limit=10');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _topCustomersData =
          List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeTopCustomersFromProvider(); // fallback
  }

  void _computeTopCustomersFromProvider() {
    final provider = Provider.of<SaleProvider>(context, listen: false);
    final sales = provider.sales.where((s) {
      final d = s.saleDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byCustomer = {};
    for (final s in sales) {
      if (s.customer == null) continue;
      final key = s.customer!.id.toString();
      byCustomer[key] ??= {
        'customer_id': s.customer!.id,  // ← add this line
        'customer_name': s.customer!.name,
        'contact': s.customer!.contact ?? '',
        'invoice_count': 0,
        'total_spent': 0.0,
      };
      byCustomer[key]!['invoice_count'] =
          (byCustomer[key]!['invoice_count'] as int) + 1;
      byCustomer[key]!['total_spent'] =
          (byCustomer[key]!['total_spent'] as double) + s.grandTotal;
    }

    final sorted = byCustomer.values.toList()
      ..sort((a, b) =>
          (b['total_spent'] as double).compareTo(a['total_spent'] as double));

    setState(() => _topCustomersData = sorted.take(10).toList());
  }

  Future<void> _fetchCreditDue() async {
    try {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      await provider.fetchSales(
        paymentStatus: 'unpaid',
        refresh: true,
        limit: 50,
      );
      setState(() {
        _creditDueSales = provider.sales
            .where((s) =>
        s.paymentStatus == 'unpaid' || s.paymentStatus == 'partial')
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
          const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate = range.end;
      });
      await _loadAllReports();
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    DateTime from;
    switch (preset) {
      case 'today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        from = now.subtract(const Duration(days: 6));
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
      case '3months':
        from = DateTime(now.year, now.month - 2, 1);
        break;
      default:
        from = now.subtract(const Duration(days: 29));
    }
    setState(() {
      _fromDate = from;
      _toDate = now;
    });
    _loadAllReports();
  }

  Widget _highlightText(String text, String query,
      {TextStyle? style})
  {
    final baseStyle = style ??
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D));
    if (query.isEmpty) return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: baseStyle.copyWith(
          color: const Color(0xFF7C3AED),
          fontWeight: FontWeight.bold,
          backgroundColor: const Color(0xFFF3F0FF),
        ),
      ));
      start = idx + query.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }



  // ── BUILD ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: Column(
        children: [
          _buildHeader(),
          _buildDateBar(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF7C3AED)))
                : _buildActiveTab(),
          ),
        ],
      ),
    );
  }

  // ── HEADER ──

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
      ),
      child: Row(
        children: [

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales Report',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2D))),
              Text('Analytics & performance overview',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadAllReports,
            icon: const Icon(Icons.refresh,
                color: Color(0xFF7C3AED)),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ── DATE BAR ──

  Widget _buildDateBar() {
    final presets = [
      ('Today', 'today'),
      ('This Week', 'week'),
      ('This Month', 'month'),
      ('3 Months', '3months'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _setPreset(p.$2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(p.$1,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF374151))),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range,
                      size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    '${_fmt(_fromDate)} – ${_fmt(_toDate)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB BAR ──

  Widget _buildTabBar() {
    final tabs = [
      (ReportTab.overview, Icons.dashboard_outlined, 'Overview'),
      (ReportTab.daily, Icons.show_chart, 'Daily'),
      (ReportTab.byType, Icons.category_outlined, 'By Type'),
      (ReportTab.byPayment, Icons.payment, 'Payment'),
      (ReportTab.topProducts, Icons.inventory_2_outlined, 'Products'),
      (ReportTab.topCustomers, Icons.people_outline, 'Customers'),
      (ReportTab.creditDue, Icons.credit_card_off_outlined, 'Credit Due'),
    ];

    return Container(
      height: 48,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: tabs.map((t) {
          final isActive = _activeTab == t.$1;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(t.$2,
                      size: 14,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(t.$3,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF6B7280))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── ACTIVE TAB ──

  Widget _buildActiveTab() {
    return switch (_activeTab) {
      ReportTab.overview => _buildOverviewTab(),
      ReportTab.daily => _buildDailyTab(),
      ReportTab.byType => _buildByTypeTab(),
      ReportTab.byPayment => _buildByPaymentTab(),
      ReportTab.topProducts => _buildTopProductsTab(),
      ReportTab.topCustomers => _buildTopCustomersTab(),
      ReportTab.creditDue => _buildCreditDueTab(),
    };
  }

  // ══════════════════════════════════════════
  //  OVERVIEW TAB
  // ══════════════════════════════════════════

  Widget _buildOverviewTab() {
    final d = _overviewData;
    final totalRevenue = _toDouble(d['total_revenue']);
    final netRevenue = _toDouble(d['net_revenue'] ?? totalRevenue);
    final totalDiscount = _toDouble(d['total_discount']);
    final totalPaid = _toDouble(d['total_paid'] ?? totalRevenue);
    final totalCredit = _toDouble(d['total_credit']);
    final totalSales = _toInt(d['total_sales']);
    final posCount = _toInt(d['pos_count']);
    final invoiceCount = _toInt(d['invoice_count']);
    final creditCount = _toInt(d['credit_count']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Big KPI Row ──
          Row(
            children: [
              Expanded(
                  child: _bigKpiCard(
                    'Total Revenue',
                    'Rs ${_fmtAmount(totalRevenue)}',
                    Icons.trending_up_rounded,
                    const Color(0xFF7C3AED),
                    const Color(0xFFF3F0FF),
                  )),
              const SizedBox(width: 12),
              Expanded(
                  child: _bigKpiCard(
                    'Net Revenue',
                    'Rs ${_fmtAmount(netRevenue)}',
                    Icons.monetization_on_outlined,
                    const Color(0xFF10B981),
                    const Color(0xFFECFDF5),
                  )),
            ],
          ),
          const SizedBox(height: 12),

          // ── Stats Row ──
          Row(
            children: [
              Expanded(
                  child: _kpiCard('Total Sales', totalSales.toString(),
                      Icons.receipt_long, const Color(0xFF3B82F6))),
              const SizedBox(width: 10),
              Expanded(
                  child: _kpiCard('Discount Given',
                      'Rs ${_fmtAmount(totalDiscount)}',
                      Icons.local_offer, const Color(0xFFF59E0B))),
              const SizedBox(width: 10),
              Expanded(
                  child: _kpiCard('Credit Pending',
                      'Rs ${_fmtAmount(totalCredit)}',
                      Icons.credit_card_off, const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 16),

          // ── Type breakdown ──
          _sectionTitle('Sales Breakdown'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _breakdownCard(
                    'POS Sales',
                    posCount,
                    totalSales,
                    const Color(0xFF7C3AED),
                    Icons.point_of_sale,
                  )),
              const SizedBox(width: 10),
              Expanded(
                  child: _breakdownCard(
                    'Invoices',
                    invoiceCount,
                    totalSales,
                    const Color(0xFF3B82F6),
                    Icons.receipt_long,
                  )),
              const SizedBox(width: 10),
              Expanded(
                  child: _breakdownCard(
                    'Credit Sales',
                    creditCount,
                    totalSales,
                    const Color(0xFFEF4444),
                    Icons.credit_card,
                  )),
            ],
          ),
          const SizedBox(height: 16),

          // ── Payment status ──
          _sectionTitle('Payment Status'),
          const SizedBox(height: 10),
          _paymentStatusCard(totalPaid, totalCredit, totalRevenue),
          const SizedBox(height: 16),

          // ── Summary table ──
          _sectionTitle('Financial Summary'),
          const SizedBox(height: 10),
          _summaryTable([
            ('Total Revenue', 'Rs ${_fmtAmount(totalRevenue)}', null),
            ('(-) Discount', '- Rs ${_fmtAmount(totalDiscount)}',
            const Color(0xFFEF4444)),
            ('Net Revenue', 'Rs ${_fmtAmount(netRevenue)}',
            const Color(0xFF10B981)),
            ('Amount Collected', 'Rs ${_fmtAmount(totalPaid)}',
            const Color(0xFF3B82F6)),
            ('Pending Credit', 'Rs ${_fmtAmount(totalCredit)}',
            const Color(0xFFEF4444)),
          ]),
        ],
      ),
    );
  }

  Widget _bigKpiCard(String label, String value, IconData icon,
      Color accent, Color bg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF5)),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accent, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accent)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _breakdownCard(
      String label, int count, int total, Color color, IconData icon)
  {
    final pct = total == 0 ? 0.0 : count / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(count.toString(),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _paymentStatusCard(
      double paid, double credit, double total)
  {
    final paidPct = total == 0 ? 0.0 : paid / total;
    final creditPct = total == 0 ? 0.0 : credit / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _statusDot(const Color(0xFF10B981), 'Collected',
                  'Rs ${_fmtAmount(paid)}'),
              const Spacer(),
              _statusDot(const Color(0xFFEF4444), 'Pending',
                  'Rs ${_fmtAmount(credit)}'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  Flexible(
                    flex: (paidPct * 1000).toInt(),
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  if (creditPct > 0)
                    Flexible(
                      flex: (creditPct * 1000).toInt(),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                  if (paidPct + creditPct < 1)
                    Flexible(
                      flex: ((1 - paidPct - creditPct) * 1000).toInt(),
                      child: Container(
                          color: const Color(0xFFE5E7EB)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(Color color, String label, String value) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF))),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ],
    );
  }

  Widget _summaryTable(
      List<(String, String, Color?)> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final idx = e.key;
          final row = e.value;
          final isLast = idx == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isLast
                  ? const Color(0xFFF8F5FF)
                  : Colors.transparent,
              border: !isLast
                  ? const Border(
                  bottom: BorderSide(
                      color: Color(0xFFF3F4F6)))
                  : null,
              borderRadius: isLast
                  ? const BorderRadius.vertical(
                  bottom: Radius.circular(12))
                  : null,
            ),
            child: Row(
              children: [
                Text(row.$1,
                    style: TextStyle(
                        fontSize: 13,
                        color: row.$3 != null
                            ? row.$3!
                            : const Color(0xFF374151),
                        fontWeight: isLast
                            ? FontWeight.bold
                            : FontWeight.normal)),
                const Spacer(),
                Text(row.$2,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: row.$3 ??
                            const Color(0xFF1E1E2D))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  DAILY TAB
  // ══════════════════════════════════════════

  Widget _buildDailyTab() {
    if (_dailyData.isEmpty) {
      return _buildEmptyState('No daily data available',
          Icons.show_chart_rounded);
    }

    // Max revenue for bar scaling
    final maxRev = _dailyData
        .map((d) => _toDouble(d['revenue']))
        .fold(0.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Daily Revenue Chart'),
          const SizedBox(height: 12),
          // ── Mini bar chart ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _dailyData.map((d) {
                      final rev = _toDouble(d['revenue']);
                      final pct = maxRev == 0 ? 0.0 : rev / maxRev;
                      return Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: pct.clamp(0.02, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED)
                                          .withOpacity(0.8),
                                      borderRadius:
                                      const BorderRadius.vertical(
                                          top: Radius.circular(3)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                // Date labels (show first/mid/last)
                Row(
                  children: [
                    Text(
                      _dailyData.isNotEmpty
                          ? _shortDate(_dailyData.first['date'] ?? '')
                          : '',
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF9CA3AF)),
                    ),
                    const Spacer(),
                    if (_dailyData.length > 2)
                      Text(
                        _shortDate(_dailyData[_dailyData.length ~/ 2]
                        ['date'] ??
                            ''),
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9CA3AF)),
                      ),
                    const Spacer(),
                    Text(
                      _dailyData.isNotEmpty
                          ? _shortDate(_dailyData.last['date'] ?? '')
                          : '',
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Daily Breakdown'),
          const SizedBox(height: 10),
          // ── Table header ──
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              border: Border.all(color: const Color(0xFFEEEEF5)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Date',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                Expanded(
                    child: Text('Sales',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                Expanded(
                    flex: 2,
                    child: Text('Revenue',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                Expanded(
                    flex: 2,
                    child: Text('Discount',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12)),
              border: const Border(
                left: BorderSide(color: Color(0xFFEEEEF5)),
                right: BorderSide(color: Color(0xFFEEEEF5)),
                bottom: BorderSide(color: Color(0xFFEEEEF5)),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailyData.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (ctx, i) {
                final d = _dailyData[i];
                final rev = _toDouble(d['revenue']);
                final disc = _toDouble(d['discount']);
                final cnt = _toInt(d['count']);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          _fmtDateStr(d['date']?.toString() ?? ''),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: _chip(
                            cnt.toString(),
                            const Color(0xFFF3F0FF),
                            const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rs ${_fmtAmount(rev)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          disc > 0
                              ? '- Rs ${_fmtAmount(disc)}'
                              : '—',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11,
                              color: disc > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF9CA3AF)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  BY TYPE TAB
  // ══════════════════════════════════════════

  Widget _buildByTypeTab() {
    if (_byTypeData.isEmpty) {
      return _buildEmptyState(
          'No type data available', Icons.category_outlined);
    }

    final total = _byTypeData.fold(
        0.0, (s, d) => s + _toDouble(d['revenue']));

    final typeColors = {
      'pos': const Color(0xFF7C3AED),
      'invoice': const Color(0xFF3B82F6),
      'credit': const Color(0xFFEF4444),
    };

    final typeLabels = {
      'pos': 'POS Counter',
      'invoice': 'Invoice',
      'credit': 'Credit Sale',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Revenue by Sale Type'),
          const SizedBox(height: 12),

          // ── Donut-style visual ──
          Row(
            children: _byTypeData.map((d) {
              final type = d['type']?.toString() ?? '';
              final rev = _toDouble(d['revenue']);
              final cnt = _toInt(d['count']);
              final pct = total == 0 ? 0.0 : rev / total;
              final color =
                  typeColors[type] ?? const Color(0xFF9CA3AF);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: color.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.receipt_long,
                                size: 14, color: color),
                          ),
                          const Spacer(),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Rs ${_fmtAmount(rev)}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      Text('$cnt sales',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: color.withOpacity(0.1),
                          valueColor:
                          AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(typeLabels[type] ?? type,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Detailed Breakdown'),
          const SizedBox(height: 10),
          _summaryTable(_byTypeData.map((d) {
            final type = d['type']?.toString() ?? '';
            final rev = _toDouble(d['revenue']);
            final cnt = _toInt(d['count']);
            final color =
                typeColors[type] ?? const Color(0xFF374151);
            return (
            '${typeLabels[type] ?? type} ($cnt sales)',
            'Rs ${_fmtAmount(rev)}',
            color
            );
          }).toList()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  BY PAYMENT TAB
  // ══════════════════════════════════════════

  Widget _buildByPaymentTab() {
    if (_byPaymentData.isEmpty) {
      return _buildEmptyState(
          'No payment data available', Icons.payment);
    }

    final total = _byPaymentData.fold(
        0.0, (s, d) => s + _toDouble(d['revenue']));

    final methodColors = {
      'cash': const Color(0xFF10B981),
      'bank': const Color(0xFF3B82F6),
      'cheque': const Color(0xFFF59E0B),
      'slip': const Color(0xFF8B5CF6),
      'credit': const Color(0xFFEF4444),
    };
    final methodIcons = {
      'cash': Icons.payments_outlined,
      'bank': Icons.account_balance_outlined,
      'cheque': Icons.receipt_long_outlined,
      'slip': Icons.receipt_outlined,
      'credit': Icons.credit_card_outlined,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Revenue by Payment Method'),
          const SizedBox(height: 12),
          ..._byPaymentData.map((d) {
            final method = d['method']?.toString() ?? '';
            final rev = _toDouble(d['revenue']);
            final cnt = _toInt(d['count']);
            final pct = total == 0 ? 0.0 : rev / total;
            final color =
                methodColors[method] ?? const Color(0xFF9CA3AF);
            final icon =
                methodIcons[method] ?? Icons.payment;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _capitalise(method),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text('Rs ${_fmtAmount(rev)}',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: color)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor:
                            AlwaysStoppedAnimation(color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('$cnt transactions · ${(pct * 100).toStringAsFixed(1)}% of total',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

// ══════════════════════════════════════════
//  TOP PRODUCTS TAB (CLICKABLE)
// ══════════════════════════════════════════

  Widget _buildTopProductsTab() {
    // Filter products by search query
    final filtered = _topProductsData.where((item) {
      if (_productSearchQuery.isEmpty) return true;
      final q = _productSearchQuery.toLowerCase();
      final name = (item['product_name'] ?? '').toString().toLowerCase();
      final barcode = (item['barcode'] ?? '').toString().toLowerCase();
      return name.contains(q) || barcode.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Top Selling Products'),
          const SizedBox(height: 12),

          // ── Search Bar ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEF5)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _productSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by product name or barcode...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                suffixIcon: _productSearchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF9CA3AF)),
                  onPressed: () => setState(() => _productSearchQuery = ''),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            _buildEmptyState(
              _productSearchQuery.isEmpty
                  ? 'No product sales data available for this period'
                  : 'No products found for "$_productSearchQuery"',
              Icons.inventory_2_outlined,
            )
          else ...[
            // Summary stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: _buildProductStat(
                      'Products Found',
                      filtered.length,
                      Icons.shopping_bag_outlined,
                      const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProductStat(
                      'Total Qty Sold',
                      filtered.fold<int>(0, (sum, item) => sum + _toInt(item['total_quantity'])),
                      Icons.category_outlined,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: const Color(0xFFEEEEF5)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: Text('Product',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(child: Text('Qty', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(flex: 2, child: Text('Revenue', textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(flex: 2, child: Text('Avg Price', textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: const Border(
                  left: BorderSide(color: Color(0xFFEEEEF5)),
                  right: BorderSide(color: Color(0xFFEEEEF5)),
                  bottom: BorderSide(color: Color(0xFFEEEEF5)),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (ctx, i) {
                  final item = filtered[i];
                  // Find original rank (index in full unfiltered list)
                  final originalRank = _topProductsData.indexOf(item);
                  final productName = item['product_name']?.toString() ?? 'Unknown Product';
                  final barcode = item['barcode']?.toString();
                  final quantity = _toInt(item['total_quantity']);
                  final revenue = _toDouble(item['total_revenue']);
                  final double avgPrice = quantity > 0 ? revenue / quantity : 0.0;

                  Color rankColor = Colors.transparent;
                  if (originalRank == 0) rankColor = const Color(0xFFFFD700).withOpacity(0.1);
                  else if (originalRank == 1) rankColor = const Color(0xFFC0C0C0).withOpacity(0.1);
                  else if (originalRank == 2) rankColor = const Color(0xFFCD7F32).withOpacity(0.1);

                  return Container(
                    color: rankColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: originalRank < 3
                                ? const Color(0xFF7C3AED).withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${originalRank + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: originalRank < 3 ? FontWeight.bold : FontWeight.normal,
                                color: originalRank < 3 ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _highlightText(productName, _productSearchQuery),
                              if (barcode != null && barcode.isNotEmpty)
                                Text('Barcode: $barcode',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F0FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(quantity.toString(),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED))),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Rs ${_fmtAmount(revenue)}', textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981))),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Rs ${_fmtAmount(avgPrice)}', textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Only show contribution chart when not searching
            if (_productSearchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle('Sales Contribution'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(children: _buildProductContributionBars()),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildProductContributionBars() {
    if (_topProductsData.isEmpty) return [];

    final totalRevenue = _topProductsData.fold<double>(
        0, (sum, item) => sum + _toDouble(item['total_revenue']));

    // Take top 5 for the chart
    final top5 = _topProductsData.take(5).toList();
    final otherRevenue = _topProductsData.skip(5).fold<double>(
        0, (sum, item) => sum + _toDouble(item['total_revenue']));

    final List<Widget> bars = [];

    for (int i = 0; i < top5.length; i++) {
      final item = top5[i];
      final productName = item['product_name']?.toString() ?? 'Unknown';
      final revenue = _toDouble(item['total_revenue']);
      final percentage = totalRevenue > 0 ? (revenue / totalRevenue) * 100 : 0;

      bars.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    '${i + 1}. ${productName.length > 20 ? '${productName.substring(0, 20)}...' : productName}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProductBarColor(i),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // Add "Others" bar if there are more than 5 products
    if (otherRevenue > 0 && _topProductsData.length > 5) {
      final percentage = totalRevenue > 0 ? (otherRevenue / totalRevenue) * 100 : 0;
      bars.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Others (${_topProductsData.length - 5} products)',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ));
    }

    return bars;
  }

  Color _getProductBarColor(int index) {
    const colors = [
      Color(0xFF7C3AED), // Purple
      Color(0xFF3B82F6), // Blue
      Color(0xFF10B981), // Green
      Color(0xFFF59E0B), // Orange
      Color(0xFFEF4444), // Red
    ];
    return colors[index % colors.length];
  }

  Widget _buildProductStat(String label, int value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// ══════════════════════════════════════════
//  TOP CUSTOMERS TAB (CLICKABLE)
// ══════════════════════════════════════════

  Widget _buildTopCustomersTab() {
    // Filter customers by search query
    final filtered = _topCustomersData.where((c) {
      if (_customerSearchQuery.isEmpty) return true;
      final q = _customerSearchQuery.toLowerCase();
      final name = (c['customer_name'] ?? '').toString().toLowerCase();
      final contact = (c['contact'] ?? '').toString().toLowerCase();
      return name.contains(q) || contact.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Top Customers by Revenue'),
          const SizedBox(height: 12),

          // ── Search Bar ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEF5)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _customerSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name or contact number...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                suffixIcon: _customerSearchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF9CA3AF)),
                  onPressed: () => setState(() => _customerSearchQuery = ''),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            _buildEmptyState(
              _customerSearchQuery.isEmpty
                  ? 'No customer sales data available for this period'
                  : 'No customers found for "$_customerSearchQuery"',
              Icons.people_outline,
            )
          else ...[
            // Summary stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCustomerStat(
                      _customerSearchQuery.isEmpty ? 'Total Customers' : 'Results Found',
                      filtered.length,
                      Icons.people_alt_outlined,
                      const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCustomerStat(
                      'Avg. per Customer',
                      'Rs ${_fmtAmount(filtered.fold<double>(0, (sum, c) =>
                      sum + _toDouble(c['total_spent'])) / filtered.length)}',
                      Icons.trending_up_rounded,
                      const Color(0xFF10B981),
                      isAmount: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Customer cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final customer = filtered[i];
                final originalRank = _topCustomersData.indexOf(customer);
                final name = customer['customer_name']?.toString() ?? 'Unknown Customer';
                final contact = customer['contact']?.toString();
                final totalSpent = _toDouble(customer['total_spent']);
                final invoiceCount = _toInt(customer['invoice_count']);
                final double avgPerInvoice = invoiceCount > 0 ? totalSpent / invoiceCount : 0.0;

                Widget rankBadge;
                if (originalRank == 0) {
                  rankBadge = Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events, size: 14, color: Colors.white),
                  );
                } else if (originalRank == 1) {
                  rankBadge = Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFC0C0C0), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events, size: 14, color: Colors.white),
                  );
                } else if (originalRank == 2) {
                  rankBadge = Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFCD7F32), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events, size: 14, color: Colors.white),
                  );
                } else {
                  rankBadge = Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${originalRank + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                              color: Color(0xFF9CA3AF))),
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEF5)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02),
                        blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showCustomerDetails(customer),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            rankBadge,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _highlightText(name, _customerSearchQuery,
                                      style: const TextStyle(fontSize: 14,
                                          fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.receipt_outlined, size: 11, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text('$invoiceCount invoice${invoiceCount != 1 ? 's' : ''}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                      const SizedBox(width: 12),
                                      if (contact != null && contact.isNotEmpty) ...[
                                        Icon(Icons.phone_outlined, size: 11, color: Colors.grey[400]),
                                        const SizedBox(width: 4),
                                        _highlightText(contact, _customerSearchQuery,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Rs ${_fmtAmount(totalSpent)}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED))),
                                const SizedBox(height: 2),
                                Text('Avg: Rs ${_fmtAmount(avgPerInvoice)}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                              ],
                            ),
                            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Only show distribution chart when not searching
            if (_customerSearchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle('Revenue Distribution'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: _buildCustomerDistribution(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerStat(String label, dynamic value, IconData icon, Color color,
      {bool isAmount = false}) {
    String displayValue = value.toString();
    if (isAmount && value is String) {
      displayValue = value;
    } else if (!isAmount && value is int) {
      displayValue = value.toString();
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerDistribution() {
    if (_topCustomersData.isEmpty) return const SizedBox.shrink();

    final totalRevenue = _topCustomersData.fold<double>(
        0, (sum, c) => sum + _toDouble(c['total_spent']));

    // Take top 4 for the list
    final top4 = _topCustomersData.take(4).toList();
    final otherRevenue = _topCustomersData.skip(4).fold<double>(
        0, (sum, c) => sum + _toDouble(c['total_spent']));

    final List<Widget> items = [];

    for (int i = 0; i < top4.length; i++) {
      final customer = top4[i];
      final name = customer['customer_name']?.toString() ?? 'Unknown';
      final spent = _toDouble(customer['total_spent']);
      final percentage = totalRevenue > 0 ? (spent / totalRevenue) * 100 : 0;

      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getCustomerColor(i),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                name.length > 20 ? '${name.substring(0, 20)}...' : name,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getCustomerColor(i),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 4,
                backgroundColor: _getCustomerColor(i).withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_getCustomerColor(i)),
              ),
            ),
          ],
        ),
      ));
    }

    if (otherRevenue > 0 && _topCustomersData.length > 4) {
      final percentage = totalRevenue > 0 ? (otherRevenue / totalRevenue) * 100 : 0;
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF9CA3AF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              flex: 3,
              child: Text(
                'Others',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 4,
                backgroundColor: const Color(0xFF9CA3AF).withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ));
    }

    return Column(children: items);
  }

  Color _getCustomerColor(int index) {
    const colors = [
      Color(0xFF7C3AED), // Purple
      Color(0xFF3B82F6), // Blue
      Color(0xFF10B981), // Green
      Color(0xFFF59E0B), // Orange
    ];
    return colors[index % colors.length];
  }

  void _showCustomerDetails(Map<String, dynamic> customerData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CustomerDetailsSheet(
        customerData: customerData,
      ),
    );
  }

  // ══════════════════════════════════════════
  //  CREDIT DUE TAB
  // ══════════════════════════════════════════

  Widget _buildCreditDueTab() {
    final totalDue = _creditDueSales.fold(
        0.0, (s, sale) => s + (sale.grandTotal  - sale.amountPaid));
    final overdue = _creditDueSales
        .where((s) =>
    s.dueDate != null && s.dueDate!.isBefore(DateTime.now()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Row
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Total Due',
                  'Rs ${_fmtAmount(totalDue)}',
                  Icons.credit_card_off,
                  const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Invoices',
                  _creditDueSales.length.toString(),
                  Icons.receipt_long,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Overdue',
                  overdue.length.toString(),
                  Icons.warning_amber,
                  const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _sectionTitle('Pending Credit Sales'),
          const SizedBox(height: 10),

          if (_creditDueSales.isEmpty)
            _buildEmptyState(
                'No credit dues found 🎉', Icons.check_circle_outline)
          else ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                border: Border.all(color: const Color(0xFFEEEEF5)),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: Text('Customer',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280)))),
                  Expanded(
                      child: Text('Date',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280)))),
                  Expanded(
                      child: Text('Amount',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280)))),
                  Expanded(
                      child: Text('Status',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280)))),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
                border: const Border(
                  left: BorderSide(color: Color(0xFFEEEEF5)),
                  right: BorderSide(color: Color(0xFFEEEEF5)),
                  bottom: BorderSide(color: Color(0xFFEEEEF5)),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _creditDueSales.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (ctx, i) {
                  final s = _creditDueSales[i];
                  final due = s.grandTotal  - s.amountPaid;
                  final isOverdue = s.dueDate != null &&
                      s.dueDate!.isBefore(DateTime.now());
                  return Container(
                    color: isOverdue
                        ? const Color(0xFFFFF5F5)
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.customer?.name ?? 'Unknown',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (s.dueDate != null)
                                Text(
                                  'Due: ${_fmt(s.dueDate!)}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: isOverdue
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF9CA3AF)),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _fmt(s.saleDate),
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Rs ${_fmtAmount(due)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444)),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: _chip(
                              isOverdue
                                  ? 'Overdue'
                                  : s.paymentStatus == 'partial'
                                  ? 'Partial'
                                  : 'Unpaid',
                              isOverdue
                                  ? const Color(0xFFFEE2E2)
                                  : s.paymentStatus == 'partial'
                                  ? const Color(0xFFFFF3CD)
                                  : const Color(0xFFFFEDD5),
                              isOverdue
                                  ? const Color(0xFFDC2626)
                                  : s.paymentStatus == 'partial'
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFFC2410C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── HELPERS ──────────────────────────────

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E1E2D)),
  );

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text,
        style: TextStyle(
            fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
  );

  Widget _buildEmptyState(String msg, IconData icon) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
              color: Color(0xFFF3F0FF), shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(height: 16),
        Text(msg,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF9CA3AF))),
      ],
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFEEEEF5)),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2)),
    ],
  );

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _fmtAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _fmtDateStr(String s) {
    try {
      final d = DateTime.parse(s);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return s;
    }
  }

  String _shortDate(String s) {
    try {
      final d = DateTime.parse(s);
      return '${d.day}/${d.month}';
    } catch (_) {
      return s;
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// Stub for when SharedPreferences is not directly available
class _FakePrefs {
  String? getString(String key) => null;
}

// ═════════════════════════════════════════════════════════════════
//  CUSTOMER DETAILS SHEET
// ═════════════════════════════════════════════════════════════════
class _CustomerDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> customerData;

  const _CustomerDetailsSheet({required this.customerData});

  @override
  State<_CustomerDetailsSheet> createState() => _CustomerDetailsSheetState();
}

class _CustomerDetailsSheetState extends State<_CustomerDetailsSheet> {
  List<SaleModel> _customerSales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomerSales();
  }

  Future<void> _fetchCustomerSales() async {
    try {
      final customerId = widget.customerData['customer_id'] as int?;
      if (customerId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final provider = Provider.of<SaleProvider>(context, listen: false);
      await provider.fetchSales(
        customerId: customerId,
        refresh: true,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _customerSales = List<SaleModel>.from(provider.sales);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.customerData['customer_name']?.toString() ?? 'Unknown Customer';
    final contact = widget.customerData['contact']?.toString() ?? 'No contact';
    final totalSpent = _toDouble(widget.customerData['total_spent']);
    final invoiceCount = _toInt(widget.customerData['invoice_count']);
    final double avgPerInvoice = invoiceCount > 0 ? totalSpent / invoiceCount : 0.0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFF3F0FF),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E2D))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(contact,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats cards
            Row(
              children: [
                Expanded(child: _buildDetailCard('Total Spent',
                    'Rs ${_fmtAmount(totalSpent)}',
                    Icons.payments_outlined, const Color(0xFF7C3AED))),
                const SizedBox(width: 10),
                Expanded(child: _buildDetailCard('Invoices',
                    invoiceCount.toString(),
                    Icons.receipt_long_outlined, const Color(0xFF3B82F6))),
                const SizedBox(width: 10),
                Expanded(child: _buildDetailCard('Avg/Invoice',
                    'Rs ${_fmtAmount(avgPerInvoice)}',
                    Icons.trending_up_rounded, const Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Recent Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D))),
            const SizedBox(height: 12),

            // Activity list
            Expanded(
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                  : _customerSales.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    const Text('No sales found',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                  ],
                ),
              )
                  : ListView.builder(
                controller: scrollCtrl,
                itemCount: _customerSales.length,
                itemBuilder: (ctx, i) {
                  final sale = _customerSales[i];
                  final due = sale.grandTotal - sale.amountPaid;
                  final statusColor = _getStatusColor(sale.paymentStatus);
                  return GestureDetector(               // ← wrap with this
                    onTap: () => _showSaleDetail(sale), // ← add tap
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEEEEF5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                                sale.saleType == 'pos' ? Icons.point_of_sale : Icons.receipt,
                                size: 16, color: statusColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sale.invoiceNumber,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(DateFormat('dd MMM yyyy').format(sale.saleDate),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                if (due > 0)
                                  Text('Due: Rs ${_fmtAmount(due)}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Rs ${_fmtAmount(sale.grandTotal)}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                      color: statusColor)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_capitalise(sale.paymentStatus),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                        color: statusColor)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)), // ← add arrow
                        ],
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return const Color(0xFF10B981);
      case 'partial': return const Color(0xFFF59E0B);
      case 'unpaid': return const Color(0xFFEF4444);
      default: return const Color(0xFF9CA3AF);
    }
  }

  Widget _buildDetailCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  void _showSaleDetail(SaleModel sale) {
    final statusColor = _getStatusColor(sale.paymentStatus);
    final due = sale.grandTotal - sale.amountPaid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        sale.saleType == 'pos' ? Icons.point_of_sale : Icons.receipt_long,
                        color: statusColor, size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sale.invoiceNumber,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E2D))),
                          Text(
                            '${_capitalise(sale.saleType)} · ${DateFormat('dd MMM yyyy').format(sale.saleDate)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_capitalise(sale.paymentStatus),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [

                    // ── Financial Summary ──
                    _detailSection('Financial Summary', [
                      _detailRow('Subtotal', 'Rs ${_fmtAmount(sale.subtotal)}'),
                      if (sale.discountAmount > 0)
                        _detailRow('Discount',
                            '- Rs ${_fmtAmount(sale.discountAmount)}',
                            valueColor: const Color(0xFFEF4444)),
                      if (sale.taxAmount > 0)
                        _detailRow('Tax', '+ Rs ${_fmtAmount(sale.taxAmount)}'),
                      _detailRow('Grand Total', 'Rs ${_fmtAmount(sale.grandTotal)}',
                          isBold: true, valueColor: const Color(0xFF7C3AED)),
                      _detailRow('Amount Paid', 'Rs ${_fmtAmount(sale.amountPaid)}',
                          valueColor: const Color(0xFF10B981)),
                      if (due > 0)
                        _detailRow('Balance Due', 'Rs ${_fmtAmount(due)}',
                            isBold: true, valueColor: const Color(0xFFEF4444)),
                    ]),

                    const SizedBox(height: 16),

                    // ── Payment Info ──
                    _detailSection('Payment Info', [
                      _detailRow('Method', _capitalise(sale.paymentMethod)),
                      _detailRow('Status', _capitalise(sale.paymentStatus),
                          valueColor: statusColor),
                      if (sale.dueDate != null)
                        _detailRow('Due Date',
                            DateFormat('dd MMM yyyy').format(sale.dueDate!),
                            valueColor: sale.isOverdue
                                ? const Color(0xFFEF4444)
                                : null),
                      if (sale.changeAmount > 0)
                        _detailRow('Change', 'Rs ${_fmtAmount(sale.changeAmount)}'),
                    ]),

                    const SizedBox(height: 16),

                    // ── Items ──
                    if (sale.items != null && sale.items!.isNotEmpty) ...[
                      const Text('Items Purchased',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E2D))),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEEEEF5)),
                        ),
                        child: Column(
                          children: sale.items!.asMap().entries.map((e) {
                            final idx = e.key;
                            final item = e.value;
                            final isLast = idx == sale.items!.length - 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: !isLast
                                    ? const Border(bottom: BorderSide(
                                    color: Color(0xFFF3F4F6)))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F0FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text('${idx + 1}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF7C3AED))),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E1E2D))),
                                        if (item.barcode != null && item.barcode!.isNotEmpty)
                                          Text('Barcode: ${item.barcode}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF9CA3AF))),
                                        Text(
                                          'Rs ${_fmtAmount(item.unitPrice)} × ${item.quantity}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7280)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text('Rs ${_fmtAmount(item.totalPrice)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981))),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // ── Notes ──
                    if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Notes',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E2D))),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFEF3C7)),
                        ),
                        child: Text(sale.notes!,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF92400E))),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E2D))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEF5)),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, Color? valueColor})
  {
    final isLast = false; // handled by caller if needed
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E1E2D),
              )),
        ],
      ),
    );
  }


  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _fmtAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}