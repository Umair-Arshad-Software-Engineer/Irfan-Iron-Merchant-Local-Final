// lib/screens/customer_prices/customer_price_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/customer_price_model.dart';
import '../providers/CustomerPriceProvider.dart';

class CustomerPriceScreen extends StatefulWidget {
  final int? productId;
  final int? customerId;

  const CustomerPriceScreen({super.key, this.productId, this.customerId})
      : assert(productId != null || customerId != null,
  'Provide either productId or customerId');

  @override
  State<CustomerPriceScreen> createState() => _CustomerPriceScreenState();
}

class _CustomerPriceScreenState extends State<CustomerPriceScreen> {
  final _formatter = NumberFormat.currency(symbol: '\$');
  bool _isLoadingCustomers = false;
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    // Load customers if we're in product view (need customers dropdown)
    if (widget.productId != null) {
      await _loadCustomers();
    }

    // Load products if we're in customer view (need products dropdown)
    if (widget.customerId != null) {
      await _loadProducts();
    }

    // Load prices
    await _loadPrices();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final customerProvider = context.read<CustomerProvider>();
      // Check if customers are already loaded
      if (customerProvider.customers.isEmpty) {
        await customerProvider.fetchCustomers();
      }
    } catch (e) {
      debugPrint('Error loading customers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final productProvider = context.read<ProductProvider>();
      // Check if products are already loaded
      if (productProvider.products.isEmpty) {
        await productProvider.fetchProducts();
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<void> _loadPrices() async {
    final provider = context.read<CustomerPriceProvider>();
    await provider.fetchPrices(
      productId: widget.productId,
      customerId: widget.customerId,
    );
  }

  bool get _byProduct => widget.productId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _byProduct ? 'Customer Prices for Product' : 'Product Prices for Customer',
          style: const TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSetPriceDialog,
        label: const Text('Add / Update Price'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF7C3AED),
      ),
      body: Consumer<CustomerPriceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Color(0xFFFF6B6B)),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFF6B6B))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadInitialData,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final prices = _byProduct
              ? provider.pricesForProduct(widget.productId!)
              : provider.pricesForCustomer(widget.customerId!);

          if (prices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.price_change_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No custom prices set',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _byProduct
                        ? 'Set special prices for specific customers'
                        : 'Set special prices for specific products',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showSetPriceDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Price'),
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

          return RefreshIndicator(
            onRefresh: _loadInitialData,
            color: const Color(0xFF7C3AED),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: prices.length,
              itemBuilder: (context, index) => _buildPriceCard(prices[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceCard(CustomerPriceModel price) {
    final title = _byProduct ? price.customer?.name ?? 'Unknown' : price.product?.itemName ?? 'Unknown';
    final subtitle = _byProduct
        ? 'Type: ${price.customer?.customerType ?? 'N/A'}'
        : 'Unit: ${price.product?.unit?.symbol ?? 'N/A'}';
    final standardPrice = price.product?.salePrice;
    final discount = standardPrice != null && standardPrice > 0
        ? ((standardPrice - price.price) / standardPrice * 100)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: price.isActive ? const Color(0xFFF0F0F5) : Colors.grey.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: price.isActive
                    ? const Color(0xFF7C3AED).withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _byProduct ? Icons.person : Icons.inventory_2,
                color: price.isActive ? const Color(0xFF7C3AED) : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: price.isActive ? const Color(0xFF2D3142) : Colors.grey,
                          ),
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: price.isActive
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          price.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: price.isActive ? const Color(0xFF10B981) : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPriceChip(
                        label: 'Custom',
                        value: _formatter.format(price.price),
                        color: const Color(0xFF7C3AED),
                      ),
                      if (standardPrice != null)
                        _buildPriceChip(
                          label: 'Standard',
                          value: _formatter.format(standardPrice),
                          color: Colors.grey,
                        ),
                      if (discount != null && discount != 0)
                        _buildPriceChip(
                          label: discount > 0 ? 'Discount' : 'Markup',
                          value: '${discount.abs().toStringAsFixed(1)}%',
                          color: discount > 0 ? const Color(0xFF10B981) : const Color(0xFFFF6B6B),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (action) => _handleAction(action, price),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFF7C3AED)),
                    SizedBox(width: 10),
                    Text('Edit Price'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(
                      price.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                      size: 18,
                      color: price.isActive ? Colors.orange : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    Text(price.isActive ? 'Deactivate' : 'Activate'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF6B6B)),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChip({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.7), fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(String action, CustomerPriceModel price) {
    switch (action) {
      case 'edit':
        _showSetPriceDialog(existing: price);
        break;
      case 'toggle':
        _toggleStatus(price);
        break;
      case 'delete':
        _confirmDelete(price);
        break;
    }
  }

  Future<void> _toggleStatus(CustomerPriceModel price) async {
    final result = await context.read<CustomerPriceProvider>().toggleStatus(price.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] ? result['message'] : result['message']),
          backgroundColor: result['success'] ? const Color(0xFF10B981) : const Color(0xFFFF6B6B),
        ),
      );
    }
  }

  void _confirmDelete(CustomerPriceModel price) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Price'),
        content: Text(
          'Remove the custom price for '
              '${_byProduct ? price.customer?.name : price.product?.itemName}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            onPressed: () async {
              Navigator.pop(context);
              final result =
              await context.read<CustomerPriceProvider>().deleteCustomerPrice(price.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: result['success'] ? const Color(0xFF10B981) : const Color(0xFFFF6B6B),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSetPriceDialog({CustomerPriceModel? existing}) {
    int? selectedCustomerId = existing?.customerId ?? widget.customerId;
    int? selectedProductId = existing?.productId ?? widget.productId;
    final priceController = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.price_change, color: Color(0xFF7C3AED)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      existing == null ? 'Set Custom Price' : 'Edit Custom Price',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Loading indicator for customers
                if (_byProduct && _isLoadingCustomers)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
                  ),

                // Customer selector with search
                if (_byProduct && !_isLoadingCustomers) ...[
                  const Text('Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  Consumer<CustomerProvider>(
                    builder: (_, customerProvider, __) {
                      if (customerProvider.customers.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.orange),
                                const SizedBox(height: 8),
                                Text(
                                  'No customers available',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _loadCustomers,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildSearchableDropdown<int>(
                        selectedValue: selectedCustomerId,
                        items: customerProvider.customers,
                        itemToString: (c) => c.name,
                        itemToValue: (c) => c.id,
                        hint: 'Search and select customer...',
                        onChanged: existing == null
                            ? (value) => setDialogState(() => selectedCustomerId = value)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Loading indicator for products
                if (!_byProduct && _isLoadingProducts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
                  ),

                // Product selector with search
                if (!_byProduct && !_isLoadingProducts) ...[
                  const Text('Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  Consumer<ProductProvider>(
                    builder: (_, productProvider, __) {
                      if (productProvider.products.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.orange),
                                const SizedBox(height: 8),
                                Text(
                                  'No products available',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _loadProducts,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildSearchableDropdown<int>(
                        selectedValue: selectedProductId,
                        items: productProvider.products,
                        itemToString: (p) => p.itemName,
                        itemToValue: (p) => p.id,
                        hint: 'Search and select product...',
                        onChanged: existing == null
                            ? (value) => setDialogState(() => selectedProductId = value)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Price field
                const Text('Custom Price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final price = double.tryParse(priceController.text.trim());
                          if (price == null || price < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid price')),
                            );
                            return;
                          }
                          if (selectedCustomerId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a customer')),
                            );
                            return;
                          }
                          if (selectedProductId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a product')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          final result = await context.read<CustomerPriceProvider>().setCustomerPrice(
                            customerId: selectedCustomerId!,
                            productId: selectedProductId!,
                            price: price,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? ''),
                                backgroundColor: result['success']
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFFF6B6B),
                              ),
                            );
                          }
                        },
                        child: Text(existing == null ? 'Set Price' : 'Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Custom searchable dropdown widget
  Widget _buildSearchableDropdown<T>({
    required T? selectedValue,
    required List<dynamic> items,
    required String Function(dynamic) itemToString,
    required T Function(dynamic) itemToValue,
    required String hint,
    required void Function(T?)? onChanged,
  }) {
    final searchController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setState) {
        final filteredItems = _getFilteredItems(items, searchController.text);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),

            const SizedBox(height: 8),

            // Results list
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: filteredItems.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      searchController.text.isEmpty
                          ? 'No items available'
                          : 'No results found',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredItems.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // "None" option
                      return _buildDropdownItem(
                        label: 'None',
                        isSelected: selectedValue == null,
                        onTap: onChanged != null ? () => onChanged(null) : null,
                      );
                    }

                    final item = filteredItems[index - 1];
                    final isSelected = selectedValue == itemToValue(item);

                    return _buildDropdownItem(
                      label: itemToString(item),
                      isSelected: isSelected,
                      onTap: onChanged != null ? () => onChanged(itemToValue(item)) : null,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<dynamic> _getFilteredItems(List<dynamic> items, String query) {
    if (query.isEmpty) return items;
    return items.where((item) {
      final name = itemToStringForSearch(item);
      return name.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  String itemToStringForSearch(dynamic item) {
    if (item is Map) {
      return item['name']?.toString() ?? item.toString();
    }
    // Try to access name property if it exists
    try {
      final name = item.name;
      if (name != null) return name.toString();
    } catch (e) {
      // Ignore, fallback to toString
    }
    return item.toString();
  }

  Widget _buildDropdownItem({
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.1) : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF2D3142),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 18, color: Color(0xFF7C3AED)),
          ],
        ),
      ),
    );
  }
}