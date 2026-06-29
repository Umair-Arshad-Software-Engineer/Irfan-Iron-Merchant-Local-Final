// lib/screens/sales/sales_list_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import '../../providers/sale_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/sale_image_provider.dart';        // ← ADD
import '../../models/sale_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../Sales/sale_detail_screen.dart';
import '../providers/lanprovider.dart';
import 'sale_screen.dart';
import 'sale_image_manager.dart';                         // ← ADD

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedStatus;
  String? _selectedType;
  String? _selectedCategory;
  int? _selectedCustomerId;
  DateTimeRange? _selectedDateRange;
  bool _showFilters = false;
  bool _isLoadingMore = false;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  // Responsive breakpoints
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
          MediaQuery.of(context).size.width < 1200;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1200;

  // Compact mode for smaller screens
  bool get _isCompact =>
      _isMobile || MediaQuery.of(context).size.width < 400;

  // List of valid payment methods (exclude credit)
  final List<String> _validPaymentMethods = [
    'cash',
    'online',
    'check',
    'bank',
    'slip'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    if (!saleProvider.isLoading && saleProvider.hasMoreData) {
      setState(() => _isLoadingMore = true);
      await saleProvider.loadMoreSales();
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadInitialData() async {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final customerProvider =
    Provider.of<CustomerProvider>(context, listen: false);

    saleProvider.resetPagination();
    await Future.wait([
      saleProvider.fetchSales(),
      customerProvider.fetchCustomers(),
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
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: _buildAppBar(languageProvider),
          body: Column(
            children: [
              _buildSearchAndFilterBar(languageProvider),
              if (_showFilters) _buildFiltersPanel(languageProvider),
              Expanded(
                child: Consumer<SaleProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.sales.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: LoadingIndicator(),
                      );
                    }

                    if (provider.errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: CustomErrorWidget(
                          message: provider.errorMessage!,
                          onRetry: () => provider.fetchSales(refresh: true),
                        ),
                      );
                    }

                    if (provider.sales.isEmpty) {
                      return _buildEmptyState(languageProvider);
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        final saleProvider = Provider.of<SaleProvider>(
                            context,
                            listen: false);
                        saleProvider.resetPagination();
                        await saleProvider.fetchSales(refresh: true);
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding:
                              EdgeInsets.all(_isCompact ? 4 : 8),
                              itemCount: provider.sales.length + 1,
                              itemBuilder: (context, index) {
                                if (index == provider.sales.length) {
                                  if (provider.isLoading &&
                                      provider.sales.isNotEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Center(
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child:
                                          CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  }
                                  if (!provider.hasMoreData &&
                                      provider.sales.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Center(
                                        child: Text(
                                          languageProvider.isEnglish
                                              ? 'No more records'
                                              : 'مزید ریکارڈز نہیں ہیں',
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }

                                final sale = provider.sales[index];
                                return _buildSaleCard(
                                    sale, languageProvider);
                              },
                            ),
                          ),
                          if (provider.isLoading &&
                              provider.sales.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(
                                child: SizedBox(
                                  height: 30,
                                  width: 30,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
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
          ),
          floatingActionButton: _isMobile
              ? FloatingActionButton(
            onPressed: () => _navigateToCreateSale(),
            backgroundColor: const Color(0xFF7C3AED),
            child:
            const Icon(Icons.add, color: Colors.white, size: 24),
          )
              : FloatingActionButton.extended(
            onPressed: () => _navigateToCreateSale(),
            label: Text(
              languageProvider.isEnglish ? 'New Sale' : 'نئی فروخت',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14),
            ),
            icon: const Icon(Icons.add,
                color: Colors.white, size: 20),
            backgroundColor: const Color(0xFF7C3AED),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(LanguageProvider languageProvider) {
    return AppBar(
      title: Text(
        languageProvider.isEnglish ? 'Sales' : 'فروخت',
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF7C3AED),
      elevation: 0,
      toolbarHeight: _isCompact ? 48 : 56,
    );
  }

  Widget _buildSearchAndFilterBar(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isCompact ? 8 : 16,
        vertical: _isCompact ? 4 : 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Color(0xFFF0F0F5), width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: _isCompact ? 32 : 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: _isCompact ? 12 : 13,
                      fontFamily: languageProvider.fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: _isCompact
                          ? (languageProvider.isEnglish
                          ? 'Search...'
                          : 'تلاش کریں...')
                          : languageProvider.isEnglish
                          ? 'Search by invoice or customer...'
                          : 'انوائس یا کسٹمر سے تلاش کریں...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: _isCompact ? 11 : 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[400],
                        size: _isCompact ? 16 : 18,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear,
                            size: _isCompact ? 14 : 18),
                        onPressed: () =>
                            _searchController.clear(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: _isCompact ? 4 : 8,
                        horizontal: _isCompact ? 6 : 12,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                height: _isCompact ? 32 : 38,
                width: _isCompact ? 32 : 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () =>
                      setState(() => _showFilters = !_showFilters),
                  icon: Icon(
                    Icons.filter_list,
                    color: _showFilters
                        ? const Color(0xFF7C3AED)
                        : Colors.grey[600],
                    size: _isCompact ? 16 : 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range,
                              size: 14,
                              color: const Color(0xFF7C3AED)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}',
                              style: TextStyle(
                                fontSize: _isCompact ? 10 : 12,
                                color: const Color(0xFF7C3AED),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(
                                      () => _selectedDateRange = null);
                              _applyFilters();
                            },
                            child: Icon(Icons.close,
                                size: 14,
                                color: const Color(0xFF7C3AED)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(LanguageProvider languageProvider) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        return Container(
          padding: EdgeInsets.all(_isCompact ? 8 : 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
                bottom:
                BorderSide(color: Color(0xFFF0F0F5), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.isEnglish ? 'Filters' : 'فلٹرز',
                style: TextStyle(
                  fontSize: _isCompact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildFilterChip(
                    label:
                    languageProvider.isEnglish ? 'Type' : 'قسم',
                    value: _selectedType,
                    options: [
                      {
                        'value': null,
                        'label': languageProvider.isEnglish
                            ? 'All'
                            : 'تمام'
                      },
                      {'value': 'pos', 'label': 'POS'},
                      {
                        'value': 'invoice',
                        'label': languageProvider.isEnglish
                            ? 'Invoice'
                            : 'انوائس'
                      },
                    ],
                    onChanged: (value) {
                      setState(() => _selectedType = value);
                      _applyFilters();
                    },
                    languageProvider: languageProvider,
                  ),
                  _buildFilterChip(
                    label: languageProvider.isEnglish
                        ? 'Category'
                        : 'کیٹگری',
                    value: _selectedCategory,
                    options: [
                      {
                        'value': null,
                        'label': languageProvider.isEnglish
                            ? 'All'
                            : 'تمام'
                      },
                      {'value': 'sarya', 'label': 'SARYA'},
                      {
                        'value': 'filled',
                        'label': languageProvider.isEnglish
                            ? 'FILLED'
                            : 'بھری'
                      },
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      _applyFilters();
                    },
                    languageProvider: languageProvider,
                  ),
                  _buildFilterChip(
                    label: languageProvider.isEnglish
                        ? 'Status'
                        : 'حالت',
                    value: _selectedStatus,
                    options: [
                      {
                        'value': null,
                        'label': languageProvider.isEnglish
                            ? 'All'
                            : 'تمام'
                      },
                      {
                        'value': 'paid',
                        'label': languageProvider.isEnglish
                            ? 'Paid'
                            : 'ادا'
                      },
                      {
                        'value': 'partial',
                        'label': languageProvider.isEnglish
                            ? 'Partial'
                            : 'جزوی'
                      },
                      {
                        'value': 'unpaid',
                        'label': languageProvider.isEnglish
                            ? 'Unpaid'
                            : 'غیر ادا'
                      },
                    ],
                    onChanged: (value) {
                      setState(() => _selectedStatus = value);
                      _applyFilters();
                    },
                    languageProvider: languageProvider,
                  ),
                  _buildFilterChip<int?>(
                    label: languageProvider.isEnglish
                        ? 'Customer'
                        : 'کسٹمر',
                    value: _selectedCustomerId,
                    options: [
                      {
                        'value': null,
                        'label': languageProvider.isEnglish
                            ? 'All'
                            : 'تمام'
                      },
                      ...customerProvider.customers.map((c) => ({
                        'value': c.id,
                        'label': c.name,
                      })),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCustomerId = value);
                      _applyFilters();
                    },
                    languageProvider: languageProvider,
                  ),
                  _buildDateFilterChip(languageProvider),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(
                          horizontal: _isCompact ? 8 : 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      languageProvider.isEnglish
                          ? 'Clear All'
                          : 'سب صاف کریں',
                      style: TextStyle(
                        color: const Color(0xFF7C3AED),
                        fontSize: _isCompact ? 11 : 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(
                        horizontal: _isCompact ? 12 : 16,
                        vertical: _isCompact ? 4 : 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      languageProvider.isEnglish
                          ? 'Apply'
                          : 'لاگو کریں',
                      style: TextStyle(
                          fontSize: _isCompact ? 11 : 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> options,
    required void Function(T?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      constraints:
      BoxConstraints(minWidth: _isCompact ? 80 : 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: _isCompact ? 9 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border:
              Border.all(color: const Color(0xFFF0F0F5)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: options.map((option) {
                  return DropdownMenuItem<T>(
                    value: option['value'] as T?,
                    child: Text(
                      option['label'] as String,
                      style: TextStyle(
                          fontSize: _isCompact ? 11 : 13),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
                isExpanded: true,
                hint: Text(
                  label,
                  style: TextStyle(
                    fontSize: _isCompact ? 11 : 13,
                    color: Colors.grey[400],
                  ),
                ),
                icon: Icon(Icons.keyboard_arrow_down,
                    size: _isCompact ? 16 : 20,
                    color: Colors.grey[600]),
                style: TextStyle(
                  fontSize: _isCompact ? 11 : 13,
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(LanguageProvider languageProvider) {
    return Container(
      constraints:
      BoxConstraints(minWidth: _isCompact ? 100 : 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish
                ? 'Date Range'
                : 'تاریخ کی حد',
            style: TextStyle(
              fontSize: _isCompact ? 9 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => _selectDateRange(languageProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border:
                Border.all(color: const Color(0xFFF0F0F5)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: _isCompact ? 12 : 14,
                      color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getDateRangeText(languageProvider),
                      style: TextStyle(
                          fontSize: _isCompact ? 10 : 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedDateRange != null)
                    GestureDetector(
                      onTap: () {
                        setState(
                                () => _selectedDateRange = null);
                        _applyFilters();
                      },
                      child: Icon(Icons.close,
                          size: _isCompact ? 12 : 14,
                          color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodName(
      String method, LanguageProvider languageProvider) {
    switch (method.toLowerCase()) {
      case 'cash':
        return languageProvider.isEnglish ? 'Cash' : 'نقد';
      case 'online':
        return languageProvider.isEnglish ? 'Online' : 'آن لائن';
      case 'check':
        return languageProvider.isEnglish ? 'Cheque' : 'چیک';
      case 'bank':
        return languageProvider.isEnglish ? 'Bank' : 'بینک';
      case 'slip':
        return languageProvider.isEnglish ? 'Slip' : 'پرچی';
      default:
        return method;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'online':
        return Icons.wifi;
      case 'check':
        return Icons.assignment;
      case 'bank':
        return Icons.account_balance;
      case 'slip':
        return Icons.receipt;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'online':
        return Colors.blue;
      case 'check':
        return Colors.orange;
      case 'bank':
        return Colors.purple;
      case 'slip':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLengthsWithQuantities(SaleItemModel item,
      bool isWideScreen, LanguageProvider languageProvider) {
    final lengthsWithQty = item.lengthsWithQuantities;

    if (lengthsWithQty.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: lengthsWithQty.map((lengthData) {
          final length = lengthData['length'] as String;
          final qty = lengthData['qty'] as double;

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
              border:
              Border.all(color: Colors.blue.shade200, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('انچ سوتر شافٹ'),
                    Text(
                      length,
                      style: TextStyle(
                        fontSize: isWideScreen ? 15 : 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${qty.toStringAsFixed(0)}مقدار',
                    style: TextStyle(
                      fontSize: _isCompact ? 12 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<String, double> _getPaymentMethodTotals(SaleModel sale) {
    final Map<String, double> totals = {};
    final allTotals = sale.paymentMethodTotals;
// In _getPaymentMethodTotals(), add at the top temporarily:
    debugPrint('=== Sale ${sale.invoiceNumber} ===');
    debugPrint('paymentMethod: ${sale.paymentMethod}');
    debugPrint('paymentDetails raw: ${sale.paymentDetails}');
    debugPrint('amountPaid: ${sale.amountPaid}');
    debugPrint('paidAmount: ${sale.paidAmount}');
    // Added 'bank' to the valid list
    final validMethods = ['cash', 'online', 'check', 'bank', 'slip'];

    for (var entry in allTotals.entries) {
      final methodKey = entry.key.toLowerCase();
      if (validMethods.contains(methodKey) && entry.value > 0) {
        totals[entry.key] = entry.value;
      }
    }

    // Fallback: if paymentDetails was empty but paymentMethod is set
    if (totals.isEmpty && sale.paymentMethod.isNotEmpty) {
      final method = sale.paymentMethod.toLowerCase();
      if (validMethods.contains(method)) {
        totals[method] = sale.paidAmount ?? sale.amountPaid;
      }
    }

    return totals;
  }

  Widget _buildSaleCard(
      SaleModel sale, LanguageProvider languageProvider) {
    final bool isCredit = sale.paymentMethod == 'credit';
    final bool isOverdue = sale.isOverdue;
    final bool isSarya = sale.saleCategory == 'sarya';
    final screenshotKey = GlobalKey();

    final paymentTotals = _getPaymentMethodTotals(sale);
    final items = sale.items ?? [];

    final double paidAmount =
        sale.paidAmount ?? sale.amountPaid ?? 0.0;
    final double remainingAmount = sale.remainingAmount ??
        (sale.grandTotal - paidAmount);
    final double previousBalance =
        sale.previousBalance ?? sale.previousBalanceValue;
    final double totalWithPrevious =
        sale.grandTotal + previousBalance;
    final double totalBalance = previousBalance + remainingAmount;

    debugPrint(
        'Sale ${sale.invoiceNumber}: previousBalance=${sale.previousBalance}, customerBalance=${sale.customerBalance}');

    return RepaintBoundary(
      key: screenshotKey,
      child: Card(
        margin:
        EdgeInsets.only(bottom: _isCompact ? 8 : 12),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(_isCompact ? 10 : 14),
          side: BorderSide(
            color: isCredit && sale.paymentStatus != 'paid'
                ? const Color(0xFF7C3AED).withOpacity(0.3)
                : const Color(0xFFF0F0F5),
            width:
            isCredit && sale.paymentStatus != 'paid'
                ? 1.5
                : 0.5,
          ),
        ),
        child: Padding(
          padding:
          EdgeInsets.all(_isCompact ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header ──────────────────────────────────
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر'} ${sale.reference}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Center(
                    child: Image.asset(
                      'asset/images/hafizlogo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Text(
                    _dateFormat.format(sale.saleDate),
                    style: TextStyle(
                      fontSize: _isCompact ? 11 : 12,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Image.asset(
                      'asset/images/everysarya.png',
                      height: 60,
                      width: 180,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 30,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('asset/images/name.png'),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                languageProvider.isEnglish
                    ? 'Customer Name: ${sale.customer?.name ?? 'Walk-in Customer'}'
                    : 'کسٹمر کا نام: ${sale.customer?.name ?? 'واک اِن کسٹمر'}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontFamily: languageProvider.fontFamily,
                ),
              ),

              const SizedBox(height: 12),

              // ── Badges ──────────────────────────────────
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBadge(
                    label: isSarya
                        ? 'SARYA'
                        : (languageProvider.isEnglish
                        ? 'FILLED'
                        : 'بھری ہوئی'),
                    color: isSarya
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF10B981),
                    icon: isSarya
                        ? Icons.scale
                        : Icons.production_quantity_limits,
                  ),
                  if (isCredit)
                    _buildBadge(
                      label: languageProvider.isEnglish
                          ? 'CREDIT'
                          : 'کریڈٹ',
                      color: const Color(0xFF7C3AED),
                      icon: Icons.credit_card,
                    ),
                  _buildBadge(
                    label: sale.saleType == 'pos'
                        ? 'POS'
                        : (languageProvider.isEnglish
                        ? 'INVOICE'
                        : 'انوائس'),
                    color: _getTypeColor(sale.saleType),
                    icon: sale.saleType == 'pos'
                        ? Icons.point_of_sale
                        : Icons.receipt_long,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Items ────────────────────────────────────
              if (items.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(
                      _isCompact ? 10 : 14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(
                        _isCompact ? 8 : 10),
                    border:
                    Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${languageProvider.isEnglish ? 'Invoice #' : 'انوائس نمبر'} ${sale.reference}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            // languageProvider.isEnglish
                            //     ? 'Customer Name: ${sale.customer?.name ?? 'Walk-in Customer'}'
                            //     : 'کسٹمر کا نام: ${sale.customer?.name ?? 'واک اِن کسٹمر'}',
                            '${sale.customer?.name}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                              fontFamily:
                              languageProvider.fontFamily,
                            ),
                          ),
                          Text(
                            _dateFormat.format(sale.saleDate),
                            style: TextStyle(
                              fontSize: _isCompact ? 11 : 12,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(
                              bottom: 6),
                          padding: EdgeInsets.all(
                              _isCompact ? 8 : 12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius:
                            BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.productName,
                                      style: TextStyle(
                                        fontWeight:
                                        FontWeight.w600,
                                        fontSize: _isCompact
                                            ? 13
                                            : 15,
                                        color: Colors
                                            .blue.shade800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat
                                        .format(item.totalPrice),
                                    style: TextStyle(
                                      fontWeight:
                                      FontWeight.bold,
                                      fontSize:
                                      _isCompact ? 12 : 14,
                                      color:
                                      Colors.teal.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.description != null &&
                                  item.description!.isNotEmpty)
                                Padding(
                                  padding:
                                  const EdgeInsets.only(
                                      top: 4),
                                  child: Text(
                                    item.description!,
                                    style: TextStyle(
                                      fontSize:
                                      _isCompact ? 11 : 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Rate: ',
                                          style: TextStyle(
                                            color: Colors
                                                .grey.shade700,
                                            fontSize: _isCompact
                                                ? 11
                                                : 13,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _currencyFormat
                                              .format(
                                              item.unitPrice),
                                          style: TextStyle(
                                            color: Colors
                                                .blue.shade700,
                                            fontWeight:
                                            FontWeight.bold,
                                            fontSize: _isCompact
                                                ? 11
                                                : 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Qty: ',
                                          style: TextStyle(
                                            color: Colors
                                                .grey.shade700,
                                            fontSize: _isCompact
                                                ? 11
                                                : 13,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                          '${item.quantity}',
                                          style: TextStyle(
                                            color: Colors
                                                .orange.shade700,
                                            fontWeight:
                                            FontWeight.bold,
                                            fontSize: _isCompact
                                                ? 11
                                                : 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item.weight != null) ...[
                                    const SizedBox(width: 16),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Weight: ',
                                            style: TextStyle(
                                              color: Colors
                                                  .grey.shade700,
                                              fontSize:
                                              _isCompact
                                                  ? 11
                                                  : 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                            '${item.weight!.toStringAsFixed(2)} kg',
                                            style: TextStyle(
                                              color: Colors
                                                  .green.shade700,
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize:
                                              _isCompact
                                                  ? 11
                                                  : 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              _buildLengthsWithQuantities(
                                  item, !_isCompact,
                                  languageProvider),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // ── Payment Methods ──────────────────────────
              if (paymentTotals.isNotEmpty &&
                  paymentTotals.values.any((v) => v > 0))
                Container(
                  padding: EdgeInsets.all(
                      _isCompact ? 10 : 14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(
                        _isCompact ? 8 : 10),
                    border: Border.all(
                        color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.isEnglish
                            ? 'Payment Methods:'
                            : 'ادائیگی کے طریقے:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: _isCompact ? 13 : 15,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...paymentTotals.entries
                          .where((entry) => entry.value > 0)
                          .map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getPaymentMethodIcon(
                                        entry.key),
                                    size:
                                    _isCompact ? 16 : 20,
                                    color:
                                    _getPaymentMethodColor(
                                        entry.key),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getPaymentMethodName(
                                        entry.key,
                                        languageProvider),
                                    style: TextStyle(
                                      fontSize:
                                      _isCompact ? 12 : 14,
                                      fontWeight:
                                      FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _currencyFormat
                                    .format(entry.value),
                                style: TextStyle(
                                  fontSize:
                                  _isCompact ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                  color:
                                  _getPaymentMethodColor(
                                      entry.key),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // ── Summary ──────────────────────────────────
              Container(
                padding:
                EdgeInsets.all(_isCompact ? 10 : 14),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(
                      _isCompact ? 8 : 10),
                  border:
                  Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      label: languageProvider.isEnglish
                          ? 'Grand Total:'
                          : 'مجموعی رقم:',
                      value: _currencyFormat
                          .format(sale.grandTotal),
                      labelColor: Colors.teal.shade800,
                      valueColor: Colors.teal.shade800,
                      labelSize: _isCompact ? 13.0 : 15.0,
                      valueSize: _isCompact ? 14.0 : 17.0,
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    _buildSummaryRow(
                      label: languageProvider.isEnglish
                          ? 'Previous Balance:'
                          : 'سابقہ رقم:',
                      value: _currencyFormat
                          .format(previousBalance),
                      labelColor: previousBalance > 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      valueColor: previousBalance > 0
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      labelSize: _isCompact ? 12.0 : 14.0,
                      valueSize: _isCompact ? 12.0 : 14.0,
                      labelWeight: FontWeight.w500,
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    _buildSummaryRow(
                      label: languageProvider.isEnglish
                          ? 'Total Amount:'
                          : 'ٹوٹل رقم:',
                      value: _currencyFormat
                          .format(totalWithPrevious),
                      labelColor: Colors.purple.shade800,
                      valueColor: Colors.purple.shade800,
                      labelSize: _isCompact ? 13.0 : 15.0,
                      valueSize: _isCompact ? 14.0 : 17.0,
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    _buildSummaryRow(
                      label: languageProvider.isEnglish
                          ? 'Paid Amount:'
                          : 'وصول رقم:',
                      value:
                      _currencyFormat.format(paidAmount),
                      labelColor: Colors.green.shade700,
                      valueColor: Colors.green.shade700,
                      labelSize: _isCompact ? 12.0 : 14.0,
                      valueSize: _isCompact ? 12.0 : 14.0,
                      labelWeight: FontWeight.w500,
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    _buildSummaryRow(
                      label: languageProvider.isEnglish
                          ? 'Total Balance:'
                          : 'کل بیلنس:',
                      value:
                      _currencyFormat.format(totalBalance),
                      labelColor: totalBalance > 0
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                      valueColor: totalBalance > 0
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                      labelSize: _isCompact ? 13.0 : 15.0,
                      valueSize: _isCompact ? 14.0 : 17.0,
                      labelWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),

              if (isOverdue && sale.paymentStatus != 'paid')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color:
                          Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning,
                            size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          '${languageProvider.isEnglish ? 'Due Date' : 'واجب الادا'}: ${_dateFormat.format(sale.dueDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Image Gallery Strip ──────────────────────
              SaleImageGallery(
                saleId: sale.id,
                isCompact: _isCompact,
              ),

              const SizedBox(height: 12),

              // ── Action Buttons ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        _navigateToSaleDetail(sale.id),
                    icon: Icon(Icons.visibility,
                        size: _isCompact ? 18 : 20,
                        color: Colors.blue),
                    label: Text(
                      languageProvider.isEnglish
                          ? 'View'
                          : 'دیکھیں',
                      style: TextStyle(
                        fontSize: _isCompact ? 12 : 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isCompact ? 10 : 14,
                        vertical: _isCompact ? 6 : 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: sale.paymentStatus != 'paid'
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SaleScreen(
                              existingSale: sale),
                        ),
                      ).then((r) {
                        if (r == true)
                          _loadInitialData();
                      });
                    }
                        : null,
                    icon: Icon(
                      Icons.edit,
                      size: _isCompact ? 18 : 20,
                      color: sale.paymentStatus != 'paid'
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    label: Text(
                      languageProvider.isEnglish
                          ? 'Edit'
                          : 'ترمیم',
                      style: TextStyle(
                        fontSize: _isCompact ? 12 : 14,
                        color: sale.paymentStatus != 'paid'
                            ? Colors.orange
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isCompact ? 10 : 14,
                        vertical: _isCompact ? 6 : 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // ── Images Button ──────────────────────── ← ADD
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SaleImageManager(
                            saleId: sale.id,
                            invoiceNumber:
                            sale.invoiceNumber,
                          ),
                        ),
                      ).then((_) {
                        context
                            .read<SaleImageProvider>()
                            .fetchImages(sale.id);
                      });
                    },
                    icon: Icon(Icons.image,
                        size: _isCompact ? 18 : 20,
                        color: Colors.purple),
                    label: Text(
                      languageProvider.isEnglish
                          ? 'Images'
                          : 'تصاویر',
                      style: TextStyle(
                        fontSize: _isCompact ? 12 : 14,
                        color: Colors.purple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isCompact ? 10 : 14,
                        vertical: _isCompact ? 6 : 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () {
                      _captureAndShareSale(
                          screenshotKey,
                          context,
                          languageProvider);
                    },
                    icon: const Icon(Icons.share,
                        size: 18,
                        color: Color(0xFF7C3AED)),
                    label: Text(
                      languageProvider.isEnglish
                          ? 'Share'
                          : 'شیئر',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isCompact ? 10 : 14,
                        vertical: _isCompact ? 6 : 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable summary row ─────────────────────────────────────
  Widget _buildSummaryRow({
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
    required double labelSize,
    required double valueSize,
    FontWeight labelWeight = FontWeight.w600,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: labelSize,
                fontWeight: labelWeight,
                color: labelColor)),
        Text(value,
            style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.bold,
                color: valueColor)),
      ],
    );
  }

  Widget _buildBadge(
      {required String label,
        required Color color,
        IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isCompact ? 4 : 8,
        vertical: _isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: _isCompact ? 10 : 14, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: _isCompact ? 8 : 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined,
              size: _isCompact ? 40 : 60,
              color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            languageProvider.isEnglish
                ? 'No Sales Found'
                : 'کوئی فروخت نہیں ملی',
            style: TextStyle(
              fontSize: _isCompact ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            languageProvider.isEnglish
                ? 'Create your first sale'
                : 'اپنی پہلی فروخت بنائیں',
            style: TextStyle(
              fontSize: _isCompact ? 11 : 13,
              color: Colors.grey[500],
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navigateToCreateSale(),
            icon: Icon(Icons.add, size: _isCompact ? 16 : 20),
            label: Text(
              languageProvider.isEnglish
                  ? 'New Sale'
                  : 'نئی فروخت',
              style:
              TextStyle(fontSize: _isCompact ? 12 : 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: _isCompact ? 12 : 20,
                vertical: _isCompact ? 6 : 10,
              ),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndShareSale(GlobalKey key,
      BuildContext context,
      LanguageProvider languageProvider) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(child: CircularProgressIndicator()),
      );

      await Future.delayed(
          const Duration(milliseconds: 100));

      final renderObject =
      key.currentContext?.findRenderObject();
      if (renderObject == null ||
          renderObject is! RenderRepaintBoundary) {
        throw Exception('Could not find render boundary');
      }

      ui.Image? image;
      for (int i = 0; i < 3; i++) {
        try {
          image = await renderObject.toImage(
              pixelRatio: kIsWeb ? 2.0 : 3.0);
          break;
        } catch (e) {
          if (i == 2) rethrow;
          await Future.delayed(
              const Duration(milliseconds: 100));
        }
      }

      if (image == null) {
        throw Exception(
            'Failed to capture image after multiple attempts');
      }

      final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Could not generate image data');
      }

      final pngBytes = byteData.buffer.asUint8List();

      if (context.mounted) Navigator.of(context).pop();

      if (kIsWeb) {
        await _shareOnWeb(pngBytes, languageProvider);
      } else {
        await _shareOnMobile(pngBytes, languageProvider);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error sharing sale: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareOnWeb(Uint8List pngBytes,
      LanguageProvider languageProvider) async {
    try {
      final fileName =
          'sale_${DateTime.now().millisecondsSinceEpoch}.png';
      final blob = html.Blob([pngBytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Sale downloaded and opened in new tab.'
                : 'فروخت ڈاؤن لوڈ ہو گئی اور نئی ٹیب میں کھل گئی۔'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to share: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareOnMobile(Uint8List pngBytes,
      LanguageProvider languageProvider) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/sale_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: languageProvider.isEnglish
            ? 'Sale Details'
            : 'فروخت کی تفصیلات',
        subject: languageProvider.isEnglish
            ? 'Sale from my app'
            : 'میری ایپ سے فروخت',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to share: ${e.toString()}')),
        );
      }
    }
  }

  Color _getTypeColor(String type) {
    return type == 'pos'
        ? const Color(0xFF7C3AED)
        : const Color(0xFF3B82F6);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDateRangeText(LanguageProvider languageProvider) {
    if (_selectedDateRange != null) {
      return '${_dateFormat.format(_selectedDateRange!.start)} - ${_dateFormat.format(_selectedDateRange!.end)}';
    } else {
      return languageProvider.isEnglish
          ? 'Select date range'
          : 'تاریخ کی حد منتخب کریں';
    }
  }

  Future<void> _selectDateRange(
      LanguageProvider languageProvider) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate:
      DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
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
        _selectedDateRange = picked;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    final provider =
    Provider.of<SaleProvider>(context, listen: false);
    provider.resetPagination();
    provider.fetchSales(
      saleType: _selectedType,
      saleCategory: _selectedCategory,
      paymentStatus: _selectedStatus,
      customerId: _selectedCustomerId,
      fromDate: _selectedDateRange?.start,
      toDate: _selectedDateRange?.end,
      search: _searchController.text,
      refresh: true,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedType = null;
      _selectedCategory = null;
      _selectedCustomerId = null;
      _selectedDateRange = null;
      _searchController.clear();
    });

    final provider =
    Provider.of<SaleProvider>(context, listen: false);
    provider.resetPagination();
    provider.fetchSales(refresh: true);
  }

  void _navigateToSaleDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SaleDetailScreen(saleId: id),
      ),
    ).then((_) {
      _loadInitialData();
    });
  }

  void _navigateToCreateSale() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SaleScreen(),
      ),
    ).then((refresh) {
      if (refresh == true) {
        _loadInitialData();
      }
    });
  }
}