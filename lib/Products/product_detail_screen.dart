import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:irfan_iron_merchant_local/Products/product_images_screen.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/product_provider.dart';
import '../Customers/customer_price_screen.dart';
import '../components/error_widget.dart';
import '../components/loading_indicator.dart';
import '../models/customer_price_model.dart';
import '../models/product_image_model.dart';
import '../models/product_model.dart';
import '../providers/CustomerPriceProvider.dart';
import '../providers/product_image_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/purchase_order_provider.dart';
import 'add_edit_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final productProvider =
    Provider.of<ProductProvider>(context, listen: false);
    final imageProvider =
    Provider.of<ProductImageProvider>(context, listen: false);
    final priceProvider =
    Provider.of<CustomerPriceProvider>(context, listen: false);

    await Future.wait([
      productProvider.fetchProductById(widget.productId),
      imageProvider.fetchProductImages(widget.productId),
      priceProvider.fetchPrices(productId: widget.productId),
    ]);
  }

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
        title: const Text(
          'Product Details',
          style: TextStyle(
              color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF7C3AED)),
            onPressed: _editProduct,
          ),
          IconButton(
            icon:
            const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
            onPressed: _deleteProduct,
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const LoadingIndicator();

          if (provider.errorMessage != null) {
            return CustomErrorWidget(
              message: provider.errorMessage!,
              onRetry: _loadProduct,
            );
          }

          if (provider.selectedProduct == null) {
            return const Center(child: Text('Product not found'));
          }

          final product = provider.selectedProduct!;

          return Column(
            children: [
              _buildHeader(product),
              _buildTabBar(),
              Expanded(child: _buildTabContent(product)),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(ProductModel product) {
    final formatter = NumberFormat.currency(symbol: '\$');
    final isLowStock = product.physicalQty <= product.minStock;

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.inventory_2,
                    color: Color(0xFF7C3AED), size: 40),
              ),
              const SizedBox(width: 20),
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
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142)),
                          ),
                        ),
                        // Active badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: product.isActive
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                                color: product.isActive
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Barcode row
                    if (product.barcode != null)
                      Row(
                        children: [
                          Icon(Icons.qr_code,
                              size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text('Barcode: ${product.barcode}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14)),
                        ],
                      ),
                    // Multi-length badge
                    if (product.hasMultipleLengths) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                          const Color(0xFF7C3AED).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF7C3AED)
                                  .withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.straighten,
                                size: 13, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 5),
                            Text(
                              '${product.lengthCombinations?.length ?? 0} lengths',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w600),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoBox(
                  'Stock Quantity',
                  '${product.physicalQty} ${product.unit?.symbol ?? ''}',
                  isLowStock ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoBox('Cost Price',
                    formatter.format(product.costPrice),
                    const Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoBox('Sale Price',
                    formatter.format(product.salePrice),
                    const Color(0xFFF59E0B)),
              ),
            ],
          ),
          if (isLowStock) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFF6B6B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Low stock alert! Minimum stock level is ${product.minStock}',
                      style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: _showUpdateStockDialog,
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6B6B)),
                    child: const Text('Update Stock'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  // ─── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final product = Provider.of<ProductProvider>(context).selectedProduct;
    final hasBom = product?.isBom ?? false;

    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('Details', 0),
          _buildTab('Images', 1),
          _buildTab('Prices', 2),
          if (hasBom) _buildTab('BOM', 4), // Add BOM tab for BOM products
          _buildTab('History', 3),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF7C3AED)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
              isSelected ? const Color(0xFF7C3AED) : Colors.grey,
              fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ProductModel product) {
    switch (_selectedTab) {
      case 0:
        return _buildDetailsTab(product);
      case 1:
        return _buildImagesTab(product);
      case 2:
        return _buildCustomerPricesTab(product);
      case 3:
        return ProductHistoryTab(productId: widget.productId);
      case 4:
        return _buildBomTab(product);
      default:
        return _buildDetailsTab(product);
    }
  }

  // ─── Details Tab ──────────────────────────────────────────────────────────

  Widget _buildDetailsTab(ProductModel product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection('Basic Information', [
            _buildInfoRow('Product Name', product.itemName),
            _buildInfoRow(
                'Description', product.description ?? 'No description'),
            _buildInfoRow('Category', product.category?.name ?? 'N/A'),
            _buildInfoRow(
                'Subcategory', product.subcategory?.name ?? 'N/A'),
            _buildInfoRow('Unit',
                '${product.unit?.name ?? 'N/A'} (${product.unit?.symbol ?? ''})'),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('Pricing & Stock', [
            _buildInfoRow('Cost Price',
                NumberFormat.currency(symbol: '\$').format(product.costPrice)),
            _buildInfoRow('Sale Price',
                NumberFormat.currency(symbol: '\$').format(product.salePrice)),
            _buildInfoRow(
              'Profit Margin',
              product.costPrice > 0
                  ? '${((product.salePrice - product.costPrice) / product.costPrice * 100).toStringAsFixed(1)}%'
                  : 'N/A',
            ),
            _buildInfoRow(
                'Physical Quantity', product.physicalQty.toString()),
            _buildInfoRow(
                'Available Quantity', product.availableQty.toString()),
            _buildInfoRow('Minimum Stock', product.minStock.toString()),
          ]),
          const SizedBox(height: 20),
          // ── Length Combinations section ──────────────────────────────────
          if (product.hasMultipleLengths &&
              product.lengthCombinations != null &&
              product.lengthCombinations!.isNotEmpty) ...[
            _buildLengthCombinationsSection(product),
            const SizedBox(height: 20),
          ],
          _buildInfoSection('Supplier Information', [
            _buildInfoRow(
                'Supplier', product.supplier?.name ?? 'No supplier'),
            _buildInfoRow('Contact', product.supplier?.contact ?? 'N/A'),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('System Information', [
            _buildInfoRow('Created At',
                DateFormat('MMM dd, yyyy HH:mm').format(product.createdAt)),
            _buildInfoRow('Last Updated',
                DateFormat('MMM dd, yyyy HH:mm').format(product.updatedAt)),
          ]),
        ],
      ),
    );
  }

  /// Length combinations section shown inside Details tab
  Widget _buildLengthCombinationsSection(ProductModel product) {
    final combinations = product.lengthCombinations!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Icon(Icons.straighten,
                  size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              const Text(
                'Length Combinations',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${combinations.length} total',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grid of length chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: combinations.asMap().entries.map((entry) {
              final index = entry.key;
              final combo = entry.value;
              return _buildLengthChip(index + 1, combo);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLengthChip(int number, LengthCombination combo) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF7C3AED).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Index bubble
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF7C3AED),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                combo.length,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF2D3142)),
              ),
              if (combo.lengthDecimal.isNotEmpty)
                Text(
                  '= ${combo.lengthDecimal}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142))),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3142))),
          ),
        ],
      ),
    );
  }

  // ─── Images Tab ───────────────────────────────────────────────────────────

  void _navigateToImagesScreen(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductImagesScreen(
          productId: product.id,
          productName: product.itemName,
        ),
      ),
    ).then((_) {
      Provider.of<ProductImageProvider>(context, listen: false)
          .fetchProductImages(product.id);
    });
  }

  void _showFullScreenImage(ProductImage image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(image.imageUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon:
                const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesTab(ProductModel product) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton.icon(
            onPressed: () => _navigateToImagesScreen(product),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Manage Images'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Expanded(
          child: Consumer<ProductImageProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final images = provider.getImagesForProduct(product.id);

              if (images.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No images yet',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Add images to showcase your product',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final image = images[index];
                  return GestureDetector(
                    onTap: () => _showFullScreenImage(image),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(image.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity),
                        ),
                        if (image.isPrimary)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Color(0xFF7C3AED),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.star,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Customer Prices Tab ──────────────────────────────────────────────────

  Widget _summaryTile(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142))),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _summaryDivider() =>
      Container(width: 1, height: 36, color: const Color(0xFFE5E7EB));

  Widget _buildCompactPriceRow(
      CustomerPriceModel price, ProductModel product) {
    final discount = product.salePrice > 0
        ? ((product.salePrice - price.price) / product.salePrice * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: price.isActive
              ? const Color(0xFFF0F0F5)
              : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
            const Color(0xFF7C3AED).withOpacity(0.1),
            child: Text(
              (price.customer?.name ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.customer?.name ?? 'Unknown',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: price.isActive
                          ? const Color(0xFF2D3142)
                          : Colors.grey),
                ),
                Text(price.customer?.customerType ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(symbol: '\$').format(price.price),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF7C3AED)),
              ),
              if (discount != 0)
                Text(
                  discount > 0
                      ? '-${discount.toStringAsFixed(1)}%'
                      : '+${(-discount).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: discount > 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPricesTab(ProductModel product) {
    return Consumer<CustomerPriceProvider>(
      builder: (context, priceProvider, _) {
        if (priceProvider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF7C3AED)));
        }

        final prices = priceProvider.pricesForProduct(product.id);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer-specific Prices',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142))),
                        SizedBox(height: 2),
                        Text(
                            'Override the standard sale price per customer',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToCustomerPrices(product.id),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Manage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            if (prices.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _summaryTile('Total', prices.length.toString(),
                        Icons.list_alt),
                    _summaryDivider(),
                    _summaryTile(
                        'Active',
                        prices
                            .where((p) => p.isActive)
                            .length
                            .toString(),
                        Icons.check_circle_outline),
                    _summaryDivider(),
                    _summaryTile(
                      'Avg Price',
                      NumberFormat.currency(symbol: '\$').format(
                          prices.isEmpty
                              ? 0
                              : prices.fold(
                              0.0, (s, p) => s + p.price) /
                              prices.length),
                      Icons.attach_money,
                    ),
                  ],
                ),
              ),
            if (prices.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.price_change_outlined,
                          size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No custom prices yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text(
                          'Tap Manage to add customer-specific pricing',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400])),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _navigateToCustomerPrices(product.id),
                        icon: const Icon(Icons.add,
                            color: Color(0xFF7C3AED)),
                        label: const Text('Add Price',
                            style: TextStyle(
                                color: Color(0xFF7C3AED))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF7C3AED)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding:
                  const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    ...prices.take(5).map(
                            (price) =>
                            _buildCompactPriceRow(price, product)),
                    if (prices.length > 5) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              _navigateToCustomerPrices(product.id),
                          child: Text(
                              'View all ${prices.length} prices →',
                              style: const TextStyle(
                                  color: Color(0xFF7C3AED))),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBomTab(ProductModel product) {
    if (!product.isBom) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Not a BOM Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'This product is not configured as a Bill of Materials',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _editProduct(),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Product'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
      );
    }

    if (product.bomComponents == null || product.bomComponents!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_outlined, size: 64, color: Colors.orange[400]),
            const SizedBox(height: 16),
            Text(
              'No Components Added',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'This BOM product has no components configured',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final totalCost = product.bomTotalCost ?? _calculateBomTotalCost(product.bomComponents!);
    final suggestedPrice30 = totalCost * 1.3;
    final suggestedPrice50 = totalCost * 1.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BOM Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BOM Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${product.bomComponents!.length} Components',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildBomSummaryItem(
                        'Total Cost',
                        NumberFormat.currency(symbol: 'PKR ').format(totalCost),
                        Icons.calculate,
                        Colors.white,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildBomSummaryItem(
                        'Current Sale Price',
                        NumberFormat.currency(symbol: 'PKR ').format(product.salePrice),
                        Icons.price_change,
                        Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Suggested Selling Prices',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '30% Margin: ${NumberFormat.currency(symbol: 'PKR ').format(suggestedPrice30)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                Text(
                                  '50% Margin: ${NumberFormat.currency(symbol: 'PKR ').format(suggestedPrice50)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Components List
          const Text(
            'Components',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: product.bomComponents!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final component = product.bomComponents![index];
              return _buildBomComponentCard(component, index + 1);
            },
          ),

          const SizedBox(height: 20),

          // Manufacturing Cost Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manufacturing Cost Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                const SizedBox(height: 12),
                ...product.bomComponents!.map((comp) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${comp.productName} x${comp.quantity.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        NumberFormat.currency(symbol: 'PKR ').format(comp.totalCost),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Manufacturing Cost:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      NumberFormat.currency(symbol: 'PKR ').format(totalCost),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBomSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildBomComponentCard(BomComponent component, int number) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FB),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  component.productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${component.quantity.toStringAsFixed(2)} ${component.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildComponentDetail(
                  'Unit Cost',
                  NumberFormat.currency(symbol: 'PKR ').format(component.costPerUnit),
                  Icons.attach_money,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: const Color(0xFFE0E0E8),
              ),
              Expanded(
                child: _buildComponentDetail(
                  'Total Cost',
                  NumberFormat.currency(symbol: 'PKR ').format(component.totalCost),
                  Icons.calculate,
                ),
              ),
            ],
          ),
          if (component.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      component.notes!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComponentDetail(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }

  double _calculateBomTotalCost(List<BomComponent> components) {
    return components.fold(0.0, (sum, c) => sum + c.totalCost);
  }

  void _navigateToCustomerPrices(int productId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              CustomerPriceScreen(productId: productId)),
    ).then((_) => _loadProduct());
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _editProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddEditProductScreen(productId: widget.productId)),
    ).then((refresh) {
      if (refresh == true) _loadProduct();
    });
  }

  void _deleteProduct() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider =
              Provider.of<ProductProvider>(context, listen: false);
              final result =
              await provider.deleteProduct(widget.productId);
              if (result['success'] && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                        Text('Product deleted successfully')));
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['error'] ??
                        'Failed to delete product')));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showUpdateStockDialog() {
    final quantityController = TextEditingController();
    String operation = 'add';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: operation,
                items: const [
                  DropdownMenuItem(
                      value: 'add', child: Text('Add Stock')),
                  DropdownMenuItem(
                      value: 'subtract',
                      child: Text('Remove Stock')),
                  DropdownMenuItem(
                      value: 'set', child: Text('Set Quantity')),
                ],
                onChanged: (value) =>
                    setState(() => operation = value!),
                decoration: const InputDecoration(
                    labelText: 'Operation',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (quantityController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter quantity')));
                  return;
                }
                final quantity =
                int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Please enter a valid quantity')));
                  return;
                }
                Navigator.pop(context);
                final provider = Provider.of<ProductProvider>(
                    context,
                    listen: false);
                final result =
                await provider.updateProductQuantity(
                    widget.productId, quantity, operation);
                if (result['success'] && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                      Text(result['data']['message'] ?? 'Updated')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result['error'] ??
                          'Failed to update stock')));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED)),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PRODUCT HISTORY TAB  (unchanged — kept in same file)
