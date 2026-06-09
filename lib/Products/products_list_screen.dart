import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/unit_provider.dart';
import '../../providers/supplier_provider.dart';
import 'package:intl/intl.dart';
import '../components/error_widget.dart';
import '../components/loading_indicator.dart';
import '../../models/product_model.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/unit.dart';
import '../providers/lanprovider.dart';
import '../providers/product_image_provider.dart';
import '../services/product_pdf_generator.dart';
import 'add_edit_product_screen.dart';
import 'product_detail_screen.dart';

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  bool _showFilters = false;
  String? _selectedCategory;
  String? _selectedSupplier;
  String? _selectedUnit;
  bool? _lowStockOnly;
  bool? _activeOnly;
  bool _isInitialized = false;

  // Column sort state
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  static const _purple = Color(0xFF7C3AED);
  static const _red = Color(0xFFDC2626);
  static const _teal = Color(0xFF059669);
  static const _amber = Color(0xFFD97706);
  static const _bgPurple = Color(0xFFF5F3FF);
  static const _bgRed = Color(0xFFFEF2F2);
  static const _bgTeal = Color(0xFFECFDF5);
  static const _bgAmber = Color(0xFFFFFBEB);
  static const _border = Color(0xFFE5E7EB);
  static const _surface = Color(0xFFF9FAFB);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textTertiary = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final unitProvider = Provider.of<UnitProvider>(context, listen: false);
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
    try {
      await Future.wait([
        productProvider.fetchProducts(),
        categoryProvider.loadCategories(),
        unitProvider.loadUnits(),
        supplierProvider.fetchSuppliers(context: context),
      ]);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing data: $e');
    }
  }

  Timer? _debounceTimer;
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      Provider.of<ProductProvider>(context, listen: false)
          .fetchProducts(search: _searchController.text);
    });
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: _surface,
          body: Column(
            children: [
              _buildHeader(languageProvider),
              _buildStatsRow(languageProvider),
              _buildToolbar(languageProvider),
              if (_showFilters) _buildFiltersPanel(languageProvider),
              Expanded(
                child: Consumer<ProductProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading && provider.products.isEmpty) {
                      return const LoadingIndicator();
                    }
                    if (provider.errorMessage != null) {
                      return CustomErrorWidget(
                        message: provider.errorMessage!,
                        onRetry: () => provider.fetchProducts(refresh: true),
                      );
                    }
                    if (provider.products.isEmpty) return _buildEmptyState(languageProvider);
                    return _buildTableView(provider, languageProvider);
                  },
                ),
              ),
              _buildPagination(languageProvider),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _navigateToAddProduct,
            label: Text(
              languageProvider.isEnglish ? 'Add Product' : 'پروڈکٹ شامل کریں',
              style: const TextStyle(color: Colors.white),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            backgroundColor: _purple,
          ),
        );
      },
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            languageProvider.isEnglish ? 'Products' : 'پروڈکٹس',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const Spacer(),
          _headerIconBtn(
            Icons.inventory_2_outlined,
            languageProvider.isEnglish ? 'Bulk Operations' : 'بلک آپریشنز',
            _showBulkOperations,
          ),
          const SizedBox(width: 8),
          _headerIconBtn(
            Icons.download_outlined,
            languageProvider.isEnglish ? 'Export' : 'ایکسپورٹ',
            _showExportOptions,
          ),
        ],
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Icon(icon, size: 18, color: _textSecondary),
        ),
      ),
    );
  }

  // ─── STATS ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(LanguageProvider languageProvider) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Row(
            children: [
              Expanded(child: _statCard(
                languageProvider.isEnglish ? 'Total Products' : 'کل پروڈکٹس',
                provider.totalProducts.toString(),
                Icons.inventory_2_rounded, _purple, _bgPurple, languageProvider,
              )),
              const SizedBox(width: 12),
              Expanded(child: _statCard(
                languageProvider.isEnglish ? 'Low Stock' : 'کم اسٹاک',
                provider.lowStockCount.toString(),
                Icons.warning_amber_rounded, _red, _bgRed, languageProvider,
              )),
              const SizedBox(width: 12),
              Expanded(child: _statCard(
                languageProvider.isEnglish ? 'Inventory Value' : 'انوینٹری ویلیو',
                NumberFormat.compactCurrency(symbol: 'PKR ', decimalDigits: 2)
                    .format(provider.totalInventoryValue),
                Icons.account_balance_wallet_outlined, _teal, _bgTeal, languageProvider,
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    fontFamily: languageProvider.fontFamily,
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

  // ─── TOOLBAR ──────────────────────────────────────────────────────────────

  Widget _buildToolbar(LanguageProvider languageProvider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                  fontFamily: languageProvider.fontFamily,
                ),
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish
                      ? 'Search by name or barcode…'
                      : 'نام یا بارکوڈ سے تلاش کریں…',
                  hintStyle: const TextStyle(color: _textTertiary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18, color: _textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _toolbarBtn(
            icon: Icons.tune_rounded,
            label: languageProvider.isEnglish ? 'Filters' : 'فلٹرز',
            active: _showFilters,
            onTap: () => setState(() => _showFilters = !_showFilters),
            languageProvider: languageProvider,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _refreshProducts,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: const Icon(Icons.refresh, size: 18, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required LanguageProvider languageProvider,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _bgPurple : Colors.white,
          border: Border.all(color: active ? _purple : _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? _purple : _textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: active ? _purple : _textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                fontFamily: languageProvider.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FILTERS ──────────────────────────────────────────────────────────────

  Widget _buildFiltersPanel(LanguageProvider languageProvider) {
    return Consumer3<CategoryProvider, SupplierProvider, UnitProvider>(
      builder: (context, catProvider, supProvider, unitProvider, _) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _filterDropdown<String>(
                        languageProvider.isEnglish ? 'Category' : 'کیٹگری',
                        _selectedCategory,
                        [
                          DropdownMenuItem(
                              value: null,
                              child: Text(languageProvider.isEnglish ? 'All categories' : 'تمام کیٹگریز')
                          ),
                          ...catProvider.categories.map((c) =>
                              DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                            (v) { setState(() => _selectedCategory = v); _applyFilters(); },
                        languageProvider,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _filterDropdown<String>(
                        languageProvider.isEnglish ? 'Supplier' : 'سپلائر',
                        _selectedSupplier,
                        [
                          DropdownMenuItem(
                              value: null,
                              child: Text(languageProvider.isEnglish ? 'All suppliers' : 'تمام سپلائرز')
                          ),
                          ...supProvider.suppliers.map((s) =>
                              DropdownMenuItem(value: s.id.toString(), child: Text(s.name))),
                        ],
                            (v) { setState(() => _selectedSupplier = v); _applyFilters(); },
                        languageProvider,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _filterDropdown<String>(
                        languageProvider.isEnglish ? 'Unit' : 'یونٹ',
                        _selectedUnit,
                        [
                          DropdownMenuItem(
                              value: null,
                              child: Text(languageProvider.isEnglish ? 'All units' : 'تمام یونٹس')
                          ),
                          ...unitProvider.units.map((u) =>
                              DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.symbol})'))),
                        ],
                            (v) { setState(() => _selectedUnit = v); _applyFilters(); },
                        languageProvider,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _filterChip(
                      Icons.warning_amber_rounded,
                      languageProvider.isEnglish ? 'Low Stock' : 'کم اسٹاک',
                      _lowStockOnly ?? false,
                          (v) { setState(() => _lowStockOnly = v); _applyFilters(); },
                      languageProvider,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      Icons.check_circle_outline,
                      languageProvider.isEnglish ? 'Active Only' : 'صرف فعال',
                      _activeOnly ?? false,
                          (v) { setState(() => _activeOnly = v); _applyFilters(); },
                      languageProvider,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearFilters,
                      child: Text(
                        languageProvider.isEnglish ? 'Clear all' : 'سب صاف کریں',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(fontSize: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(languageProvider.isEnglish ? 'Apply' : 'لاگو کریں'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterDropdown<T>(
      String label,
      T? value,
      List<DropdownMenuItem<T>> items,
      void Function(T?) onChanged,
      LanguageProvider languageProvider,
      ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  color: _textTertiary,
                  fontFamily: languageProvider.fontFamily
              )
          ),
          isExpanded: true,
          style: TextStyle(
              fontSize: 13,
              color: _textPrimary,
              fontFamily: languageProvider.fontFamily
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        ),
      ),
    );
  }

  Widget _filterChip(IconData icon, String label, bool selected, void Function(bool) onSelected, LanguageProvider languageProvider) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _bgPurple : Colors.white,
          border: Border.all(color: selected ? _purple.withOpacity(0.5) : _border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Icon(Icons.check, size: 13, color: _purple)
            else
              Icon(icon, size: 13, color: _textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? _purple : _textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontFamily: languageProvider.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FULL WIDTH TABLE ────────────────────────────────────────────────────

  Widget _buildTableView(ProductProvider provider, LanguageProvider languageProvider) {
    return Column(
      children: [
        // Row count bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Text(
                languageProvider.isEnglish
                    ? 'Showing ${provider.products.length} of ${provider.totalProducts} products'
                    : '${provider.products.length} میں سے ${provider.totalProducts} پروڈکٹس دکھا رہے ہیں',
                style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontFamily: languageProvider.fontFamily
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _border),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.fetchProducts(refresh: true),
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 48,
                  child: Column(
                    children: [
                      _buildTableHeader(languageProvider),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: provider.products.length,
                          itemBuilder: (context, index) {
                            final product = provider.products[index];
                            return _buildTableRow(product, index, languageProvider);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(LanguageProvider languageProvider) {
    return Container(
      color: _surface,
      child: Row(
        children: [
          _thCell(languageProvider.isEnglish ? 'Product' : 'پروڈکٹ', flex: 28, sortIndex: 0, languageProvider: languageProvider),
          _thCell(languageProvider.isEnglish ? 'Category' : 'کیٹگری', flex: 14, sortIndex: 1, languageProvider: languageProvider),
          _thCell(languageProvider.isEnglish ? 'Stock' : 'اسٹاک', flex: 10, sortIndex: 2, languageProvider: languageProvider),
          _thCell(languageProvider.isEnglish ? 'Cost' : 'لاگت', flex: 12, sortIndex: 3, languageProvider: languageProvider),
          _thCell(languageProvider.isEnglish ? 'Sale Price' : 'فروخت قیمت', flex: 12, sortIndex: 4, languageProvider: languageProvider),
          _thCell(languageProvider.isEnglish ? 'Margin' : 'مارجن', flex: 9, sortIndex: 5, languageProvider: languageProvider),
          _thCell(languageProvider.isEnglish ? 'Status' : 'صورتحال', flex: 8, sortIndex: -1, languageProvider: languageProvider),
          _thCell(languageProvider.isEnglish ? 'Actions' : 'ایکشنز', flex: 7, sortIndex: -1, languageProvider: languageProvider),
        ],
      ),
    );
  }

  Widget _thCell(String label, {required int flex, required int sortIndex, required LanguageProvider languageProvider}) {
    final isSorted = _sortColumnIndex == sortIndex && sortIndex >= 0;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: sortIndex >= 0
            ? () => setState(() {
          if (_sortColumnIndex == sortIndex) {
            _sortAscending = !_sortAscending;
          } else {
            _sortColumnIndex = sortIndex;
            _sortAscending = true;
          }
        })
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSorted ? _purple : _textTertiary,
                  letterSpacing: 0.5,
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
              if (sortIndex >= 0) ...[
                const SizedBox(width: 3),
                Icon(
                  isSorted
                      ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                      : Icons.unfold_more,
                  size: 12,
                  color: isSorted ? _purple : _textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(ProductModel product, int index, LanguageProvider languageProvider) {
    final isLowStock = product.physicalQty <= product.minStock;
    final isBom = product.isBom;
    final formatter = NumberFormat.currency(symbol: 'PKR ', decimalDigits: 0);
    final costForMargin = isBom ? (product.bomTotalCost ?? product.costPrice) : product.costPrice;
    final margin = costForMargin > 0
        ? ((product.salePrice - costForMargin) / product.salePrice * 100)
        : 0.0;

    return InkWell(
      onTap: () => _navigateToProductDetail(product.id),
      child: Container(
        decoration: BoxDecoration(
          color: index.isOdd ? Colors.white : _surface.withOpacity(0.5),
          border: const Border(bottom: BorderSide(color: _border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Product name + sku
            Expanded(
              flex: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Image / icon
                    Consumer<ProductImageProvider>(
                      builder: (context, imgProvider, _) {
                        final img = imgProvider.getPrimaryImage(product.id);
                        return Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _bgPurple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: img != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              img.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.inventory_2, color: _purple, size: 18),
                            ),
                          )
                              : Icon(
                            isBom ? Icons.precision_manufacturing_outlined : Icons.inventory_2_outlined,
                            color: _purple,
                            size: 18,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  product.itemName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                    fontFamily: languageProvider.fontFamily,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isBom) ...[
                                const SizedBox(width: 6),
                                _inlineBadge(
                                    languageProvider.isEnglish ? 'BOM' : 'بی او ایم',
                                    _purple,
                                    _bgPurple,
                                    languageProvider
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.barcode ?? ''} ${product.barcode != null ? '·' : ''} ${product.category?.name ?? (languageProvider.isEnglish ? 'Uncategorized' : 'غیر درجہ بند')}',
                            style: TextStyle(
                                fontSize: 11,
                                color: _textTertiary,
                                fontFamily: languageProvider.fontFamily
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Category
            Expanded(
              flex: 14,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  product.category?.name ?? '—',
                  style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontFamily: languageProvider.fontFamily
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Stock
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      '${product.physicalQty} ${product.unit?.symbol ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLowStock ? _red : _teal,
                        fontFamily: languageProvider.fontFamily,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber_rounded, size: 14, color: _red),
                    ],
                  ],
                ),
              ),
            ),
            // Cost
            Expanded(
              flex: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  formatter.format(isBom ? (product.bomTotalCost ?? product.costPrice) : product.costPrice),
                  style: TextStyle(
                      fontSize: 12,
                      color: _textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontFamily: languageProvider.fontFamily
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Sale Price
            Expanded(
              flex: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  formatter.format(product.salePrice),
                  style: TextStyle(
                      fontSize: 12,
                      color: _textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontFamily: languageProvider.fontFamily
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Margin
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      margin >= 20 ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: margin >= 20 ? _teal : _amber,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${margin.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: margin >= 20 ? _teal : _amber,
                        fontFamily: languageProvider.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Status
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: product.isActive
                    ? _inlineBadge(
                    languageProvider.isEnglish ? 'Active' : 'فعال',
                    _teal,
                    _bgTeal,
                    languageProvider
                )
                    : _inlineBadge(
                    languageProvider.isEnglish ? 'Inactive' : 'غیر فعال',
                    _textSecondary,
                    const Color(0xFFF3F4F6),
                    languageProvider
                ),
              ),
            ),
            // Actions
            Expanded(
              flex: 7,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: _textSecondary,
                    onPressed: () => _navigateToEditProduct(product),
                    tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: _red.withOpacity(0.7),
                    onPressed: () => _showDeleteConfirmation(product, languageProvider),
                    tooltip: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── NEW ACTION METHODS ───────────────────────────────────────────────────

  void _navigateToEditProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(productId: product.id),
      ),
    ).then((refresh) {
      if (refresh == true) _refreshProducts();
    });
  }

  void _showDeleteConfirmation(ProductModel product, LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Product' : 'پروڈکٹ حذف کریں'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to delete "${product.itemName}"?'
              : 'کیا آپ واقعی "${product.itemName}" کو حذف کرنا چاہتے ہیں؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteProduct(product.id, languageProvider);
            },
            style: TextButton.styleFrom(foregroundColor: _red),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(int id, LanguageProvider languageProvider) async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    try {
      await productProvider.deleteProduct(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  languageProvider.isEnglish
                      ? 'Product deleted successfully'
                      : 'پروڈکٹ کامیابی سے حذف ہو گئی'
              )
          ),
        );
        _refreshProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  languageProvider.isEnglish
                      ? 'Error deleting product: $e'
                      : 'پروڈکٹ حذف کرنے میں خرابی: $e'
              ),
              backgroundColor: _red
          ),
        );
      }
    }
  }

  Widget _inlineBadge(String label, Color textColor, Color bg, LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
            fontFamily: languageProvider.fontFamily
        ),
      ),
    );
  }

  // ─── EMPTY ────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: _bgPurple, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.inventory_2_outlined, size: 36, color: _purple),
          ),
          const SizedBox(height: 16),
          Text(
            languageProvider.isEnglish ? 'No Products Found' : 'کوئی پروڈکٹ نہیں ملی',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
                fontFamily: languageProvider.fontFamily
            ),
          ),
          const SizedBox(height: 6),
          Text(
            languageProvider.isEnglish
                ? 'Add your first product to get started'
                : 'شروع کرنے کے لیے اپنی پہلی پروڈکٹ شامل کریں',
            style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
                fontFamily: languageProvider.fontFamily
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddProduct,
            icon: const Icon(Icons.add),
            label: Text(languageProvider.isEnglish ? 'Add Product' : 'پروڈکٹ شامل کریں'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PAGINATION ───────────────────────────────────────────────────────────

  Widget _buildPagination(LanguageProvider languageProvider) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        if (provider.totalPages <= 1) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Text(
                languageProvider.isEnglish
                    ? 'Page ${provider.currentPage} of ${provider.totalPages}  ·  ${provider.totalProducts} products'
                    : 'صفحہ ${provider.currentPage} of ${provider.totalPages}  ·  ${provider.totalProducts} پروڈکٹس',
                style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontFamily: languageProvider.fontFamily
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _pageBtn(
                    icon: Icons.chevron_left,
                    enabled: provider.currentPage > 1,
                    onTap: () => provider.setPage(provider.currentPage - 1),
                  ),
                  const SizedBox(width: 4),
                  ...List.generate(
                    provider.totalPages.clamp(0, 5),
                        (i) {
                      final page = i + 1;
                      final isCurrent = page == provider.currentPage;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: isCurrent ? null : () => provider.setPage(page),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isCurrent ? _purple : Colors.white,
                              border: Border.all(color: isCurrent ? _purple : _border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$page',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isCurrent ? Colors.white : _textSecondary,
                                fontFamily: languageProvider.fontFamily,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _pageBtn(
                    icon: Icons.chevron_right,
                    enabled: provider.currentPage < provider.totalPages,
                    onTap: () => provider.setPage(provider.currentPage + 1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageBtn({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Icon(icon, size: 16, color: enabled ? _textSecondary : _textTertiary),
      ),
    );
  }

  // ─── ACTIONS ──────────────────────────────────────────────────────────────

  void _applyFilters() {
    int? safeInt(String? v) => (v == null || v.isEmpty) ? null : int.tryParse(v);
    Provider.of<ProductProvider>(context, listen: false).fetchProducts(
      categoryId: safeInt(_selectedCategory),
      supplierId: safeInt(_selectedSupplier),
      unitId: safeInt(_selectedUnit),
      lowStock: _lowStockOnly,
      active: _activeOnly,
      refresh: true,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedSupplier = null;
      _selectedUnit = null;
      _lowStockOnly = null;
      _activeOnly = null;
    });
    Provider.of<ProductProvider>(context, listen: false).fetchProducts(refresh: true);
  }

  void _refreshProducts() =>
      Provider.of<ProductProvider>(context, listen: false).fetchProducts(refresh: true);

  void _navigateToProductDetail(int id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: id)));
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
    ).then((refresh) {
      if (refresh == true) _refreshProducts();
    });
  }

  // ─── BULK / EXPORT ────────────────────────────────────────────────────────

  void _showBulkOperations() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _buildBulkSheet(),
    );
  }

  Widget _buildBulkSheet() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))
              ),
              Text(
                languageProvider.isEnglish ? 'Bulk Operations' : 'بلک آپریشنز',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    fontFamily: languageProvider.fontFamily
                ),
              ),
              const SizedBox(height: 16),
              _bulkTile(
                Icons.download,
                languageProvider.isEnglish ? 'Export Products' : 'پروڈکٹس ایکسپورٹ کریں',
                languageProvider.isEnglish
                    ? 'Download as CSV, Excel or PDF'
                    : 'CSV، Excel یا PDF کے طور پر ڈاؤن لوڈ کریں',
                _exportProducts,
                languageProvider,
              ),
              _bulkTile(
                Icons.upload,
                languageProvider.isEnglish ? 'Import Products' : 'پروڈکٹس امپورٹ کریں',
                languageProvider.isEnglish
                    ? 'Upload CSV to add multiple products'
                    : 'متعدد پروڈکٹس شامل کرنے کے لیے CSV اپ لوڈ کریں',
                _importProducts,
                languageProvider,
              ),
              _bulkTile(
                Icons.price_change,
                languageProvider.isEnglish ? 'Bulk Price Update' : 'بلک قیمت اپ ڈیٹ',
                languageProvider.isEnglish
                    ? 'Update prices for multiple products'
                    : 'متعدد پروڈکٹس کی قیمتیں اپ ڈیٹ کریں',
                _bulkPriceUpdate,
                languageProvider,
              ),
              _bulkTile(
                Icons.inventory,
                languageProvider.isEnglish ? 'Bulk Stock Update' : 'بلک اسٹاک اپ ڈیٹ',
                languageProvider.isEnglish
                    ? 'Update quantities for multiple products'
                    : 'متعدد پروڈکٹس کی مقدار اپ ڈیٹ کریں',
                _bulkStockUpdate,
                languageProvider,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bulkTile(IconData icon, String title, String subtitle, VoidCallback onTap, LanguageProvider languageProvider) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: _bgPurple, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: _purple, size: 20),
      ),
      title: Text(
          title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: languageProvider.fontFamily
          )
      ),
      subtitle: Text(
          subtitle,
          style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontFamily: languageProvider.fontFamily
          )
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return AlertDialog(
            title: Text(
              languageProvider.isEnglish ? 'Export Products' : 'پروڈکٹس ایکسپورٹ کریں',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _exportTile(
                  Icons.picture_as_pdf,
                  languageProvider.isEnglish ? 'PDF Document' : 'PDF دستاویز',
                  languageProvider.isEnglish
                      ? 'Export with filters and formatting'
                      : 'فلٹرز اور فارمیٹنگ کے ساتھ ایکسپورٹ کریں',
                  _purple,
                      () {
                    Navigator.pop(ctx);
                    _exportProductsAsPdf(languageProvider);
                  },
                  languageProvider,
                ),
                _exportTile(
                  Icons.table_chart,
                  languageProvider.isEnglish ? 'CSV File' : 'CSV فائل',
                  languageProvider.isEnglish
                      ? 'Export as spreadsheet data'
                      : 'اسپریڈ شیٹ ڈیٹا کے طور پر ایکسپورٹ کریں',
                  _teal,
                      () {
                    Navigator.pop(ctx);
                    _exportAs('csv', languageProvider);
                  },
                  languageProvider,
                ),
                _exportTile(
                  Icons.grid_on,
                  languageProvider.isEnglish ? 'Excel File' : 'Excel فائل',
                  languageProvider.isEnglish
                      ? 'Export as Excel spreadsheet'
                      : 'Excel اسپریڈ شیٹ کے طور پر ایکسپورٹ کریں',
                  Colors.blue,
                      () {
                    Navigator.pop(ctx);
                    _exportAs('excel', languageProvider);
                  },
                  languageProvider,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _exportTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap, LanguageProvider languageProvider) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: languageProvider.fontFamily
          )
      ),
      subtitle: Text(
          subtitle,
          style: TextStyle(
              fontSize: 12,
              fontFamily: languageProvider.fontFamily
          )
      ),
      onTap: onTap,
    );
  }

  Future<void> _exportProductsAsPdf(LanguageProvider languageProvider) async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final products = productProvider.products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  languageProvider.isEnglish
                      ? 'No products to export'
                      : 'ایکسپورٹ کرنے کے لیے کوئی پروڈکٹ نہیں'
              ),
              backgroundColor: _red
          )
      );
      return;
    }
    final stats = {
      'total': products.length,
      'low_stock': products.where((p) => p.physicalQty <= p.minStock).length,
      'active': products.where((p) => p.isActive).length,
      'inactive': products.where((p) => !p.isActive).length,
    };

    String? categoryName, supplierName, unitName;
    if (_selectedCategory != null) {
      final cp = Provider.of<CategoryProvider>(context, listen: false);
      categoryName = cp.categories.firstWhere(
              (c) => c.id.toString() == _selectedCategory,
          orElse: () => Category(
              id: '0',
              name: languageProvider.isEnglish ? 'Unknown' : 'نامعلوم',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now()
          )
      ).name;
    }
    if (_selectedSupplier != null) {
      final sp = Provider.of<SupplierProvider>(context, listen: false);
      supplierName = sp.suppliers.firstWhere(
              (s) => s.id.toString() == _selectedSupplier,
          orElse: () => Supplier(
              id: 0,
              name: languageProvider.isEnglish ? 'Unknown' : 'نامعلوم',
              contact: '',
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              discountPercent: 0.0
          )
      ).name;
    }
    if (_selectedUnit != null) {
      final up = Provider.of<UnitProvider>(context, listen: false);
      unitName = up.units.firstWhere(
              (u) => u.id.toString() == _selectedUnit,
          orElse: () => Unit(
              id: '0',
              name: languageProvider.isEnglish ? 'Unknown' : 'نامعلوم',
              symbol: '',
              type: '',
              isActive: true,
              conversionFactor: 1.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now()
          )
      ).name;
    }

    final filterInfo = {
      'total_count': products.length,
      'category': categoryName,
      'supplier': supplierName,
      'unit': unitName,
      'low_stock': _lowStockOnly,
      'active_only': _activeOnly,
      'search': _searchController.text,
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final pdfData = await ProductPdfGenerator.generateProductsListPdf(
          products: products, filterInfo: filterInfo, stats: stats);
      if (mounted) Navigator.pop(context);
      _showPrintOptions(pdfData,
          'products_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
          languageProvider);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  languageProvider.isEnglish
                      ? 'Error generating PDF: $e'
                      : 'PDF بنانے میں خرابی: $e'
              ),
              backgroundColor: _red
          )
      );
    }
  }

  void _showPrintOptions(Uint8List pdfData, String filename, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))
            ),
            Text(
              languageProvider.isEnglish ? 'Export Options' : 'ایکسپورٹ آپشنز',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: languageProvider.fontFamily
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _printOption(
                    Icons.picture_as_pdf,
                    languageProvider.isEnglish ? 'Save PDF' : 'PDF محفوظ کریں',
                    _purple,
                        () {
                      Navigator.pop(ctx);
                      ProductPdfGenerator.sharePdf(pdfData, filename);
                    },
                    languageProvider
                )),
                const SizedBox(width: 12),
                Expanded(child: _printOption(
                    Icons.print,
                    languageProvider.isEnglish ? 'Print' : 'پرنٹ کریں',
                    _teal,
                        () {
                      Navigator.pop(ctx);
                      ProductPdfGenerator.printPdf(pdfData);
                    },
                    languageProvider
                )),
                const SizedBox(width: 12),
                Expanded(child: _printOption(
                    Icons.visibility,
                    languageProvider.isEnglish ? 'Preview' : 'پریوو',
                    Colors.blue,
                        () {
                      Navigator.pop(ctx);
                      _showPdfPreview(pdfData);
                    },
                    languageProvider
                )),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _printOption(IconData icon, String label, Color color, VoidCallback onTap, LanguageProvider languageProvider) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
                label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: languageProvider.fontFamily
                )
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(Uint8List pdfData) async =>
      Printing.layoutPdf(onLayout: (_) => pdfData);

  void _exportProducts() => _showExportOptions();
  void _exportAs(String format, LanguageProvider languageProvider) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  languageProvider.isEnglish
                      ? 'Exporting as $format…'
                      : '$format کے طور پر ایکسپورٹ ہو رہا ہے…'
              )
          )
      );
  void _importProducts() =>
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import coming soon…'))
      );
  void _bulkPriceUpdate() =>
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk price update coming soon…'))
      );
  void _bulkStockUpdate() =>
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk stock update coming soon…'))
      );
}