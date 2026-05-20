// lib/screens/purchases/purchase_report_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../models/purchase_order_model.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/product_provider.dart';
import 'purchase_order_detail_screen.dart';

// ─────────────────────────────────────────────
//  REPORT TAB ENUM
// ─────────────────────────────────────────────

enum PurchaseReportTab {
  overview,
  daily,
  byStatus,
  bySupplier,
  topProducts,
  topSuppliers,
  pendingOrders
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  State<PurchaseReportScreen> createState() => _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends State<PurchaseReportScreen>
    with SingleTickerProviderStateMixin {
  PurchaseReportTab _activeTab = PurchaseReportTab.overview;

  // Date range
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _toDate = DateTime.now();

  // Search queries
  String _supplierSearchQuery = '';
  String _productSearchQuery = '';

  // Data
  bool _isLoading = false;
  Map<String, dynamic> _overviewData = {};
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _byStatusData = [];
  List<Map<String, dynamic>> _bySupplierData = [];
  List<Map<String, dynamic>> _topProductsData = [];
  List<Map<String, dynamic>> _topSuppliersData = [];
  List<PurchaseOrderModel> _pendingOrders = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllReports();
    });
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<Map<String, String>> _getHeaders() async {
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

  dynamic _prefs;
  Future<dynamic> _prefsInstance() async {
    _prefs ??= await _loadPrefs();
    return _prefs;
  }

  Future<dynamic> _loadPrefs() async {
    try {
      return await (throw UnimplementedError());
    } catch (_) {
      return _FakePrefs();
    }
  }

  Future<void> _loadAllReports() async {
    setState(() {
      _isLoading = true;
      _supplierSearchQuery = '';
      _productSearchQuery = '';
    });
    try {
      // Load suppliers and products FIRST, then purchase data
      await _loadSuppliersAndProducts();
      await _loadPurchaseData();

      await Future.wait([
        _fetchOverview(),
        _fetchDaily(),
        _fetchByStatus(),
        _fetchBySupplier(),
        _fetchTopProducts(),
        _fetchTopSuppliers(),
        _fetchPendingOrders(),
      ]);
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSuppliersAndProducts() async {
    try {
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false);

      await Future.wait([
        supplierProvider.fetchSuppliers(context: context),
        productProvider.fetchProducts(),
      ]);

      debugPrint('Loaded ${supplierProvider.suppliers.length} suppliers and ${productProvider.products.length} products');
    } catch (e) {
      debugPrint('Error loading suppliers/products: $e');
    }
  }

  Future<void> _loadPurchaseData() async {
    try {
      final purchaseProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
      await purchaseProvider.fetchPurchaseOrders(
        refresh: true,
        // Remove limit: 1000
      );
      debugPrint('Loaded ${purchaseProvider.purchaseOrders.length} purchase orders');
    } catch (e) {
      debugPrint('Error loading purchase data: $e');
    }
  }
  String get _dateQuery =>
      'date_from=${_fromDate.toIso8601String().split('T').first}'
          '&date_to=${_toDate.toIso8601String().split('T').first}';

  // ─── API FALLBACKS & COMPUTATIONS ─────────────────────────────────────────

  Future<void> _fetchOverview() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/purchase-orders/reports/overview?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _overviewData = j['data'] ?? {});
          return;
        }
      }
    } catch (_) {}
    _computeOverviewFromProvider();
  }

  void _computeOverviewFromProvider() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);

    final orders = provider.purchaseOrders.where((o) {
      final d = o.orderDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    double totalOrderValue = 0, totalReceived = 0, totalTax = 0, totalDiscount = 0, totalShipping = 0;
    int draftCount = 0, orderedCount = 0, partialCount = 0, receivedCount = 0, cancelledCount = 0;
    int totalItems = 0;

    for (final o in orders) {
      totalOrderValue += o.totalAmount;
      totalTax += o.taxAmount;
      totalDiscount += o.discountAmount;
      totalShipping += o.shippingCost;

      switch (o.status) {
        case 'draft': draftCount++; break;
        case 'ordered': orderedCount++; break;
        case 'partial': partialCount++; break;
        case 'received': receivedCount++; break;
        case 'cancelled': cancelledCount++; break;
      }

      if (o.items != null) {
        for (final item in o.items!) {
          totalItems += item.quantityOrdered;
          totalReceived += item.quantityReceived;
        }
      }
    }

    setState(() {
      _overviewData = {
        'total_orders': orders.length,
        'total_order_value': totalOrderValue,
        'total_received_value': totalReceived > 0 ? (totalReceived / (totalItems > 0 ? totalItems : 1)) * totalOrderValue : 0,
        'total_tax': totalTax,
        'total_discount': totalDiscount,
        'total_shipping': totalShipping,
        'draft_count': draftCount,
        'ordered_count': orderedCount,
        'partial_count': partialCount,
        'received_count': receivedCount,
        'cancelled_count': cancelledCount,
        'total_items_ordered': totalItems,
        'total_items_received': totalReceived,
      };
    });
  }

  Future<void> _fetchDaily() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/purchase-orders/reports/daily?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _dailyData = List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeDailyFromProvider();
  }

  void _computeDailyFromProvider() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    final orders = provider.purchaseOrders.where((o) {
      final d = o.orderDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byDay = {};
    for (final o in orders) {
      final key = o.orderDate.toIso8601String().split('T').first;
      byDay[key] ??= {'date': key, 'count': 0, 'value': 0.0, 'items': 0};
      byDay[key]!['count'] = (byDay[key]!['count'] as int) + 1;
      byDay[key]!['value'] = (byDay[key]!['value'] as double) + o.totalAmount;
      byDay[key]!['items'] = (byDay[key]!['items'] as int) + (o.items?.length ?? 0);
    }

    final sorted = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    setState(() => _dailyData = sorted.map((e) => e.value).toList());
  }

  Future<void> _fetchByStatus() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/purchase-orders/reports/by-status?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _byStatusData = List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeByStatusFromProvider();
  }

  void _computeByStatusFromProvider() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    final orders = provider.purchaseOrders.where((o) {
      final d = o.orderDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byStatus = {};
    for (final o in orders) {
      final s = o.status;
      byStatus[s] ??= {'status': s, 'count': 0, 'value': 0.0, 'items': 0};
      byStatus[s]!['count'] = (byStatus[s]!['count'] as int) + 1;
      byStatus[s]!['value'] = (byStatus[s]!['value'] as double) + o.totalAmount;
      byStatus[s]!['items'] = (byStatus[s]!['items'] as int) + (o.items?.length ?? 0);
    }
    setState(() => _byStatusData = byStatus.values.toList());
  }

  Future<void> _fetchBySupplier() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/purchase-orders/reports/by-supplier?$_dateQuery');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _bySupplierData = List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeBySupplierFromProvider();
  }

  void _computeBySupplierFromProvider() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    final orders = provider.purchaseOrders.where((o) {
      final d = o.orderDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> bySupplier = {};
    for (final o in orders) {
      if (o.supplier == null) continue;
      final key = o.supplier!.id.toString();
      bySupplier[key] ??= {
        'supplier_id': o.supplier!.id,
        'supplier_name': o.supplier!.name,
        'contact': o.supplier!.contact ?? '',
        'order_count': 0,
        'total_spent': 0.0,
        'items_ordered': 0,
        'items_received': 0,
      };
      bySupplier[key]!['order_count'] = (bySupplier[key]!['order_count'] as int) + 1;
      bySupplier[key]!['total_spent'] = (bySupplier[key]!['total_spent'] as double) + o.totalAmount;

      if (o.items != null) {
        for (final item in o.items!) {
          bySupplier[key]!['items_ordered'] = (bySupplier[key]!['items_ordered'] as int) + item.quantityOrdered;
          bySupplier[key]!['items_received'] = (bySupplier[key]!['items_received'] as int) + item.quantityReceived;
        }
      }
    }

    final sorted = bySupplier.values.toList()
      ..sort((a, b) => (b['total_spent'] as double).compareTo(a['total_spent'] as double));

    setState(() => _bySupplierData = sorted);
  }

  Future<void> _fetchTopProducts() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/purchase-orders/reports/top-products?$_dateQuery&limit=10');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _topProductsData = List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeTopProductsFromProvider();
  }

  void _computeTopProductsFromProvider() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    final orders = provider.purchaseOrders.where((o) {
      final d = o.orderDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> byProduct = {};
    for (final o in orders) {
      if (o.items == null) continue;
      for (final item in o.items!) {
        final key = item.productId.toString();
        byProduct[key] ??= {
          'product_name': item.product?.itemName ?? 'Unknown',
          'barcode': item.product?.barcode ?? '',
          'total_ordered': 0,
          'total_received': 0,
          'total_spent': 0.0,
          'avg_unit_cost': 0.0,
          'order_count': 0,
        };
        byProduct[key]!['total_ordered'] = (byProduct[key]!['total_ordered'] as int) + item.quantityOrdered;
        byProduct[key]!['total_received'] = (byProduct[key]!['total_received'] as int) + item.quantityReceived;
        byProduct[key]!['total_spent'] = (byProduct[key]!['total_spent'] as double) +
            (item.quantityOrdered * item.unitCost);
        byProduct[key]!['order_count'] = (byProduct[key]!['order_count'] as int) + 1;
      }
    }

    // Calculate average unit cost
    for (final entry in byProduct.entries) {
      entry.value['avg_unit_cost'] =
          entry.value['total_spent'] / (entry.value['total_ordered'] > 0 ? entry.value['total_ordered'] : 1);
    }

    final sorted = byProduct.values.toList()
      ..sort((a, b) => (b['total_spent'] as double).compareTo(a['total_spent'] as double));

    setState(() => _topProductsData = sorted.take(10).toList());
  }

  Future<void> _fetchTopSuppliers() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/purchase-orders/reports/top-suppliers?$_dateQuery&limit=10');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          setState(() => _topSuppliersData = List<Map<String, dynamic>>.from(j['data'] ?? []));
          return;
        }
      }
    } catch (_) {}
    _computeTopSuppliersFromProvider();
  }

  void _computeTopSuppliersFromProvider() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    final orders = provider.purchaseOrders.where((o) {
      final d = o.orderDate;
      return !d.isBefore(_fromDate) && !d.isAfter(_toDate);
    }).toList();

    final Map<String, Map<String, dynamic>> bySupplier = {};
    for (final o in orders) {
      if (o.supplier == null) continue;
      final key = o.supplier!.id.toString();
      bySupplier[key] ??= {
        'supplier_id': o.supplier!.id,
        'supplier_name': o.supplier!.name,
        'contact': o.supplier!.contact ?? '',
        'email': o.supplier!.email ?? '',
        'order_count': 0,
        'total_spent': 0.0,
        'items_ordered': 0,
        'items_received': 0,
        'avg_order_value': 0.0,
      };
      bySupplier[key]!['order_count'] = (bySupplier[key]!['order_count'] as int) + 1;
      bySupplier[key]!['total_spent'] = (bySupplier[key]!['total_spent'] as double) + o.totalAmount;

      if (o.items != null) {
        for (final item in o.items!) {
          bySupplier[key]!['items_ordered'] = (bySupplier[key]!['items_ordered'] as int) + item.quantityOrdered;
          bySupplier[key]!['items_received'] = (bySupplier[key]!['items_received'] as int) + item.quantityReceived;
        }
      }
    }

    for (final entry in bySupplier.entries) {
      entry.value['avg_order_value'] =
          entry.value['total_spent'] / (entry.value['order_count'] > 0 ? entry.value['order_count'] : 1);
    }

    final sorted = bySupplier.values.toList()
      ..sort((a, b) => (b['total_spent'] as double).compareTo(a['total_spent'] as double));

    setState(() => _topSuppliersData = sorted.take(10).toList());
  }

  Future<void> _fetchPendingOrders() async {
    try {
      final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);

      // Fetch ordered orders - remove limit
      await provider.fetchPurchaseOrders(
        status: 'ordered',
        refresh: true,
        // Remove limit: 50
      );

      final ordered = List<PurchaseOrderModel>.from(provider.purchaseOrders);

      // Fetch partial orders - remove limit
      await provider.fetchPurchaseOrders(
        status: 'partial',
        refresh: true,
        // Remove limit: 50
      );

      final partial = List<PurchaseOrderModel>.from(provider.purchaseOrders);

      setState(() {
        _pendingOrders = [...ordered, ...partial];
        _pendingOrders.sort((a, b) => a.orderDate.compareTo(b.orderDate));
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
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
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

  Widget _highlightText(String text, String query, {TextStyle? style}) {
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

  // ─── BUILD ─────────────────────────────────────────────────────────────────

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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                : _buildActiveTab(),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Purchase Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
              Text('Analytics & procurement overview', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadAllReports,
            icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ─── DATE BAR ──────────────────────────────────────────────────────────────

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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(p.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    '${_fmt(_fromDate)} – ${_fmt(_toDate)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB BAR ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      (PurchaseReportTab.overview, Icons.dashboard_outlined, 'Overview'),
      (PurchaseReportTab.daily, Icons.show_chart, 'Daily'),
      (PurchaseReportTab.byStatus, Icons.assignment_turned_in_outlined, 'By Status'),
      (PurchaseReportTab.bySupplier, Icons.business, 'By Supplier'),
      (PurchaseReportTab.topProducts, Icons.inventory_2_outlined, 'Products'),
      (PurchaseReportTab.topSuppliers, Icons.people_outline, 'Suppliers'),
      (PurchaseReportTab.pendingOrders, Icons.pending_actions, 'Pending'),
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
                color: isActive ? const Color(0xFF7C3AED) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(t.$2, size: 14, color: isActive ? Colors.white : const Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(
                    t.$3,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── ACTIVE TAB ────────────────────────────────────────────────────────────

  Widget _buildActiveTab() {
    return switch (_activeTab) {
      PurchaseReportTab.overview => _buildOverviewTab(),
      PurchaseReportTab.daily => _buildDailyTab(),
      PurchaseReportTab.byStatus => _buildByStatusTab(),
      PurchaseReportTab.bySupplier => _buildBySupplierTab(),
      PurchaseReportTab.topProducts => _buildTopProductsTab(),
      PurchaseReportTab.topSuppliers => _buildTopSuppliersTab(),
      PurchaseReportTab.pendingOrders => _buildPendingOrdersTab(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  OVERVIEW TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    final d = _overviewData;
    final totalOrderValue = _toDouble(d['total_order_value']);
    final totalReceivedValue = _toDouble(d['total_received_value']);
    final totalTax = _toDouble(d['total_tax']);
    final totalDiscount = _toDouble(d['total_discount']);
    final totalShipping = _toDouble(d['total_shipping']);
    final totalOrders = _toInt(d['total_orders']);
    final draftCount = _toInt(d['draft_count']);
    final orderedCount = _toInt(d['ordered_count']);
    final partialCount = _toInt(d['partial_count']);
    final receivedCount = _toInt(d['received_count']);
    final cancelledCount = _toInt(d['cancelled_count']);
    final totalItemsOrdered = _toInt(d['total_items_ordered']);
    final totalItemsReceived = _toInt(d['total_items_received']);

    final completionRate = totalItemsOrdered > 0
        ? (totalItemsReceived / totalItemsOrdered * 100).clamp(0, 100)
        : 0.0;

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
                    'Total Spend',
                    _fmtAmount(totalOrderValue),
                    Icons.trending_up_rounded,
                    const Color(0xFF7C3AED),
                    const Color(0xFFF3F0FF),
                  )),
              const SizedBox(width: 12),
              Expanded(
                  child: _bigKpiCard(
                    'Received Value',
                    _fmtAmount(totalReceivedValue),
                    Icons.inventory_2_rounded,
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
                  child: _kpiCard('Total Orders', totalOrders.toString(),
                      Icons.receipt_long, const Color(0xFF3B82F6))),
              const SizedBox(width: 10),
              Expanded(
                  child: _kpiCard('Items Ordered', totalItemsOrdered.toString(),
                      Icons.category_outlined, const Color(0xFFF59E0B))),
              const SizedBox(width: 10),
              Expanded(
                  child: _kpiCard('Items Received', totalItemsReceived.toString(),
                      Icons.check_circle_outline, const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 16),

          // ── Completion rate bar ──
          _sectionTitle('Order Completion'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Items Received', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    Text('${completionRate.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: completionRate / 100,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statPill('${(completionRate).toStringAsFixed(0)}% Complete',
                          Icons.check_circle, const Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statPill('${(100 - completionRate).toStringAsFixed(0)}% Pending',
                          Icons.pending, const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Status breakdown ──
          _sectionTitle('Orders by Status'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _breakdownCard(
                    'Draft',
                    draftCount,
                    totalOrders,
                    const Color(0xFF9CA3AF),
                    Icons.drafts,
                  )),
              const SizedBox(width: 10),
              Expanded(
                  child: _breakdownCard(
                    'Ordered',
                    orderedCount,
                    totalOrders,
                    const Color(0xFF3B82F6),
                    Icons.shopping_cart,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _breakdownCard(
                    'Partial',
                    partialCount,
                    totalOrders,
                    const Color(0xFFF59E0B),
                    Icons.star_half,
                  )),
              const SizedBox(width: 10),
              Expanded(
                  child: _breakdownCard(
                    'Received',
                    receivedCount,
                    totalOrders,
                    const Color(0xFF10B981),
                    Icons.check_circle,
                  )),
              const SizedBox(width: 10),
              Expanded(
                  child: _breakdownCard(
                    'Cancelled',
                    cancelledCount,
                    totalOrders,
                    const Color(0xFFEF4444),
                    Icons.cancel,
                  )),
            ],
          ),
          const SizedBox(height: 16),

          // ── Financial Summary ──
          _sectionTitle('Financial Summary'),
          const SizedBox(height: 10),
          _summaryTable([
            ('Subtotal (before discounts)', _fmtAmount(totalOrderValue + totalDiscount - totalTax - totalShipping), null),
            ('(-) Discount', '-${_fmtAmount(totalDiscount)}', const Color(0xFFEF4444)),
            ('(+) Tax', '+${_fmtAmount(totalTax)}', const Color(0xFF3B82F6)),
            ('(+) Shipping', '+${_fmtAmount(totalShipping)}', const Color(0xFFF59E0B)),
            ('Total Order Value', _fmtAmount(totalOrderValue), const Color(0xFF7C3AED)),
          ]),
        ],
      ),
    );
  }

  Widget _bigKpiCard(String label, String value, IconData icon, Color accent, Color bg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF5)),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
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
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
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
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _breakdownCard(String label, int count, int total, Color color, IconData icon) {
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _statPill(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _summaryTable(List<(String, String, Color?)> rows) {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isLast ? const Color(0xFFF8F5FF) : Colors.transparent,
              border: !isLast ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))) : null,
              borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : null,
            ),
            child: Row(
              children: [
                Text(row.$1,
                    style: TextStyle(
                        fontSize: 13,
                        color: row.$3 != null ? row.$3! : const Color(0xFF374151),
                        fontWeight: isLast ? FontWeight.bold : FontWeight.normal)),
                const Spacer(),
                Text(row.$2,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: row.$3 ?? const Color(0xFF1E1E2D))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DAILY TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDailyTab() {
    if (_dailyData.isEmpty) {
      return _buildEmptyState('No daily data available', Icons.show_chart_rounded);
    }

    final maxValue = _dailyData
        .map((d) => _toDouble(d['value']))
        .fold(0.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Daily Purchase Value'),
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
                      final value = _toDouble(d['value']);
                      final pct = maxValue == 0 ? 0.0 : value / maxValue;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: pct.clamp(0.02, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withOpacity(0.8),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
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
                // Date labels
                Row(
                  children: [
                    Text(_dailyData.isNotEmpty ? _shortDate(_dailyData.first['date'] ?? '') : '',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                    const Spacer(),
                    if (_dailyData.length > 2)
                      Text(_shortDate(_dailyData[_dailyData.length ~/ 2]['date'] ?? ''),
                          style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                    const Spacer(),
                    Text(_dailyData.isNotEmpty ? _shortDate(_dailyData.last['date'] ?? '') : '',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: const Color(0xFFEEEEF5)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(child: Text('Orders', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('Value', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                Expanded(flex: 2, child: Text('Items', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
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
              itemCount: _dailyData.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (ctx, i) {
                final d = _dailyData[i];
                final value = _toDouble(d['value']);
                final count = _toInt(d['count']);
                final items = _toInt(d['items']);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(_fmtDateStr(d['date']?.toString() ?? ''),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      Expanded(child: Center(child: _chip(count.toString(), const Color(0xFFF3F0FF), const Color(0xFF7C3AED)))),
                      Expanded(flex: 2, child: Text(_fmtAmount(value), textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
                      Expanded(flex: 2, child: Text(items.toString(), textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  BY STATUS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildByStatusTab() {
    if (_byStatusData.isEmpty) {
      return _buildEmptyState('No status data available', Icons.assignment_turned_in_outlined);
    }

    final total = _byStatusData.fold(0.0, (s, d) => s + _toDouble(d['value']));

    final statusColors = {
      'draft': const Color(0xFF9CA3AF),
      'ordered': const Color(0xFF3B82F6),
      'partial': const Color(0xFFF59E0B),
      'received': const Color(0xFF10B981),
      'cancelled': const Color(0xFFEF4444),
    };

    final statusLabels = {
      'draft': 'Draft',
      'ordered': 'Ordered',
      'partial': 'Partial',
      'received': 'Received',
      'cancelled': 'Cancelled',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Value by Order Status'),
          const SizedBox(height: 12),

          // Status cards
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _byStatusData.map((d) {
              final status = d['status']?.toString() ?? '';
              final value = _toDouble(d['value']);
              final count = _toInt(d['count']);
              final items = _toInt(d['items']);
              final pct = total == 0 ? 0.0 : value / total;
              final color = statusColors[status] ?? const Color(0xFF9CA3AF);

              return Container(
                width: (MediaQuery.of(context).size.width - 56) / 2,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(statusLabels[status] ?? status,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_fmtAmount(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$count order${count != 1 ? 's' : ''}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                        Text('$items items', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 3,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${(pct * 100).toStringAsFixed(1)}% of total',
                        style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Detailed Breakdown'),
          const SizedBox(height: 10),
          _summaryTable(_byStatusData.map((d) {
            final status = d['status']?.toString() ?? '';
            final value = _toDouble(d['value']);
            final count = _toInt(d['count']);
            final color = statusColors[status] ?? const Color(0xFF374151);
            return ('${statusLabels[status] ?? status} ($count orders)', _fmtAmount(value), color);
          }).toList()),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BY SUPPLIER TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBySupplierTab() {
    if (_bySupplierData.isEmpty) {
      return _buildEmptyState('No supplier data available', Icons.business);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Spend by Supplier'),
          const SizedBox(height: 12),

          ..._bySupplierData.map((d) {
            final name = d['supplier_name']?.toString() ?? 'Unknown';
            final spent = _toDouble(d['total_spent']);
            final orders = _toInt(d['order_count']);
            final itemsOrdered = _toInt(d['items_ordered']);
            final itemsReceived = _toInt(d['items_received']);
            final receivedPct = itemsOrdered > 0 ? (itemsReceived / itemsOrdered * 100) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.business, size: 16, color: Color(0xFF7C3AED)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
                            Text('$orders orders · $itemsOrdered items',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_fmtAmount(spent),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: receivedPct >= 100
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${receivedPct.toStringAsFixed(0)}% recv',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: receivedPct >= 100 ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (receivedPct / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        receivedPct >= 100 ? Colors.green : Colors.orange,
                      ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOP PRODUCTS TAB (with search)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTopProductsTab() {
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
          _sectionTitle('Top Purchased Products'),
          const SizedBox(height: 12),

          // Search Bar
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
                  ? 'No product purchase data available'
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
                      'Products',
                      filtered.length,
                      Icons.shopping_bag_outlined,
                      const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProductStat(
                      'Total Ordered',
                      filtered.fold<int>(0, (sum, item) => sum + _toInt(item['total_ordered'])),
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
                  Expanded(flex: 4, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(child: Text('Ordered', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(child: Text('Recv', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(flex: 2, child: Text('Spent', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(flex: 2, child: Text('Avg Cost', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
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
                  final originalRank = _topProductsData.indexOf(item);
                  final productName = item['product_name']?.toString() ?? 'Unknown';
                  final barcode = item['barcode']?.toString();
                  final ordered = _toInt(item['total_ordered']);
                  final received = _toInt(item['total_received']);
                  final spent = _toDouble(item['total_spent']);
                  final avgCost = _toDouble(item['avg_unit_cost']);
                  final receivePct = ordered > 0 ? (received / ordered * 100) : 0.0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: originalRank < 3 ? const Color(0xFF7C3AED).withOpacity(0.1) : Colors.transparent,
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
                          child: Center(child: Text(ordered.toString(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: receivePct >= 100 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('$received',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: receivePct >= 100 ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ),
                        ),
                        Expanded(flex: 2, child: Text(_fmtAmount(spent), textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
                        Expanded(flex: 2, child: Text(_fmtAmount(avgCost), textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Contribution chart
            if (_productSearchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle('Spend Contribution'),
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

    final totalSpent = _topProductsData.fold<double>(
        0, (sum, item) => sum + _toDouble(item['total_spent']));

    final top5 = _topProductsData.take(5).toList();
    final otherSpent = _topProductsData.skip(5).fold<double>(
        0, (sum, item) => sum + _toDouble(item['total_spent']));

    final List<Widget> bars = [];

    for (int i = 0; i < top5.length; i++) {
      final item = top5[i];
      final productName = item['product_name']?.toString() ?? 'Unknown';
      final spent = _toDouble(item['total_spent']);
      final percentage = totalSpent > 0 ? (spent / totalSpent) * 100 : 0;

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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
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
                valueColor: AlwaysStoppedAnimation<Color>(_getProductBarColor(i)),
              ),
            ),
          ],
        ),
      ));
    }

    if (otherSpent > 0 && _topProductsData.length > 5) {
      final percentage = totalSpent > 0 ? (otherSpent / totalSpent) * 100 : 0;
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)),
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
      Color(0xFF7C3AED),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
    ];
    return colors[index % colors.length];
  }

  Widget _buildProductStat(String label, int value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOP SUPPLIERS TAB (with search)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTopSuppliersTab() {
    final filtered = _topSuppliersData.where((s) {
      if (_supplierSearchQuery.isEmpty) return true;
      final q = _supplierSearchQuery.toLowerCase();
      final name = (s['supplier_name'] ?? '').toString().toLowerCase();
      final contact = (s['contact'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || contact.contains(q) || email.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Top Suppliers by Spend'),
          const SizedBox(height: 12),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEF5)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _supplierSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name, contact or email...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                suffixIcon: _supplierSearchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF9CA3AF)),
                  onPressed: () => setState(() => _supplierSearchQuery = ''),
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
              _supplierSearchQuery.isEmpty
                  ? 'No supplier data available'
                  : 'No suppliers found for "$_supplierSearchQuery"',
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
                    child: _buildSupplierStat(
                      _supplierSearchQuery.isEmpty ? 'Total Suppliers' : 'Results',
                      filtered.length,
                      Icons.people_alt_outlined,
                      const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSupplierStat(
                      'Avg. per Supplier',
                      _fmtAmount(filtered.fold<double>(0, (sum, s) => sum + _toDouble(s['total_spent'])) / filtered.length),
                      Icons.trending_up_rounded,
                      const Color(0xFF10B981),
                      isAmount: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Supplier cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final supplier = filtered[i];
                final originalRank = _topSuppliersData.indexOf(supplier);
                final name = supplier['supplier_name']?.toString() ?? 'Unknown';
                final contact = supplier['contact']?.toString();
                final totalSpent = _toDouble(supplier['total_spent']);
                final orderCount = _toInt(supplier['order_count']);
                final avgOrder = _toDouble(supplier['avg_order_value']);
                final itemsOrdered = _toInt(supplier['items_ordered']);
                final itemsReceived = _toInt(supplier['items_received']);
                final receivedPct = itemsOrdered > 0 ? (itemsReceived / itemsOrdered * 100) : 0.0;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEF5)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showSupplierDetails(supplier),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F0FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _highlightText(name, _supplierSearchQuery,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.receipt_outlined, size: 11, color: Color(0xFF9CA3AF)),
                                          const SizedBox(width: 4),
                                          Text('$orderCount order${orderCount != 1 ? 's' : ''}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: receivedPct >= 100 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('${receivedPct.toStringAsFixed(0)}% recv',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: receivedPct >= 100 ? Colors.green : Colors.orange,
                                                  fontWeight: FontWeight.w600,
                                                )),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_fmtAmount(totalSpent),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                    const SizedBox(height: 2),
                                    Text('Avg: ${_fmtAmount(avgOrder)}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (receivedPct / 100).clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  receivedPct >= 100 ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Distribution chart
            if (_supplierSearchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle('Spend Distribution'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: _buildSupplierDistribution(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierStat(String label, dynamic value, IconData icon, Color color, {bool isAmount = false}) {
    String displayValue = value.toString();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierDistribution() {
    if (_topSuppliersData.isEmpty) return const SizedBox.shrink();

    final totalSpent = _topSuppliersData.fold<double>(
        0, (sum, s) => sum + _toDouble(s['total_spent']));

    final top4 = _topSuppliersData.take(4).toList();
    final otherSpent = _topSuppliersData.skip(4).fold<double>(
        0, (sum, s) => sum + _toDouble(s['total_spent']));

    final List<Widget> items = [];

    for (int i = 0; i < top4.length; i++) {
      final supplier = top4[i];
      final name = supplier['supplier_name']?.toString() ?? 'Unknown';
      final spent = _toDouble(supplier['total_spent']);
      final percentage = totalSpent > 0 ? (spent / totalSpent) * 100 : 0;

      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _getSupplierColor(i), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                name.length > 20 ? '${name.substring(0, 20)}...' : name,
                style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text('${percentage.toStringAsFixed(1)}%', textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getSupplierColor(i))),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 4,
                backgroundColor: _getSupplierColor(i).withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_getSupplierColor(i)),
              ),
            ),
          ],
        ),
      ));
    }

    if (otherSpent > 0 && _topSuppliersData.length > 4) {
      final percentage = totalSpent > 0 ? (otherSpent / totalSpent) * 100 : 0;
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF9CA3AF), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Expanded(flex: 3, child: Text('Others', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
            Expanded(
              flex: 1,
              child: Text('${percentage.toStringAsFixed(1)}%', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF))),
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

  Color _getSupplierColor(int index) {
    const colors = [Color(0xFF7C3AED), Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B)];
    return colors[index % colors.length];
  }

  void _showSupplierDetails(Map<String, dynamic> supplierData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SupplierDetailsSheet(supplierData: supplierData),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PENDING ORDERS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPendingOrdersTab() {
    final totalPending = _pendingOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final totalItemsPending = _pendingOrders.fold(0, (s, o) {
      if (o.items == null) return s;
      return s + o.items!.fold(0, (itemSum, item) => itemSum + item.remainingQuantity);
    });

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
                  'Pending Value',
                  _fmtAmount(totalPending),
                  Icons.pending,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Pending Orders',
                  _pendingOrders.length.toString(),
                  Icons.shopping_cart,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Items Pending',
                  totalItemsPending.toString(),
                  Icons.inventory,
                  const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _sectionTitle('Pending Orders (Ordered / Partial)'),
          const SizedBox(height: 10),

          if (_pendingOrders.isEmpty)
            _buildEmptyState('No pending orders 🎉', Icons.check_circle_outline)
          else ...[
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
                  Expanded(flex: 2, child: Text('PO Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(child: Text('Supplier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(child: Text('Items', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(flex: 2, child: Text('Value', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  Expanded(child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
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
                itemCount: _pendingOrders.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (ctx, i) {
                  final o = _pendingOrders[i];
                  final itemsPending = o.items?.fold(0, (sum, item) => sum + item.remainingQuantity) ?? 0;
                  final statusColor = o.status == 'ordered' ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToOrderDetail(o.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(o.poNumber,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D)))),
                            Expanded(child: Text(o.supplier?.name ?? 'Unknown',
                                style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Expanded(child: Text(_fmt(o.orderDate),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))),
                            Expanded(child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: itemsPending > 0 ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(itemsPending.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: itemsPending > 0 ? Colors.orange : Colors.grey,
                                    )),
                              ),
                            )),
                            Expanded(flex: 2, child: Text(_fmtAmount(o.totalAmount), textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))),
                            Expanded(child: Center(
                              child: _chip(
                                o.statusText,
                                statusColor.withOpacity(0.1),
                                statusColor,
                              ),
                            )),
                          ],
                        ),
                      ),
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

  void _navigateToOrderDetail(int orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderDetailScreen(orderId: orderId),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
  );

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
  );

  Widget _buildEmptyState(String msg, IconData icon) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(color: Color(0xFFF3F0FF), shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(height: 16),
        Text(msg, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
      ],
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFEEEEF5)),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
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
}

// Stub for SharedPreferences
class _FakePrefs {
  String? getString(String key) => null;
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUPPLIER DETAILS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _SupplierDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> supplierData;

  const _SupplierDetailsSheet({required this.supplierData});

  @override
  State<_SupplierDetailsSheet> createState() => _SupplierDetailsSheetState();
}

class _SupplierDetailsSheetState extends State<_SupplierDetailsSheet> {
  List<PurchaseOrderModel> _supplierOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSupplierOrders();
  }

  Future<void> _fetchSupplierOrders() async {
    try {
      final supplierId = widget.supplierData['supplier_id'] as int?;
      if (supplierId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
      await provider.fetchPurchaseOrders(
        supplierId: supplierId,
        refresh: true,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _supplierOrders = List<PurchaseOrderModel>.from(provider.purchaseOrders);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.supplierData['supplier_name']?.toString() ?? 'Unknown Supplier';
    final contact = widget.supplierData['contact']?.toString() ?? 'No contact';
    final email = widget.supplierData['email']?.toString() ?? 'No email';
    final totalSpent = _toDouble(widget.supplierData['total_spent']);
    final orderCount = _toInt(widget.supplierData['order_count']);
    final avgOrder = totalSpent / (orderCount > 0 ? orderCount : 1);
    final itemsOrdered = _toInt(widget.supplierData['items_ordered']);
    final itemsReceived = _toInt(widget.supplierData['items_received']);
    final receivedPct = itemsOrdered > 0 ? (itemsReceived / itemsOrdered * 100) : 0.0;

    final currencyFormat = NumberFormat.currency(symbol: 'Rs ');

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
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(contact, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                      if (email.isNotEmpty && email != 'No email') ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ],
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
                Expanded(child: _buildDetailCard('Total Spent', currencyFormat.format(totalSpent),
                    Icons.payments_outlined, const Color(0xFF7C3AED))),
                const SizedBox(width: 10),
                Expanded(child: _buildDetailCard('Orders', orderCount.toString(),
                    Icons.receipt_long_outlined, const Color(0xFF3B82F6))),
                const SizedBox(width: 10),
                Expanded(child: _buildDetailCard('Avg/Order', currencyFormat.format(avgOrder),
                    Icons.trending_up_rounded, const Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 12),

            // Receiving progress
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: receivedPct >= 100 ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: receivedPct >= 100 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(receivedPct >= 100 ? Icons.check_circle : Icons.pending,
                      color: receivedPct >= 100 ? Colors.green : Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Items Received: $itemsReceived / $itemsOrdered',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D))),
                            const Spacer(),
                            Text('${receivedPct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: receivedPct >= 100 ? Colors.green : Colors.orange,
                                )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (receivedPct / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              receivedPct >= 100 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Recent Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
            const SizedBox(height: 12),

            // Orders list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                  : _supplierOrders.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    const Text('No orders found', style: TextStyle(color: Color(0xFF9CA3AF))),
                  ],
                ),
              )
                  : ListView.builder(
                controller: scrollCtrl,
                itemCount: _supplierOrders.length,
                itemBuilder: (ctx, i) {
                  final order = _supplierOrders[i];
                  final itemsPending = order.items?.fold(0, (sum, item) => sum + item.remainingQuantity) ?? 0;
                  final statusColor = order.status == 'received'
                      ? Colors.green
                      : order.status == 'ordered'
                      ? Colors.blue
                      : order.status == 'partial'
                      ? Colors.orange
                      : order.status == 'cancelled'
                      ? Colors.red
                      : Colors.grey;

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PurchaseOrderDetailScreen(orderId: order.id),
                        ),
                      );
                    },
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
                              order.status == 'received' ? Icons.check_circle :
                              order.status == 'cancelled' ? Icons.cancel :
                              Icons.shopping_cart,
                              size: 16, color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.poNumber,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(DateFormat('dd MMM yyyy').format(order.orderDate),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                if (itemsPending > 0)
                                  Text('$itemsPending items pending',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444))),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(currencyFormat.format(order.totalAmount),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_capitalise(order.statusText),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
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
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
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

  String _capitalise(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}