// ═══════════════════════════════════════════════════════════════════════════════

class _SaleRecord {
  final int id;
  final String invoiceNumber;
  final String saleType;
  final DateTime date;
  final String? customerName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String paymentStatus;
  final String paymentMethod;

  _SaleRecord({
    required this.id,
    required this.invoiceNumber,
    required this.saleType,
    required this.date,
    this.customerName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.paymentStatus,
    required this.paymentMethod,
  });

  factory _SaleRecord.fromJson(Map<String, dynamic> json) => _SaleRecord(
    id: json['id'],
    invoiceNumber: json['invoice_number'] ?? '',
    saleType: json['sale_type'] ?? 'pos',
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    customerName: json['customer']?['name'],
    quantity: json['quantity'] ?? 0,
    unitPrice: double.tryParse('${json['unit_price']}') ?? 0,
    totalPrice: double.tryParse('${json['total_price']}') ?? 0,
    paymentStatus: json['payment_status'] ?? '',
    paymentMethod: json['payment_method'] ?? '',
  );
}

class _PurchaseRecord {
  final int id;
  final String receiptNumber;
  final String? poNumber;
  final DateTime date;
  final String? supplierName;
  final int quantityReceived;
  final double unitCost;
  final double totalCost;
  final String? batchNumber;
  final DateTime? expiryDate;
  final String status;

