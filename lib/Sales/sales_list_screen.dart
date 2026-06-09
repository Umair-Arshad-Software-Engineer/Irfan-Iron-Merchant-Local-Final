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
              children: [
                _buildHeader(languageProvider),
                _buildStatsCards(languageProvider),
                _buildSearchAndFilterBar(languageProvider),
                if (_showFilters) _buildFiltersPanel(languageProvider),
                Consumer<SaleProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.sales.isEmpty) {
                      return const LoadingIndicator();
                    }

                    if (provider.errorMessage != null) {
                      return CustomErrorWidget(
                        message: provider.errorMessage!,
                        onRetry: () => provider.fetchSales(refresh: true),
                      );
                    }

                    if (provider.sales.isEmpty) {
                      return _buildEmptyState(languageProvider);
                    }

                    return RefreshIndicator(
                      onRefresh: () => provider.fetchSales(refresh: true),
                      child: ListView.builder(
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
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Text(
            languageProvider.isEnglish ? 'Sales Management' : 'فروخت کا انتظام',
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard(
                  languageProvider.isEnglish ? 'POS Sales' : 'POS فروخت',
                  posCount.toString(),
                  Icons.point_of_sale,
                  Colors.purple,
                  languageProvider,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Invoices' : 'انوائسز',
                  invoiceCount.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                  languageProvider,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'SARYA',
                  saryaCount.toString(),
                  Icons.scale,
                  const Color(0xFF3B82F6),
                  languageProvider,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'FILLED' : 'بھری ہوئی',
                  filledCount.toString(),
                  Icons.production_quantity_limits,
                  const Color(0xFF10B981),
                  languageProvider,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Paid' : 'ادا شدہ',
                  paidCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                  languageProvider,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Credit' : 'کریڈٹ',
                  creditCount.toString(),
                  Icons.credit_card,
                  const Color(0xFF7C3AED),
                  languageProvider,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Pending' : 'زیر التواء',
                  'Rs ${_currencyFormat.format(totalPending)}',
                  Icons.pending,
                  Colors.orange,
                  languageProvider,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  languageProvider.isEnglish ? 'Revenue' : 'آمدنی',
                  'Rs ${_currencyFormat.format(totalRevenue)}',
                  Icons.attach_money,
                  Colors.teal,
                  languageProvider,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, LanguageProvider languageProvider) {
    return Container(
      width: 200,
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
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
                style: TextStyle(fontFamily: languageProvider.fontFamily),
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish
                      ? 'Search by invoice number or customer...'
                      : 'انوائس نمبر یا کسٹمر سے تلاش کریں...',
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
              tooltip: languageProvider.isEnglish ? 'Filters' : 'فلٹرز',
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
                languageProvider.isEnglish ? 'Filters' : 'فلٹرز',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
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
          hint: Text(label, style: TextStyle(fontFamily: languageProvider.fontFamily)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          style: TextStyle(fontFamily: languageProvider.fontFamily),
        ),
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

  Widget _buildInfoChip({required String label, required String value, required Color color, required LanguageProvider languageProvider}) {
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            languageProvider.isEnglish ? 'No Sales Found' : 'کوئی فروخت نہیں ملی',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            languageProvider.isEnglish ? 'Create your first sale or invoice' : 'اپنی پہلی فروخت یا انوائس بنائیں',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToCreateSale(),
            icon: const Icon(Icons.add),
            label: Text(languageProvider.isEnglish ? 'New Sale' : 'نئی فروخت'),
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
    return Consumer<SaleProvider>(
      builder: (context, provider, child) {
        if (provider.totalPages <= 1) return const SizedBox.shrink();

        return Consumer<LanguageProvider>(
          builder: (context, languageProvider, _) {
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
                    languageProvider.isEnglish
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