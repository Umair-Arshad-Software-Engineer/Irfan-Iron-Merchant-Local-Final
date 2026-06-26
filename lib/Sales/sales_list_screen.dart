// lib/screens/sales/sales_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/sale_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/sale_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../Sales/sale_detail_screen.dart';
import '../providers/lanprovider.dart';
import 'sale_screen.dart';

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
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showFilters = false;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  // Responsive breakpoints
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1200;

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
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

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
          body: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(languageProvider),
                _buildStatsCards(languageProvider),
                _buildSearchAndFilterBar(languageProvider),
                if (_showFilters) _buildFiltersPanel(languageProvider),
                Consumer<SaleProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.sales.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: LoadingIndicator(),
                      );
                    }

                    if (provider.errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.all(40.0),
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
                      onRefresh: () => provider.fetchSales(refresh: true),
                      child: _isMobile
                          ? ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: provider.sales.length,
                        itemBuilder: (context, index) {
                          final sale = provider.sales[index];
                          return _buildMobileSaleCard(sale, languageProvider);
                        },
                      )
                          : ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        itemCount: provider.sales.length,
                        itemBuilder: (context, index) {
                          final sale = provider.sales[index];
                          return _buildSaleCard(sale, languageProvider);
                        },
                      ),
                    );
                  },
                ),
                _buildPagination(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          floatingActionButton: _isMobile
              ? FloatingActionButton(
            onPressed: () => _navigateToCreateSale(),
            backgroundColor: const Color(0xFF7C3AED),
            child: const Icon(Icons.add, color: Colors.white),
          )
              : FloatingActionButton.extended(
            onPressed: () => _navigateToCreateSale(),
            label: Text(
              languageProvider.isEnglish ? 'New Sale' : 'نئی فروخت',
              style: const TextStyle(color: Colors.white),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            backgroundColor: const Color(0xFF7C3AED),
          ),
        );
      },
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 16 : 24,
        vertical: _isMobile ? 12 : 16,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.isEnglish ? 'Sales' : 'فروخت',
                style: TextStyle(
                  fontSize: _isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3142),
                ),
              ),
              if (!_isMobile)
                Text(
                  languageProvider.isEnglish
                      ? 'Manage your sales and invoices'
                      : 'اپنی فروخت اور انوائسز کا انتظام کریں',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (_isMobile)
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                  icon: Icon(
                    Icons.filter_list,
                    color: _showFilters ? const Color(0xFF7C3AED) : Colors.grey[600],
                    size: 22,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(LanguageProvider languageProvider) {
    return Consumer<SaleProvider>(
      builder: (context, provider, child) {
        int posCount = provider.sales.where((s) => s.saleType == 'pos').length;
        int invoiceCount = provider.sales.where((s) => s.saleType == 'invoice').length;
        int saryaCount = provider.sales.where((s) => s.saleCategory == 'sarya').length;
        int filledCount = provider.sales.where((s) => s.saleCategory == 'filled').length;
        int paidCount = provider.sales.where((s) => s.paymentStatus == 'paid').length;
        int creditCount = provider.sales.where((s) => s.paymentMethod == 'credit').length;

        double totalRevenue = provider.sales.fold(0, (sum, s) => sum + s.grandTotal);
        double totalPending = provider.sales
            .where((s) => s.paymentStatus != 'paid')
            .fold(0, (sum, s) => sum + (s.grandTotal - s.amountPaid));

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 12 : 24,
            vertical: _isMobile ? 8 : 16,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _isMobile
                  ? [
                _buildStatCard(
                  'POS',
                  posCount.toString(),
                  Icons.point_of_sale,
                  Colors.purple,
                  languageProvider,
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Inv' : 'انوائسز',
                  invoiceCount.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                  languageProvider,
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  'SARYA',
                  saryaCount.toString(),
                  Icons.scale,
                  const Color(0xFF3B82F6),
                  languageProvider,
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  languageProvider.isEnglish ? 'FILL' : 'بھری',
                  filledCount.toString(),
                  Icons.production_quantity_limits,
                  const Color(0xFF10B981),
                  languageProvider,
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Paid' : 'ادا',
                  paidCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                  languageProvider,
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Credit' : 'کریڈٹ',
                  creditCount.toString(),
                  Icons.credit_card,
                  const Color(0xFF7C3AED),
                  languageProvider,
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Pending' : 'زیر',
                  'Rs ${_currencyFormat.format(totalPending)}',
                  Icons.pending,
                  Colors.orange,
                  languageProvider,
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Revenue' : 'آمدنی',
                  'Rs ${_currencyFormat.format(totalRevenue)}',
                  Icons.attach_money,
                  Colors.teal,
                  languageProvider,
                  isCompact: true,
                ),
              ]
                  : [
                _buildStatCard(
                  languageProvider.isEnglish ? 'POS Sales' : 'POS فروخت',
                  posCount.toString(),
                  Icons.point_of_sale,
                  Colors.purple,
                  languageProvider,
                  isCompact: false,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Invoices' : 'انوائسز',
                  invoiceCount.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                  languageProvider,
                  isCompact: false,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'SARYA',
                  saryaCount.toString(),
                  Icons.scale,
                  const Color(0xFF3B82F6),
                  languageProvider,
                  isCompact: false,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'FILLED' : 'بھری ہوئی',
                  filledCount.toString(),
                  Icons.production_quantity_limits,
                  const Color(0xFF10B981),
                  languageProvider,
                  isCompact: false,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Paid' : 'ادا شدہ',
                  paidCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                  languageProvider,
                  isCompact: false,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Credit' : 'کریڈٹ',
                  creditCount.toString(),
                  Icons.credit_card,
                  const Color(0xFF7C3AED),
                  languageProvider,
                  isCompact: false,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Pending' : 'زیر التواء',
                  'Rs ${_currencyFormat.format(totalPending)}',
                  Icons.pending,
                  Colors.orange,
                  languageProvider,
                  isCompact: false,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Revenue' : 'آمدنی',
                  'Rs ${_currencyFormat.format(totalRevenue)}',
                  Icons.attach_money,
                  Colors.teal,
                  languageProvider,
                  isCompact: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      LanguageProvider languageProvider, {
        required bool isCompact,
      }) {
    return Container(
      width: isCompact ? 90 : 200,
      padding: EdgeInsets.all(isCompact ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 6 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isCompact ? 6 : 10),
            ),
            child: Icon(icon, color: color, size: isCompact ? 14 : 20),
          ),
          SizedBox(width: isCompact ? 6 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 8 : 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3142),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 24,
        vertical: _isMobile ? 8 : 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: _isMobile ? 38 : 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: _isMobile ? 13 : 14,
                  fontFamily: languageProvider.fontFamily,
                ),
                decoration: InputDecoration(
                  hintText: _isMobile
                      ? (languageProvider.isEnglish ? 'Search...' : 'تلاش کریں...')
                      : languageProvider.isEnglish
                      ? 'Search by invoice number or customer...'
                      : 'انوائس نمبر یا کسٹمر سے تلاش کریں...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: _isMobile ? 12 : 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                    size: _isMobile ? 18 : 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: _isMobile ? 8 : 12,
                    horizontal: _isMobile ? 8 : 12,
                  ),
                ),
              ),
            ),
          ),
          if (!_isMobile) ...[
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
                tooltip: languageProvider.isEnglish ? 'Filters' : 'فلٹرز',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(LanguageProvider languageProvider) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile ? 12 : 24,
            vertical: _isMobile ? 6 : 8,
          ),
          padding: EdgeInsets.all(_isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.isEnglish ? 'Filters' : 'فلٹرز',
                style: TextStyle(
                  fontSize: _isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: _isMobile ? 12 : 16),
              if (_isMobile)
                Column(
                  children: [
                    _buildFilterDropdown(
                      label: languageProvider.isEnglish ? 'Type' : 'قسم',
                      value: _selectedType,
                      items: [
                        DropdownMenuItem(value: null, child: Text(languageProvider.isEnglish ? 'All' : 'تمام')),
                        DropdownMenuItem(value: 'pos', child: Text(languageProvider.isEnglish ? 'POS' : 'POS')),
                        DropdownMenuItem(value: 'invoice', child: Text(languageProvider.isEnglish ? 'Invoice' : 'انوائس')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedType = value);
                        _applyFilters();
                      },
                      languageProvider: languageProvider,
                      isCompact: true,
                    ),
                    const SizedBox(height: 8),
                    _buildFilterDropdown(
                      label: languageProvider.isEnglish ? 'Category' : 'کیٹگری',
                      value: _selectedCategory,
                      items: [
                        DropdownMenuItem(value: null, child: Text(languageProvider.isEnglish ? 'All' : 'تمام')),
                        DropdownMenuItem(value: 'sarya', child: Text('SARYA')),
                        DropdownMenuItem(value: 'filled', child: Text(languageProvider.isEnglish ? 'FILLED' : 'بھری')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                        _applyFilters();
                      },
                      languageProvider: languageProvider,
                      isCompact: true,
                    ),
                    const SizedBox(height: 8),
                    _buildFilterDropdown(
                      label: languageProvider.isEnglish ? 'Status' : 'حالت',
                      value: _selectedStatus,
                      items: [
                        DropdownMenuItem(value: null, child: Text(languageProvider.isEnglish ? 'All' : 'تمام')),
                        DropdownMenuItem(value: 'paid', child: Text(languageProvider.isEnglish ? 'Paid' : 'ادا')),
                        DropdownMenuItem(value: 'partial', child: Text(languageProvider.isEnglish ? 'Partial' : 'جزوی')),
                        DropdownMenuItem(value: 'unpaid', child: Text(languageProvider.isEnglish ? 'Unpaid' : 'غیر ادا')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedStatus = value);
                        _applyFilters();
                      },
                      languageProvider: languageProvider,
                      isCompact: true,
                    ),
                    const SizedBox(height: 8),
                    _buildFilterDropdown<int?>(
                      label: languageProvider.isEnglish ? 'Customer' : 'کسٹمر',
                      value: _selectedCustomerId,
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text(languageProvider.isEnglish ? 'All' : 'تمام')),
                        ...customerProvider.customers.map((c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCustomerId = value);
                        _applyFilters();
                      },
                      languageProvider: languageProvider,
                      isCompact: true,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDateRange(languageProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFF0F0F5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getDateRangeText(languageProvider),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _clearFilters,
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            languageProvider.isEnglish ? 'Clear' : 'صاف کریں',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(languageProvider.isEnglish ? 'Apply' : 'لاگو کریں'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            label: languageProvider.isEnglish ? 'Sale Type' : 'فروخت کی قسم',
                            value: _selectedType,
                            items: [
                              DropdownMenuItem(value: null, child: Text(languageProvider.isEnglish ? 'All Types' : 'تمام اقسام')),
                              DropdownMenuItem(value: 'pos', child: Text(languageProvider.isEnglish ? 'POS Counter' : 'POS کاؤنٹر')),
                              DropdownMenuItem(value: 'invoice', child: Text(languageProvider.isEnglish ? 'Invoice' : 'انوائس')),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedType = value);
                              _applyFilters();
                            },
                            languageProvider: languageProvider,
                            isCompact: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFilterDropdown(
                            label: languageProvider.isEnglish ? 'Sale Category' : 'فروخت کی کیٹگری',
                            value: _selectedCategory,
                            items: [
                              DropdownMenuItem(value: null, child: Text(languageProvider.isEnglish ? 'All Categories' : 'تمام کیٹگریز')),
                              DropdownMenuItem(value: 'sarya', child: Text(languageProvider.isEnglish ? 'SARYA (Weight)' : 'ساریا (وزن)')),
                              DropdownMenuItem(value: 'filled', child: Text(languageProvider.isEnglish ? 'FILLED (Pieces)' : 'بھری ہوئی (ٹکڑے)')),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCategory = value);
                              _applyFilters();
                            },
                            languageProvider: languageProvider,
                            isCompact: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            label: languageProvider.isEnglish ? 'Payment Status' : 'ادائیگی کی حالت',
                            value: _selectedStatus,
                            items: [
                              DropdownMenuItem(value: null, child: Text(languageProvider.isEnglish ? 'All Statuses' : 'تمام حالتیں')),
                              DropdownMenuItem(value: 'paid', child: Text(languageProvider.isEnglish ? 'Paid' : 'ادا شدہ')),
                              DropdownMenuItem(value: 'partial', child: Text(languageProvider.isEnglish ? 'Partial' : 'جزوی')),
                              DropdownMenuItem(value: 'unpaid', child: Text(languageProvider.isEnglish ? 'Unpaid' : 'غیر ادا شدہ')),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedStatus = value);
                              _applyFilters();
                            },
                            languageProvider: languageProvider,
                            isCompact: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFilterDropdown<int?>(
                            label: languageProvider.isEnglish ? 'Customer' : 'کسٹمر',
                            value: _selectedCustomerId,
                            items: [
                              DropdownMenuItem<int?>(value: null, child: Text(languageProvider.isEnglish ? 'All Customers' : 'تمام کسٹمرز')),
                              ...customerProvider.customers.map((c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCustomerId = value);
                              _applyFilters();
                            },
                            languageProvider: languageProvider,
                            isCompact: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDateRange(languageProvider),
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
                                      _getDateRangeText(languageProvider),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF0F0F5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  languageProvider.isEnglish ? 'SARYA = Weight-based' : 'ساریا = وزن پر مبنی',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                              ],
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
                          child: Text(languageProvider.isEnglish ? 'Clear All' : 'سب صاف کریں'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(languageProvider.isEnglish ? 'Apply Filters' : 'فلٹرز لاگو کریں'),
                        ),
                      ],
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
    required LanguageProvider languageProvider,
    required bool isCompact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 11 : 13,
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, size: isCompact ? 16 : 24),
          style: TextStyle(
            fontSize: isCompact ? 11 : 13,
            fontFamily: languageProvider.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSaleCard(SaleModel sale, LanguageProvider languageProvider) {
    final bool isCredit = sale.paymentMethod == 'credit';
    final bool isOverdue = sale.isOverdue;
    final bool isSarya = sale.saleCategory == 'sarya';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCredit && sale.paymentStatus != 'paid'
              ? const Color(0xFF7C3AED).withOpacity(0.3)
              : const Color(0xFFF0F0F5),
          width: isCredit && sale.paymentStatus != 'paid' ? 2 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSaleDetail(sale.id),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSarya
                            ? const Color(0xFF3B82F6).withOpacity(0.1)
                            : (isCredit
                            ? const Color(0xFF7C3AED).withOpacity(0.1)
                            : _getTypeColor(sale.saleType).withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isSarya ? Icons.scale : (isCredit ? Icons.credit_card : (sale.saleType == 'pos' ? Icons.point_of_sale : Icons.receipt_long)),
                        color: isSarya
                            ? const Color(0xFF3B82F6)
                            : (isCredit ? const Color(0xFF7C3AED) : _getTypeColor(sale.saleType)),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                sale.invoiceNumber,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSarya
                                      ? const Color(0xFF3B82F6).withOpacity(0.1)
                                      : const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isSarya ? 'S' : 'F',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isSarya ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isCredit) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'CR',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Color(0xFF7C3AED),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(sale.paymentStatus).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sale.paymentStatus == 'paid' ? 'P' : sale.paymentStatus == 'partial' ? 'PR' : 'UP',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: _getStatusColor(sale.paymentStatus),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person, size: 10, color: Colors.grey[400]),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  sale.customer?.name ?? (languageProvider.isEnglish ? 'Walk-in' : 'واک ان'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontFamily: languageProvider.fontFamily,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInfoChip(
                        label: '',
                        value: '${_dateFormat.format(sale.saleDate)} ${_timeFormat.format(sale.saleDate)}',
                        color: Colors.blue,
                        languageProvider: languageProvider,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildCompactInfoChip(
                        label: '',
                        value: '${sale.items?.length ?? 0}',
                        color: Colors.purple,
                        languageProvider: languageProvider,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildCompactInfoChip(
                        label: '',
                        value: languageProvider.isEnglish
                            ? sale.paymentMethod.toUpperCase().substring(0, 3)
                            : sale.paymentMethod == 'credit' ? 'کری' : 'نقد',
                        color: isCredit ? const Color(0xFF7C3AED) : Colors.green,
                        languageProvider: languageProvider,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildCompactInfoChip(
                        label: '',
                        value: _currencyFormat.format(sale.grandTotal),
                        color: Colors.teal,
                        languageProvider: languageProvider,
                      ),
                    ),
                  ],
                ),
                if (isOverdue && sale.paymentStatus != 'paid')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning, size: 10, color: Colors.red),
                          const SizedBox(width: 2),
                          Text(
                            '${languageProvider.isEnglish ? 'Due' : 'واجب'}: ${_dateFormat.format(sale.dueDate!)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfoChip({
    required String label,
    required String value,
    required Color color,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
          fontFamily: languageProvider.fontFamily,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSaleCard(SaleModel sale, LanguageProvider languageProvider) {
    final bool isCredit = sale.paymentMethod == 'credit';
    final bool isOverdue = sale.isOverdue;
    final bool isSarya = sale.saleCategory == 'sarya';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCredit && sale.paymentStatus != 'paid'
              ? const Color(0xFF7C3AED).withOpacity(0.3)
              : const Color(0xFFF0F0F5),
          width: isCredit && sale.paymentStatus != 'paid' ? 2 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSaleDetail(sale.id),
          onLongPress: sale.paymentStatus != 'paid'
              ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SaleScreen(existingSale: sale),
              ),
            ).then((r) { if (r == true) _loadInitialData(); });
          }
              : null,
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
                        color: isSarya
                            ? const Color(0xFF3B82F6).withOpacity(0.1)
                            : (isCredit
                            ? const Color(0xFF7C3AED).withOpacity(0.1)
                            : _getTypeColor(sale.saleType).withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isSarya ? Icons.scale : (isCredit ? Icons.credit_card : (sale.saleType == 'pos' ? Icons.point_of_sale : Icons.receipt_long)),
                        color: isSarya
                            ? const Color(0xFF3B82F6)
                            : (isCredit ? const Color(0xFF7C3AED) : _getTypeColor(sale.saleType)),
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
                                sale.invoiceNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSarya
                                      ? const Color(0xFF3B82F6).withOpacity(0.1)
                                      : const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSarya ? Icons.scale : Icons.production_quantity_limits,
                                      size: 10,
                                      color: isSarya ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSarya ? 'SARYA' : (languageProvider.isEnglish ? 'FILLED' : 'بھری ہوئی'),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isSarya ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (sale.reference != null && sale.reference!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F0FF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${languageProvider.isEnglish ? 'Ref' : 'حوالہ'}: ${sale.reference}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF7C3AED),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (isCredit) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    languageProvider.isEnglish ? 'CREDIT' : 'کریڈٹ',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF7C3AED),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(sale.paymentStatus).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  languageProvider.isEnglish
                                      ? sale.paymentStatus.toUpperCase()
                                      : sale.paymentStatus == 'paid' ? 'ادا شدہ'
                                      : sale.paymentStatus == 'partial' ? 'جزوی'
                                      : 'غیر ادا شدہ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getStatusColor(sale.paymentStatus),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  sale.customer?.name ?? (languageProvider.isEnglish ? 'Walk-in Customer' : 'واک ان کسٹمر'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: languageProvider.fontFamily),
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
                        label: languageProvider.isEnglish ? 'Date' : 'تاریخ',
                        value: '${_dateFormat.format(sale.saleDate)} ${_timeFormat.format(sale.saleDate)}',
                        color: Colors.blue,
                        languageProvider: languageProvider,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoChip(
                        label: languageProvider.isEnglish ? 'Items' : 'آئیٹمز',
                        value: '${sale.items?.length ?? 0} ${languageProvider.isEnglish ? 'items' : 'آئیٹمز'}',
                        color: Colors.purple,
                        languageProvider: languageProvider,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoChip(
                        label: languageProvider.isEnglish ? 'Payment' : 'ادائیگی',
                        value: languageProvider.isEnglish
                            ? sale.paymentMethod.toUpperCase()
                            : sale.paymentMethod == 'credit' ? 'کریڈٹ' : 'نقد',
                        color: isCredit ? const Color(0xFF7C3AED) : Colors.green,
                        languageProvider: languageProvider,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoChip(
                        label: languageProvider.isEnglish ? 'Total' : 'کل',
                        value: _currencyFormat.format(sale.grandTotal),
                        color: Colors.teal,
                        languageProvider: languageProvider,
                      ),
                    ),
                  ],
                ),
                if (isOverdue && sale.paymentStatus != 'paid')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning, size: 12, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${languageProvider.isEnglish ? 'Due' : 'واجب الادا'}: ${_dateFormat.format(sale.dueDate!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required Color color,
    required LanguageProvider languageProvider,
  }) {
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
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7), fontFamily: languageProvider.fontFamily),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, fontFamily: languageProvider.fontFamily),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: _isMobile ? 60 : 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              languageProvider.isEnglish ? 'No Sales Found' : 'کوئی فروخت نہیں ملی',
              style: TextStyle(
                fontSize: _isMobile ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontFamily: languageProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'Create your first sale or invoice' : 'اپنی پہلی فروخت یا انوائس بنائیں',
              style: TextStyle(
                fontSize: _isMobile ? 12 : 14,
                color: Colors.grey[500],
                fontFamily: languageProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToCreateSale(),
              icon: const Icon(Icons.add),
              label: Text(languageProvider.isEnglish ? 'New Sale' : 'نئی فروخت'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: _isMobile ? 16 : 24,
                  vertical: _isMobile ? 10 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Consumer<SaleProvider>(
      builder: (context, provider, child) {
        if (provider.totalPages <= 1) return const SizedBox.shrink();

        return Consumer<LanguageProvider>(
          builder: (context, languageProvider, _) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: _isMobile ? 12 : 24,
                vertical: _isMobile ? 8 : 12,
              ),
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
                    icon: Icon(Icons.chevron_left, size: _isMobile ? 20 : 24),
                    color: provider.currentPage > 1 ? const Color(0xFF7C3AED) : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isMobile
                        ? '${provider.currentPage}/${provider.totalPages}'
                        : languageProvider.isEnglish
                        ? 'Page ${provider.currentPage} of ${provider.totalPages}'
                        : 'صفحہ ${provider.currentPage} / ${provider.totalPages}',
                    style: TextStyle(
                      fontSize: _isMobile ? 12 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: provider.currentPage < provider.totalPages
                        ? () => provider.setPage(provider.currentPage + 1)
                        : null,
                    icon: Icon(Icons.chevron_right, size: _isMobile ? 20 : 24),
                    color: provider.currentPage < provider.totalPages ? const Color(0xFF7C3AED) : Colors.grey,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getTypeColor(String type) {
    return type == 'pos' ? const Color(0xFF7C3AED) : const Color(0xFF3B82F6);
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
    if (_fromDate != null && _toDate != null) {
      return '${_dateFormat.format(_fromDate!)} - ${_dateFormat.format(_toDate!)}';
    } else if (_fromDate != null) {
      return languageProvider.isEnglish
          ? 'From ${_dateFormat.format(_fromDate!)}'
          : 'سے ${_dateFormat.format(_fromDate!)}';
    } else if (_toDate != null) {
      return languageProvider.isEnglish
          ? 'To ${_dateFormat.format(_toDate!)}'
          : 'تک ${_dateFormat.format(_toDate!)}';
    } else {
      return languageProvider.isEnglish ? 'Select date range' : 'تاریخ کی حد منتخب کریں';
    }
  }

  Future<void> _selectDateRange(LanguageProvider languageProvider) async {
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
    final provider = Provider.of<SaleProvider>(context, listen: false);
    provider.fetchSales(
      saleType: _selectedType,
      saleCategory: _selectedCategory,
      paymentStatus: _selectedStatus,
      customerId: _selectedCustomerId,
      fromDate: _fromDate,
      toDate: _toDate,
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
      _fromDate = null;
      _toDate = null;
      _searchController.clear();
    });

    final provider = Provider.of<SaleProvider>(context, listen: false);
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