  _PurchaseRecord({
    required this.id,
    required this.receiptNumber,
    this.poNumber,
    required this.date,
    this.supplierName,
    required this.quantityReceived,
    required this.unitCost,
    required this.totalCost,
    this.batchNumber,
    this.expiryDate,
    required this.status,
  });

  factory _PurchaseRecord.fromJson(Map<String, dynamic> json) =>
      _PurchaseRecord(
        id: json['id'],
        receiptNumber: json['receipt_number'] ?? '',
        poNumber: json['po_number'],
        date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
        supplierName: json['supplier']?['name'],
        quantityReceived: json['quantity_received'] ?? 0,
        unitCost: double.tryParse('${json['unit_cost']}') ?? 0,
        totalCost: double.tryParse('${json['total_cost']}') ?? 0,
        batchNumber: json['batch_number'],
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'])
            : null,
        status: json['status'] ?? '',
      );
}

class ProductHistoryTab extends StatefulWidget {
  final int productId;
  const ProductHistoryTab({super.key, required this.productId});

  @override
  State<ProductHistoryTab> createState() => _ProductHistoryTabState();
}

class _ProductHistoryTabState extends State<ProductHistoryTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_SaleRecord> _sales = [];
  List<_PurchaseRecord> _purchases = [];
  bool _isLoading = true;
  String? _error;

  final _currency = NumberFormat.currency(symbol: 'Rs ');
  final _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/products/${widget.productId}/history');
      final response = await http.get(
          uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody['success'] == true) {
          final data = jsonBody['data'];
          setState(() {
            _sales = (data['sale_history'] as List? ?? [])
                .map((e) => _SaleRecord.fromJson(e))
                .toList();
            _purchases = (data['purchase_history'] as List? ?? [])
                .map((e) => _PurchaseRecord.fromJson(e))
                .toList();
          });
        } else {
          setState(() =>
          _error = jsonBody['message'] ?? 'Failed to load history');
        }
      } else {
        setState(() => _error = 'Server error ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child:
          CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Color(0xFFFF6B6B)),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side:
                  const BorderSide(color: Color(0xFF7C3AED))),
            ),
          ],
        ),
      );
    }

    final totalSold =
    _sales.fold<int>(0, (s, r) => s + r.quantity);
    final totalRevenue =
    _sales.fold<double>(0, (s, r) => s + r.totalPrice);
    final totalReceived =
    _purchases.fold<int>(0, (s, r) => s + r.quantityReceived);
    final totalCost =
    _purchases.fold<double>(0, (s, r) => s + r.totalCost);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _summaryItem(Icons.sell_outlined,
                  '${_sales.length}', 'Sales', Colors.white),
              _vertDivider(),
              _summaryItem(
                  Icons.attach_money,
                  _currency.format(totalRevenue),
                  'Revenue ($totalSold units)',
                  Colors.white),
              _vertDivider(),
              _summaryItem(Icons.inventory_2_outlined,
                  '${_purchases.length}', 'Receipts', Colors.white),
              _vertDivider(),
              _summaryItem(
                  Icons.shopping_cart_outlined,
                  _currency.format(totalCost),
                  'Purchased ($totalReceived units)',
                  Colors.white),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF6B7280),
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicator: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            padding: const EdgeInsets.all(4),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sell_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Sales (${_sales.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Purchases (${_purchases.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSalesTab(),
              _buildPurchasesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTab() {
    if (_sales.isEmpty) {
      return _buildEmpty(Icons.sell_outlined, 'No sales recorded yet',
          'Sales of this product will appear here');
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _sales.length,
        itemBuilder: (ctx, i) => _buildSaleCard(_sales[i]),
      ),
    );
  }

  Widget _buildSaleCard(_SaleRecord sale) {
    final isPaid = sale.paymentStatus == 'paid';
    final isCredit = sale.paymentMethod == 'credit';
    final isInvoice = sale.saleType == 'invoice';
    final statusColor = isPaid
        ? const Color(0xFF10B981)
        : sale.paymentStatus == 'partial'
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isInvoice
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInvoice
                            ? Icons.receipt_long_outlined
                            : Icons.point_of_sale,
                        size: 12,
                        color: isInvoice
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isInvoice ? 'Invoice' : 'POS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isInvoice
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF7C3AED)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(sale.invoiceNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF2D3142))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sale.paymentStatus.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _infoChip(
                      Icons.person_outline,
                      sale.customerName ?? 'Walk-in',
                      const Color(0xFF6B7280)),
                ),
                const SizedBox(width: 8),
                _infoChip(
                    Icons.calendar_today_outlined,
                    _dateFormat.format(sale.date),
                    const Color(0xFF6B7280)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFC),
                borderRadius: BorderRadius.circular(8),
                border:
                Border.all(color: const Color(0xFFF0F0F5)),
              ),
              child: Row(
                children: [
                  _amountCell('Qty', '${sale.quantity}',
                      const Color(0xFF2D3142)),
                  _amountDivider(),
                  _amountCell('Unit Price',
                      _currency.format(sale.unitPrice),
                      const Color(0xFF7C3AED)),
                  _amountDivider(),
                  _amountCell('Total',
                      _currency.format(sale.totalPrice),
                      const Color(0xFF10B981)),
                  if (isCredit) ...[
                    _amountDivider(),
                    _amountCell(
                        'Method', 'Credit', const Color(0xFFEF4444)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasesTab() {
    if (_purchases.isEmpty) {
      return _buildEmpty(
          Icons.inventory_2_outlined,
          'No purchase receipts yet',
          'Stock received for this product will appear here');
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _purchases.length,
        itemBuilder: (ctx, i) => _buildPurchaseCard(_purchases[i]),
      ),
    );
  }

  Widget _buildPurchaseCard(_PurchaseRecord purchase) {
    final isExpired = purchase.expiryDate != null &&
        purchase.expiryDate!.isBefore(DateTime.now());
    final expiringSoon = purchase.expiryDate != null &&
        !isExpired &&
        purchase.expiryDate!
            .isBefore(DateTime.now().add(const Duration(days: 30)));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.move_to_inbox,
                          size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text('Receipt',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(purchase.receiptNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF2D3142))),
                ),
                if (purchase.poNumber != null)
                  Text(purchase.poNumber!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _infoChip(
                      Icons.business_outlined,
                      purchase.supplierName ?? 'Unknown Supplier',
                      const Color(0xFF6B7280)),
                ),
                const SizedBox(width: 8),
                _infoChip(
                    Icons.calendar_today_outlined,
                    _dateFormat.format(purchase.date),
                    const Color(0xFF6B7280)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFC),
                borderRadius: BorderRadius.circular(8),
                border:
                Border.all(color: const Color(0xFFF0F0F5)),
              ),
              child: Row(
                children: [
                  _amountCell('Received',
                      '${purchase.quantityReceived}',
                      const Color(0xFF2D3142)),
                  _amountDivider(),
                  _amountCell('Unit Cost',
                      _currency.format(purchase.unitCost),
                      const Color(0xFF7C3AED)),
                  _amountDivider(),
                  _amountCell('Total Cost',
                      _currency.format(purchase.totalCost),
                      const Color(0xFF10B981)),
                ],
              ),
            ),
            if (purchase.batchNumber != null ||
                purchase.expiryDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (purchase.batchNumber != null) ...[
                    const Icon(Icons.qr_code,
                        size: 13, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text('Batch: ${purchase.batchNumber}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280))),
                    const SizedBox(width: 12),
                  ],
                  if (purchase.expiryDate != null) ...[
                    Icon(Icons.event_busy_outlined,
                        size: 13,
                        color: isExpired
                            ? const Color(0xFFEF4444)
                            : expiringSoon
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text(
                      'Exp: ${_dateFormat.format(purchase.expiryDate!)}'
                          '${isExpired ? ' ⚠ Expired' : expiringSoon ? ' ⚠ Soon' : ''}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isExpired
                              ? const Color(0xFFEF4444)
                              : expiringSoon
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF6B7280),
                          fontWeight:
                          (isExpired || expiringSoon)
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(
      IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 6),
          Text(subtitle,
              style:
              TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _summaryItem(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.8)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color.withOpacity(0.7)),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Colors.white.withOpacity(0.3),
  );

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: color),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _amountCell(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFF9CA3AF)),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _amountDivider() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: const Color(0xFFE5E7EB),
  );
}