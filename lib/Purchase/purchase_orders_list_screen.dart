// lib/screens/purchases/purchase_orders_list_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:irfan_iron_merchant_local/Purchase/purchase_order_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/purchase_order_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../providers/lanprovider.dart';
import 'add_edit_purchase_order_screen.dart';

// ─── Breakpoints ───────────────────────────────────────────────
// mobile  : width < 600
// tablet  : 600 ≤ width < 1100
// desktop : width ≥ 1100

class PurchaseOrdersListScreen extends StatefulWidget {
  const PurchaseOrdersListScreen({super.key});

  @override
  State<PurchaseOrdersListScreen> createState() => _PurchaseOrdersListScreenState();
}

class _PurchaseOrdersListScreenState extends State<PurchaseOrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  String? _selectedStatus;
  int? _selectedSupplierId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showFilters = false;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  List<Map<String, String>> _getStatusOptions(LanguageProvider lp) => [
    {'value': 'draft', 'label': lp.isEnglish ? 'Draft' : 'ڈرافٹ'},
    {'value': 'ordered', 'label': lp.isEnglish ? 'Ordered' : 'آرڈر شدہ'},
    {'value': 'partial', 'label': lp.isEnglish ? 'Partial' : 'جزوی'},
    {'value': 'received', 'label': lp.isEnglish ? 'Received' : 'موصول شدہ'},
    {'value': 'cancelled', 'label': lp.isEnglish ? 'Cancelled' : 'منسوخ شدہ'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final poProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
    await Future.wait([
      poProvider.fetchPurchaseOrders(),
      supplierProvider.fetchSuppliers(context: context),
    ]);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), _applyFilters);
  }

  // ── Helpers ────────────────────────────────────────────────────

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;
  bool _isTablet(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    return w >= 600 && w < 1100;
  }
  bool _isDesktop(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 1100;

  double _horizontalPadding(BuildContext ctx) {
    if (_isDesktop(ctx)) return 40;
    if (_isTablet(ctx)) return 28;
    return 16;
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lp, _) {
        final statusOptions = _getStatusOptions(lp);
        final isMobile = _isMobile(context);
        final isDesktop = _isDesktop(context);
        final hp = _horizontalPadding(context);

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          // Desktop/tablet: no FAB — action lives in header
          floatingActionButton: isMobile
              ? FloatingActionButton.extended(
            onPressed: _navigateToAddOrder,
            label: Text(
              lp.isEnglish ? 'New Order' : 'نیا آرڈر',
              style: const TextStyle(color: Colors.white),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            backgroundColor: const Color(0xFF7C3AED),
          )
              : null,
          body: Column(
            children: [
              _buildHeader(lp, hp),
              // Desktop: stats inline in a row; mobile/tablet: scrollable row
              _buildStatsCards(lp, hp),
              _buildSearchAndFilterBar(lp, hp),
              if (_showFilters) _buildFiltersPanel(lp, statusOptions, hp),
              Expanded(
                child: Consumer<PurchaseOrderProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading && provider.purchaseOrders.isEmpty) {
                      return const LoadingIndicator();
                    }
                    if (provider.errorMessage != null) {
                      return CustomErrorWidget(
                        message: provider.errorMessage!,
                        onRetry: () => provider.fetchPurchaseOrders(refresh: true),
                      );
                    }
                    if (provider.purchaseOrders.isEmpty) {
                      return _buildEmptyState(lp);
                    }

                    // Desktop: two-column grid; tablet: single column wider; mobile: single column tight
                    return RefreshIndicator(
                      onRefresh: () => provider.fetchPurchaseOrders(refresh: true),
                      child: isDesktop
                          ? _buildDesktopGrid(provider, lp, hp)
                          : _buildMobileList(provider, lp, hp),
                    );
                  },
                ),
              ),
              _buildPagination(lp),
            ],
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────

  Widget _buildHeader(LanguageProvider lp, double hp) {
    final isMobile = _isMobile(context);
    return Container(
      padding: EdgeInsets.fromLTRB(hp, isMobile ? 14 : 20, hp, isMobile ? 8 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5), width: 1)),
      ),
      child: Row(
        children: [
          Text(
            lp.isEnglish ? 'Purchase Orders' : 'پرچیز آرڈرز',
            style: TextStyle(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3142),
            ),
          ),
          const Spacer(),
          // Desktop/tablet: CTA button in header
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: _navigateToAddOrder,
              icon: const Icon(Icons.add, size: 18),
              label: Text(lp.isEnglish ? 'New Purchase Order' : 'نیا پرچیز آرڈر'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Stats Cards ────────────────────────────────────────────────

  Widget _buildStatsCards(LanguageProvider lp, double hp) {
    return Consumer<PurchaseOrderProvider>(
      builder: (context, provider, _) {
        final draftCount = provider.purchaseOrders.where((po) => po.status == 'draft').length;
        final orderedCount = provider.purchaseOrders.where((po) => po.status == 'ordered').length;
        final receivedCount = provider.purchaseOrders.where((po) => po.status == 'received').length;
        final totalValue = provider.purchaseOrders.fold<double>(0, (s, po) => s + po.totalAmount);

        final stats = [
          _StatData(lp.isEnglish ? 'Draft' : 'ڈرافٹ', draftCount.toString(),
              Icons.drafts, Colors.grey),
          _StatData(lp.isEnglish ? 'Ordered' : 'آرڈر شدہ', orderedCount.toString(),
              Icons.shopping_cart, Colors.blue),
          _StatData(lp.isEnglish ? 'Received' : 'موصول شدہ', receivedCount.toString(),
              Icons.check_circle, Colors.green),
          _StatData(lp.isEnglish ? 'Total Value' : 'کل قیمت',
              _currencyFormat.format(totalValue), Icons.attach_money, Colors.purple),
        ];

        final isMobile = _isMobile(context);
        final isDesktop = _isDesktop(context);

        // Mobile: horizontal scroll; tablet/desktop: fixed row
        if (isMobile) {
          return SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: hp, vertical: 10),
              itemCount: stats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _buildStatCardCompact(stats[i], lp),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(hp, 16, hp, 0),
          child: Row(
            children: stats
                .map((s) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: s != stats.last ? (isDesktop ? 16 : 12) : 0),
                child: _buildStatCardFull(s, lp),
              ),
            ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatCardFull(_StatData s, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, color: s.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        fontFamily: lp.fontFamily)),
                const SizedBox(height: 4),
                Text(s.value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3142),
                        fontFamily: lp.fontFamily),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardCompact(_StatData s, LanguageProvider lp) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(s.icon, color: s.color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF6B7280),
                        fontFamily: lp.fontFamily),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(s.value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3142),
                        fontFamily: lp.fontFamily),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search + Filter bar ────────────────────────────────────────

  Widget _buildSearchAndFilterBar(LanguageProvider lp, double hp) {
    final isMobile = _isMobile(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hp, vertical: isMobile ? 10 : 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontFamily: lp.fontFamily, fontSize: 13),
                decoration: InputDecoration(
                  hintText: lp.isEnglish
                      ? 'Search by PO number or supplier...'
                      : 'PO نمبر یا سپلائر سے تلاش کریں...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter button
          _buildIconBtn(
            icon: Icons.filter_list,
            active: _showFilters,
            tooltip: lp.isEnglish ? 'Filters' : 'فلٹرز',
            onTap: () => setState(() => _showFilters = !_showFilters),
          ),
          const SizedBox(width: 8),
          // Refresh button (desktop convenience)
          if (!isMobile) ...[
            _buildIconBtn(
              icon: Icons.refresh,
              active: false,
              tooltip: lp.isEnglish ? 'Refresh' : 'ریفریش',
              onTap: () {
                Provider.of<PurchaseOrderProvider>(context, listen: false)
                    .fetchPurchaseOrders(refresh: true);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? const Color(0xFF7C3AED) : const Color(0xFFF0F0F5),
          width: 1.5,
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon,
            color: active ? const Color(0xFF7C3AED) : Colors.grey[600], size: 20),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ── Filters Panel ──────────────────────────────────────────────

  Widget _buildFiltersPanel(
      LanguageProvider lp, List<Map<String, String>> statusOptions, double hp) {
    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, _) {
        final isMobile = _isMobile(context);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.fromLTRB(hp, 0, hp, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(lp.isEnglish ? 'Filters' : 'فلٹرز',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3142))),
                ],
              ),
              const SizedBox(height: 14),
              // Status + Supplier — stack on mobile, row on tablet+
              if (isMobile) ...[
                _buildFilterDropdown<String?>(
                  label: lp.isEnglish ? 'Status' : 'حالت',
                  value: _selectedStatus,
                  items: [
                    DropdownMenuItem(
                        value: null,
                        child: Text(lp.isEnglish ? 'All Statuses' : 'تمام حالات')),
                    ...statusOptions.map((opt) =>
                        DropdownMenuItem(value: opt['value'], child: Text(opt['label']!))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedStatus = v);
                    _applyFilters();
                  },
                  lp: lp,
                ),
                const SizedBox(height: 10),
                _buildFilterDropdown<int?>(
                  label: lp.isEnglish ? 'Supplier' : 'سپلائر',
                  value: _selectedSupplierId,
                  items: [
                    DropdownMenuItem<int?>(
                        value: null,
                        child: Text(lp.isEnglish ? 'All Suppliers' : 'تمام سپلائرز')),
                    ...supplierProvider.suppliers.map((s) =>
                        DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedSupplierId = v);
                    _applyFilters();
                  },
                  lp: lp,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown<String?>(
                        label: lp.isEnglish ? 'Status' : 'حالت',
                        value: _selectedStatus,
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child:
                              Text(lp.isEnglish ? 'All Statuses' : 'تمام حالات')),
                          ...statusOptions.map((opt) => DropdownMenuItem(
                              value: opt['value'], child: Text(opt['label']!))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedStatus = v);
                          _applyFilters();
                        },
                        lp: lp,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown<int?>(
                        label: lp.isEnglish ? 'Supplier' : 'سپلائر',
                        value: _selectedSupplierId,
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                  lp.isEnglish ? 'All Suppliers' : 'تمام سپلائرز')),
                          ...supplierProvider.suppliers.map((s) =>
                              DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedSupplierId = v);
                          _applyFilters();
                        },
                        lp: lp,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              // Date range
              InkWell(
                onTap: () => _selectDateRange(lp),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 15, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_getDateRangeText(lp),
                            style: TextStyle(
                                fontSize: 13,
                                fontFamily: lp.fontFamily,
                                color: _fromDate != null
                                    ? const Color(0xFF2D3142)
                                    : Colors.grey[500])),
                      ),
                      if (_fromDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _fromDate = null;
                              _toDate = null;
                            });
                            _applyFilters();
                          },
                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                        )
                      else
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text(lp.isEnglish ? 'Clear All' : 'سب صاف کریں',
                        style: const TextStyle(color: Color(0xFF7C3AED))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(lp.isEnglish ? 'Apply' : 'لاگو کریں'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required LanguageProvider lp,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Text(label, style: TextStyle(fontFamily: lp.fontFamily, fontSize: 13)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          style: TextStyle(
              fontFamily: lp.fontFamily,
              fontSize: 13,
              color: const Color(0xFF2D3142)),
        ),
      ),
    );
  }

  // ── Desktop Grid ───────────────────────────────────────────────

  Widget _buildDesktopGrid(
      PurchaseOrderProvider provider, LanguageProvider lp, double hp) {
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(hp, 12, hp, 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 560,
        mainAxisSpacing: 14,
        crossAxisSpacing: 16,
        mainAxisExtent: 200, // fixed card height — adjust if needed
      ),
      itemCount: provider.purchaseOrders.length,
      itemBuilder: (_, i) =>
          _buildOrderCard(provider.purchaseOrders[i], lp, compact: false),
    );
  }

  // ── Mobile / Tablet List ───────────────────────────────────────

  Widget _buildMobileList(
      PurchaseOrderProvider provider, LanguageProvider lp, double hp) {
    final isMobile = _isMobile(context);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(hp, 8, hp, isMobile ? 88 : 20),
      itemCount: provider.purchaseOrders.length,
      itemBuilder: (_, i) =>
          _buildOrderCard(provider.purchaseOrders[i], lp, compact: isMobile),
    );
  }

  // ── Order Card ─────────────────────────────────────────────────

  Widget _buildOrderCard(PurchaseOrderModel order, LanguageProvider lp,
      {bool compact = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 10 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: order.hasOverReceivedItems
              ? Colors.red.withOpacity(0.4)
              : const Color(0xFFF0F0F5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToOrderDetail(order.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + PO number + status badge + date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 40 : 46,
                      height: compact ? 40 : 46,
                      decoration: BoxDecoration(
                        color: order.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getStatusIcon(order.status),
                          color: order.statusColor, size: compact ? 22 : 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  order.poNumber,
                                  style: TextStyle(
                                    fontSize: compact ? 13 : 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2D3142),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildStatusBadge(order),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.business, size: 11, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  order.supplier?.name ??
                                      (lp.isEnglish
                                          ? 'Unknown Supplier'
                                          : 'نامعلوم سپلائر'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: lp.fontFamily),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Date — shown on right on desktop/tablet
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Text(
                        _dateFormat.format(order.orderDate),
                        style:
                        TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF5F5F8)),
                const SizedBox(height: 10),

                // Info chips row
                Row(
                  children: [
                    if (compact)
                      Expanded(
                          child: _buildInfoChip(
                              label: lp.isEnglish ? 'Date' : 'تاریخ',
                              value: _dateFormat.format(order.orderDate),
                              color: Colors.blue,
                              lp: lp)),
                    if (compact) const SizedBox(width: 6),
                    Expanded(
                        child: _buildInfoChip(
                            label: lp.isEnglish ? 'Items' : 'آئٹمز',
                            value:
                            '${order.items?.length ?? 0} ${lp.isEnglish ? 'items' : 'آئٹمز'}',
                            color: Colors.purple,
                            lp: lp)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _buildInfoChip(
                            label: lp.isEnglish ? 'Total' : 'کل',
                            value: _currencyFormat.format(order.totalAmount),
                            color: Colors.green,
                            lp: lp)),
                  ],
                ),

                // Over-received warning
                if (order.hasOverReceivedItems) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lp.isEnglish
                                ? 'Over-received: ${_overReceivedCount(order)} item${_overReceivedCount(order) > 1 ? 's exceed' : ' exceeds'} the ordered quantity'
                                : 'زیادہ موصول: ${_overReceivedCount(order)} آئٹم آرڈر کردہ مقدار سے زیادہ ہے',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PurchaseOrderModel order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: order.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        order.statusText,
        style: TextStyle(
          fontSize: 10,
          color: order.statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required Color color,
    required LanguageProvider lp,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.7),
                  fontFamily: lp.fontFamily)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontFamily: lp.fontFamily),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────

  Widget _buildEmptyState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0FF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined,
                size: 56, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            lp.isEnglish ? 'No Purchase Orders' : 'کوئی پرچیز آرڈر نہیں',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontFamily: lp.fontFamily),
          ),
          const SizedBox(height: 8),
          Text(
            lp.isEnglish
                ? 'Create your first purchase order to get started'
                : 'شروع کرنے کے لیے اپنا پہلا پرچیز آرڈر بنائیں',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: lp.fontFamily),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _navigateToAddOrder,
            icon: const Icon(Icons.add),
            label: Text(lp.isEnglish ? 'New Purchase Order' : 'نیا پرچیز آرڈر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pagination ─────────────────────────────────────────────────

  Widget _buildPagination(LanguageProvider lp) {
    return Consumer<PurchaseOrderProvider>(
      builder: (context, provider, _) {
        if (provider.totalPages <= 1) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F0F5), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: provider.currentPage > 1
                    ? () => provider.setPage(provider.currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                color: provider.currentPage > 1
                    ? const Color(0xFF7C3AED)
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                lp.isEnglish
                    ? 'Page ${provider.currentPage} of ${provider.totalPages}'
                    : 'صفحہ ${provider.currentPage} / ${provider.totalPages}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: provider.currentPage < provider.totalPages
                    ? () => provider.setPage(provider.currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: provider.currentPage < provider.totalPages
                    ? const Color(0xFF7C3AED)
                    : Colors.grey,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Utilities ──────────────────────────────────────────────────

  int _overReceivedCount(PurchaseOrderModel order) =>
      order.items?.where((i) => i.isOverReceived).length ?? 0;

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return Icons.drafts;
      case 'ordered':
        return Icons.shopping_cart;
      case 'partial':
        return Icons.star_half;
      case 'received':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getDateRangeText(LanguageProvider lp) {
    if (_fromDate != null && _toDate != null) {
      return '${_dateFormat.format(_fromDate!)} – ${_dateFormat.format(_toDate!)}';
    } else if (_fromDate != null) {
      return lp.isEnglish
          ? 'From ${_dateFormat.format(_fromDate!)}'
          : 'سے ${_dateFormat.format(_fromDate!)}';
    } else if (_toDate != null) {
      return lp.isEnglish
          ? 'To ${_dateFormat.format(_toDate!)}'
          : 'تک ${_dateFormat.format(_toDate!)}';
    }
    return lp.isEnglish ? 'Select date range' : 'تاریخ کی حد منتخب کریں';
  }

  Future<void> _selectDateRange(LanguageProvider lp) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    Provider.of<PurchaseOrderProvider>(context, listen: false).fetchPurchaseOrders(
      status: _selectedStatus,
      supplierId: _selectedSupplierId,
      fromDate: _fromDate,
      toDate: _toDate,
      search: _searchController.text,
      refresh: true,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedSupplierId = null;
      _fromDate = null;
      _toDate = null;
      _searchController.clear();
    });
    Provider.of<PurchaseOrderProvider>(context, listen: false)
        .fetchPurchaseOrders(refresh: true);
  }

  void _navigateToOrderDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(orderId: id)),
    );
  }

  void _navigateToAddOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditPurchaseOrderScreen()),
    ).then((refresh) {
      if (refresh == true) _loadInitialData();
    });
  }
}

// ── Internal data holder ───────────────────────────────────────

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatData(this.title, this.value, this.icon, this.color);
}