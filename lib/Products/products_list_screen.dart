// lib/screens/products/products_list_screen.dart
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

  bool _showFilters = false;
  String? _selectedCategory;
  String? _selectedSupplier;
  String? _selectedUnit;
  bool? _lowStockOnly;
  bool? _activeOnly;
  bool _isInitialized = false; // Add this flag

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Initialize data after first frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // Prevent double initialization
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

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print(e);
      debugPrint('Error initializing data: $e');
    }
  }

  void _onSearchChanged() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    // Debounce search to avoid too many requests
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      productProvider.fetchProducts(search: _searchController.text);
    });
  }

  Timer? _debounceTimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsCards(),
          _buildSearchAndFilterBar(),
          if (_showFilters) _buildFiltersPanel(),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading && productProvider.products.isEmpty) {
                  return const LoadingIndicator();
                }

                if (productProvider.errorMessage != null) {
                  return CustomErrorWidget(
                    message: productProvider.errorMessage!,
                    onRetry: () => productProvider.fetchProducts(refresh: true),
                  );
                }

                if (productProvider.products.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildProductsList(productProvider);
              },
            ),
          ),
          _buildPagination(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddProduct(),
        label: const Text('Add Product',style: TextStyle(color: Colors.white),),
        icon: const Icon(Icons.add,color: Colors.white),
        backgroundColor: const Color(0xFF7C3AED),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          const Text(
            'Products',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showBulkOperations(),
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Bulk Operations',
          ),
          IconButton(
            onPressed: () => _showExportOptions(),
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Products',
                  provider.totalProducts.toString(),
                  Icons.inventory_2,
                  const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Low Stock',
                  provider.lowStockCount.toString(),
                  Icons.warning_amber_rounded,
                  const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Inventory Value',
                  NumberFormat.currency(symbol: 'PKR ').format(provider.totalInventoryValue),
                  Icons.attach_money,
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
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

  Widget _buildSearchAndFilterBar() {
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
                decoration: InputDecoration(
                  hintText: 'Search products by name, barcode...',
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
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
              icon: Icon(
                Icons.filter_list,
                color: _showFilters ? const Color(0xFF7C3AED) : Colors.grey[600],
              ),
              tooltip: 'Toggle Filters',
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
            ),
            child: IconButton(
              onPressed: _refreshProducts,
              icon: Icon(Icons.refresh, color: Colors.grey[600]),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Consumer3<CategoryProvider, SupplierProvider, UnitProvider>(
      builder: (context, categoryProvider, supplierProvider, unitProvider, child) {
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
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown<String>(
                      label: 'Category',
                      value: _selectedCategory,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...categoryProvider.categories.map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFilterDropdown<String>(
                      label: 'Supplier',
                      value: _selectedSupplier,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Suppliers'),
                        ),
                        ...supplierProvider.suppliers.map((s) => DropdownMenuItem<String>(
                          value: s.id.toString(),
                          child: Text(s.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedSupplier = value);
                        _applyFilters();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown<String>(
                      label: 'Unit',
                      value: _selectedUnit,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Units'),
                        ),
                        ...unitProvider.units.map((u) => DropdownMenuItem<String>(
                          value: u.id,
                          child: Text('${u.name} (${u.symbol})'),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedUnit = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            selected: _lowStockOnly ?? false,
                            onSelected: (value) {
                              setState(() => _lowStockOnly = value);
                              _applyFilters();
                            },
                            label: const Text('Low Stock'),
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFF7C3AED).withOpacity(0.1),
                            checkmarkColor: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilterChip(
                            selected: _activeOnly ?? false,
                            onSelected: (value) {
                              setState(() => _activeOnly = value);
                              _applyFilters();
                            },
                            label: const Text('Active Only'),
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFF7C3AED).withOpacity(0.1),
                            checkmarkColor: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
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
                    child: const Text('Clear All'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply Filters'),
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
          hint: Text(label),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ),
    );
  }

  Widget _buildProductsList(ProductProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.fetchProducts(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        itemCount: provider.products.length,
        itemBuilder: (context, index) {
          final product = provider.products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final isLowStock = product.physicalQty <= product.minStock;
    final formatter = NumberFormat.currency(symbol: 'Pkr ');
    final isBomProduct = product.isBom;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBomProduct
              ? const Color(0xFF7C3AED).withOpacity(0.5)
              : (isLowStock ? const Color(0xFFFF6B6B).withOpacity(0.3) : const Color(0xFFF0F0F5)),
          width: isBomProduct ? 2 : 1.5,
        ),
        boxShadow: isBomProduct ? [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProductDetail(product.id),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // BOM Banner
              if (isBomProduct)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'BILL OF MATERIALS (BOM)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (product.bomComponents != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${product.bomComponents!.length} components',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Image section with Consumer for ProductImageProvider
                        Consumer<ProductImageProvider>(
                          builder: (context, imageProvider, child) {
                            final primaryImage = imageProvider.getPrimaryImage(product.id);

                            return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: primaryImage != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  primaryImage.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.inventory_2,
                                      color: Color(0xFF7C3AED),
                                      size: 30,
                                    );
                                  },
                                ),
                              )
                                  : Icon(
                                isBomProduct ? Icons.inventory : Icons.inventory_2,
                                color: const Color(0xFF7C3AED),
                                size: 30,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.itemName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D3142),
                                      ),
                                    ),
                                  ),
                                  if (!product.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Barcode + Category row
                              Row(
                                children: [
                                  if (product.barcode != null) ...[
                                    Icon(Icons.qr_code, size: 12, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.barcode!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Icon(Icons.category, size: 12, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      product.category?.name ?? 'N/A',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              // Lengths badge (only when hasMultipleLengths)
                              if (product.hasMultipleLengths) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFF7C3AED).withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.straighten,
                                              size: 10, color: Color(0xFF7C3AED)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${product.lengthCombinations?.length ?? 0} lengths',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF7C3AED),
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // BOM badge
                              if (isBomProduct && product.bomComponents != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFF10B981).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.factory,
                                              size: 10, color: Color(0xFF10B981)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Manufactured: ${_formatBomTotalCost(product.bomTotalCost)}',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                            label: 'Stock',
                            value: '${product.physicalQty} ${product.unit?.symbol ?? ''}',
                            color: isLowStock ? const Color(0xFFFF6B6B) : const Color(0xFF10B981),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoChip(
                            label: isBomProduct ? 'BOM Cost' : 'Cost',
                            value: formatter.format(isBomProduct
                                ? (product.bomTotalCost ?? product.costPrice)
                                : product.costPrice),
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoChip(
                            label: 'Sale',
                            value: formatter.format(product.salePrice),
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    // Profit margin indicator for BOM products
                    if (isBomProduct && product.bomTotalCost != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.trending_up, size: 12, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Text(
                              'Margin: ${((product.salePrice - product.bomTotalCost!) / product.bomTotalCost! * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
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

  String _formatBomTotalCost(double? cost) {
    if (cost == null) return 'N/A';
    final formatter = NumberFormat.currency(symbol: 'PKR ');
    return formatter.format(cost);
  }

  Widget _buildInfoChip({required String label, required String value, required Color color}) {
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
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Products Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first product to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddProduct,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
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
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
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
                color: provider.currentPage > 1 ? const Color(0xFF7C3AED) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Page ${provider.currentPage} of ${provider.totalPages}',
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
  }

  void _applyFilters() {
    final provider = Provider.of<ProductProvider>(context, listen: false);

    // Safe parsing helper
    int? safeParseInt(String? value) {
      if (value == null || value.isEmpty) return null;
      return int.tryParse(value);
    }

    provider.fetchProducts(
      categoryId: safeParseInt(_selectedCategory),
      supplierId: safeParseInt(_selectedSupplier),
      unitId: safeParseInt(_selectedUnit),
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

    final provider = Provider.of<ProductProvider>(context, listen: false);
    provider.fetchProducts(refresh: true);
  }

  void _refreshProducts() {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    provider.fetchProducts(refresh: true);
  }

  void _navigateToProductDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: id),
      ),
    );
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditProductScreen(),
      ),
    ).then((refresh) {
      if (refresh == true) {
        _refreshProducts();
      }
    });
  }

  void _showBulkOperations() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildBulkOperationsSheet(),
    );
  }

  Widget _buildBulkOperationsSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bulk Operations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 20),
          _buildBulkOperationTile(
            icon: Icons.download,
            title: 'Export Products',
            subtitle: 'Download products list as CSV or Excel',
            onTap: () => _exportProducts(),
          ),
          _buildBulkOperationTile(
            icon: Icons.upload,
            title: 'Import Products',
            subtitle: 'Upload CSV file to add multiple products',
            onTap: () => _importProducts(),
          ),
          _buildBulkOperationTile(
            icon: Icons.price_change,
            title: 'Bulk Price Update',
            subtitle: 'Update prices for multiple products',
            onTap: () => _bulkPriceUpdate(),
          ),
          _buildBulkOperationTile(
            icon: Icons.inventory,
            title: 'Bulk Stock Update',
            subtitle: 'Update quantities for multiple products',
            onTap: () => _bulkStockUpdate(),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkOperationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF7C3AED)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _exportProductsAsPdf() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final products = productProvider.products;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate stats
    final stats = {
      'total': products.length,
      'low_stock': products.where((p) => p.physicalQty <= p.minStock).length,
      'active': products.where((p) => p.isActive).length,
      'inactive': products.where((p) => !p.isActive).length,
    };

    // Get filter information safely
    String? categoryName;
    if (_selectedCategory != null) {
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final category = categoryProvider.categories.firstWhere(
            (c) => c.id.toString() == _selectedCategory,
        orElse: () => Category(
          id: '0',
          name: 'Unknown',
          createdAt: DateTime.now(), // Provide a default DateTime
          updatedAt: DateTime.now(), // Provide a default DateTime
        ),
      );
      categoryName = category.name;
    }

    String? supplierName;
    if (_selectedSupplier != null) {
      final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
      final supplier = supplierProvider.suppliers.firstWhere(
            (s) => s.id.toString() == _selectedSupplier,
        orElse: () => Supplier(
          id: 0,
          name: 'Unknown',
          contact: '', // Use empty string instead of null if contact is required
          isActive: true, // Provide a default boolean
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          discountPercent: 0.0, // Provide a default double
        ),
      );
      supplierName = supplier.name;
    }

    String? unitName;
    if (_selectedUnit != null) {
      final unitProvider = Provider.of<UnitProvider>(context, listen: false);
      final unit = unitProvider.units.firstWhere(
            (u) => u.id.toString() == _selectedUnit,
        orElse: () => Unit(
          id: '0',
          name: 'Unknown',
          symbol: '',
          type: '',
          isActive: true,
          conversionFactor: 1.0, // Provide a default double
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      unitName = unit.name;
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
        products: products,
        filterInfo: filterInfo,
        stats: stats,
      );

      if (mounted) Navigator.pop(context);

      _showPrintOptions(pdfData, 'products_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _showPrintOptions(Uint8List pdfData, String filename) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Export Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPrintOption(
                    icon: Icons.picture_as_pdf,
                    label: 'Save PDF',
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.pop(ctx);
                      ProductPdfGenerator.sharePdf(pdfData, filename);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrintOption(
                    icon: Icons.print,
                    label: 'Print',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(ctx);
                      ProductPdfGenerator.printPdf(pdfData);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildPrintOption(
                icon: Icons.visibility,
                label: 'Preview',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPdfPreview(pdfData);
                },
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (_) => pdfData,
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Products'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFF7C3AED)),
              ),
              title: const Text('PDF Document'),
              subtitle: const Text('Export with filters and formatting'),
              onTap: () {
                Navigator.pop(context);
                _exportProductsAsPdf();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart, color: Colors.green),
              ),
              title: const Text('CSV File'),
              subtitle: const Text('Export as spreadsheet data'),
              onTap: () => _exportAs('csv'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.grid_on, color: Colors.blue),
              ),
              title: const Text('Excel File'),
              subtitle: const Text('Export as Excel spreadsheet'),
              onTap: () => _exportAs('excel'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportAs(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting as $format...')),
    );
    Navigator.pop(context);
  }

  void _exportProducts() {
    _showExportOptions();
  }

  void _importProducts() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality coming soon...')),
    );
  }

  void _bulkPriceUpdate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk price update coming soon...')),
    );
  }

  void _bulkStockUpdate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk stock update coming soon...')),
    );
  }
}