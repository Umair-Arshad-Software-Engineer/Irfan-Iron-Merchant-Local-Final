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

class PurchaseOrdersListScreen extends StatefulWidget {
  const PurchaseOrdersListScreen({super.key});

  @override
  State<PurchaseOrdersListScreen> createState() => _PurchaseOrdersListScreenState();
}

class _PurchaseOrdersListScreenState extends State<PurchaseOrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedStatus;
  int? _selectedSupplierId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showFilters = false;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  // Status options with bilingual labels
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
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
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  Timer? _debounceTimer;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final statusOptions = _getStatusOptions(languageProvider);

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          body: Column(
            children: [
              _buildHeader(languageProvider),
              _buildStatsCards(languageProvider),
              _buildSearchAndFilterBar(languageProvider),
              if (_showFilters) _buildFiltersPanel(languageProvider, statusOptions),
              Expanded(
                child: Consumer<PurchaseOrderProvider>(
                  builder: (context, provider, child) {
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
                      return _buildEmptyState(languageProvider);
                    }

                    return RefreshIndicator(
                      onRefresh: () => provider.fetchPurchaseOrders(refresh: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        itemCount: provider.purchaseOrders.length,
                        itemBuilder: (context, index) {
                          final order = provider.purchaseOrders[index];
                          return _buildOrderCard(order, languageProvider);
                        },
                      ),
                    );
                  },
                ),
              ),
              _buildPagination(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToAddOrder(),
            label: Text(languageProvider.isEnglish ? 'New Purchase Order' : 'نیا پرچیز آرڈر',
                style: const TextStyle(color: Colors.white)),
            icon: const Icon(Icons.add, color: Colors.white),
            backgroundColor: const Color(0xFF7C3AED),
          ),
        );
      },
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Text(
            lp.isEnglish ? 'Purchase Orders' : 'پرچیز آرڈرز',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStatsCards(LanguageProvider lp) {
    return Consumer<PurchaseOrderProvider>(
      builder: (context, provider, child) {
        int draftCount = provider.purchaseOrders.where((po) => po.status == 'draft').length;
        int orderedCount = provider.purchaseOrders.where((po) => po.status == 'ordered').length;
        int receivedCount = provider.purchaseOrders.where((po) => po.status == 'received').length;
        double totalValue = provider.purchaseOrders.fold(0, (sum, po) => sum + po.totalAmount);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              _buildStatCard(lp.isEnglish ? 'Draft' : 'ڈرافٹ', draftCount.toString(),
                  Icons.drafts, Colors.grey, lp),
              const SizedBox(width: 16),
              _buildStatCard(lp.isEnglish ? 'Ordered' : 'آرڈر شدہ', orderedCount.toString(),
                  Icons.shopping_cart, Colors.blue, lp),
              const SizedBox(width: 16),
              _buildStatCard(lp.isEnglish ? 'Received' : 'موصول شدہ', receivedCount.toString(),
                  Icons.check_circle, Colors.green, lp),
              const SizedBox(width: 16),
              _buildStatCard(lp.isEnglish ? 'Total Value' : 'کل قیمت',
                  _currencyFormat.format(totalValue), Icons.attach_money, Colors.purple, lp),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, LanguageProvider lp) {
    return Expanded(
      child: Container(
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontFamily: lp.fontFamily),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                      fontFamily: lp.fontFamily,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  hintText: lp.isEnglish ? 'Search by PO number or supplier...' : 'PO نمبر یا سپلائر سے تلاش کریں...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showFilters ? const Color(0xFF7C3AED) : const Color(0xFFF0F0F5),
                width: 1.5,
              ),
            ),
            child: IconButton(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Icon(
                Icons.filter_list,
                color: _showFilters ? const Color(0xFF7C3AED) : Colors.grey[600],
              ),
              tooltip: lp.isEnglish ? 'Filters' : 'فلٹرز',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(LanguageProvider lp, List<Map<String, String>> statusOptions) {
    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lp.isEnglish ? 'Filters' : 'فلٹرز',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(
                      label: lp.isEnglish ? 'Status' : 'حالت',
                      value: _selectedStatus,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Statuses')),
                        ...statusOptions.map((opt) => DropdownMenuItem(
                          value: opt['value'],
                          child: Text(opt['label']!),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedStatus = value);
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
                        DropdownMenuItem<int?>(value: null, child: Text(lp.isEnglish ? 'All Suppliers' : 'تمام سپلائرز')),
                        ...supplierProvider.suppliers.map((s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedSupplierId = value);
                        _applyFilters();
                      },
                      lp: lp,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDateRange(lp),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFF0F0F5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getDateRangeText(lp),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text(lp.isEnglish ? 'Clear All' : 'سب صاف کریں'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(lp.isEnglish ? 'Apply Filters' : 'فلٹرز لاگو کریں'),
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
          hint: Text(label, style: TextStyle(fontFamily: lp.fontFamily)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          style: TextStyle(fontFamily: lp.fontFamily),
        ),
      ),
    );
  }

  Widget _buildOrderCard(PurchaseOrderModel order, LanguageProvider lp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: order.hasOverReceivedItems
              ? Colors.red.withOpacity(0.4)
              : const Color(0xFFF0F0F5),
          width: order.hasOverReceivedItems ? 1.5 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToOrderDetail(order.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: order.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(order.status),
                        color: order.statusColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                order.poNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: order.statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  order.statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: order.statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: lp.fontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.business, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  order.supplier?.name ?? (lp.isEnglish ? 'Unknown Supplier' : 'نامعلوم سپلائر'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: lp.fontFamily),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        label: lp.isEnglish ? 'Order Date' : 'آرڈر کی تاریخ',
                        value: _dateFormat.format(order.orderDate),
                        color: Colors.blue,
                        lp: lp,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoChip(
                        label: lp.isEnglish ? 'Items' : 'آئٹمز',
                        value: '${order.items?.length ?? 0} ${lp.isEnglish ? 'items' : 'آئٹمز'}',
                        color: Colors.purple,
                        lp: lp,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoChip(
                        label: lp.isEnglish ? 'Total' : 'کل',
                        value: _currencyFormat.format(order.totalAmount),
                        color: Colors.green,
                        lp: lp,
                      ),
                    ),
                  ],
                ),
                if (order.hasOverReceivedItems) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.red.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lp.isEnglish
                                ? 'Over-received: ${_overReceivedCount(order)} item${_overReceivedCount(order) > 1 ? 's exceed' : ' exceeds'} the ordered quantity'
                                : 'زیادہ موصول: ${_overReceivedCount(order)} آئٹم آرڈر کردہ مقدار سے زیادہ ہے',
                            style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
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

  int _overReceivedCount(PurchaseOrderModel order) =>
      order.items?.where((i) => i.isOverReceived).length ?? 0;

  Widget _buildInfoChip({required String label, required String value, required Color color, required LanguageProvider lp}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7), fontFamily: lp.fontFamily),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, fontFamily: lp.fontFamily),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            lp.isEnglish ? 'No Purchase Orders' : 'کوئی پرچیز آرڈر نہیں',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600],
                fontFamily: lp.fontFamily),
          ),
          const SizedBox(height: 8),
          Text(
            lp.isEnglish ? 'Create your first purchase order' : 'اپنا پہلا پرچیز آرڈر بنائیں',
            style: TextStyle(fontSize: 14, color: Colors.grey[500], fontFamily: lp.fontFamily),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddOrder(),
            icon: const Icon(Icons.add),
            label: Text(lp.isEnglish ? 'New Purchase Order' : 'نیا پرچیز آرڈر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Consumer<PurchaseOrderProvider>(
      builder: (context, provider, child) {
        if (provider.totalPages <= 1) return const SizedBox.shrink();

        return Consumer<LanguageProvider>(
          builder: (context, lp, _) {
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
                    color: provider.currentPage > 1 ? const Color(0xFF7C3AED) : Colors.grey,
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
      },
    );
  }

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
      return '${_dateFormat.format(_fromDate!)} - ${_dateFormat.format(_toDate!)}';
    } else if (_fromDate != null) {
      return lp.isEnglish
          ? 'From ${_dateFormat.format(_fromDate!)}'
          : 'سے ${_dateFormat.format(_fromDate!)}';
    } else if (_toDate != null) {
      return lp.isEnglish
          ? 'To ${_dateFormat.format(_toDate!)}'
          : 'تک ${_dateFormat.format(_toDate!)}';
    } else {
      return lp.isEnglish ? 'Select date range' : 'تاریخ کی حد منتخب کریں';
    }
  }

  Future<void> _selectDateRange(LanguageProvider lp) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7C3AED),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  void _applyFilters() {
    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    provider.fetchPurchaseOrders(
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

    final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    provider.fetchPurchaseOrders(refresh: true);
  }

  void _navigateToOrderDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderDetailScreen(orderId: id),
      ),
    );
  }

  void _navigateToAddOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditPurchaseOrderScreen(),
      ),
    ).then((refresh) {
      if (refresh == true) {
        _loadInitialData();
      }
    });
  }
}