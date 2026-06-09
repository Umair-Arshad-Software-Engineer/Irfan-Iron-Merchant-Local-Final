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
import '../providers/lanprovider.dart';
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
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
              languageProvider.isEnglish ? 'Product Details' : 'پروڈکٹ کی تفصیلات',
              style: const TextStyle(
                  color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF7C3AED)),
                onPressed: _editProduct,
                tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                onPressed: _deleteProduct,
                tooltip: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
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
                return Center(
                  child: Text(
                    languageProvider.isEnglish ? 'Product not found' : 'پروڈکٹ نہیں ملی',
                  ),
                );
              }

              final product = provider.selectedProduct!;

              return Column(
                children: [
                  _buildHeader(product, languageProvider),
                  _buildTabBar(languageProvider),
                  Expanded(child: _buildTabContent(product, languageProvider)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(ProductModel product, LanguageProvider languageProvider) {
    final formatter = NumberFormat.currency(symbol: 'PKR ');
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
                            product.isActive
                                ? (languageProvider.isEnglish ? 'Active' : 'فعال')
                                : (languageProvider.isEnglish ? 'Inactive' : 'غیر فعال'),
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
                    if (product.barcode != null)
                      Row(
                        children: [
                          Icon(Icons.qr_code,
                              size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            '${languageProvider.isEnglish ? 'Barcode' : 'بارکوڈ'}: ${product.barcode}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
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
                              languageProvider.isEnglish
                                  ? '${product.lengthCombinations?.length ?? 0} lengths'
                                  : 'لمبائیاں: ${product.lengthCombinations?.length ?? 0}',
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
                  languageProvider.isEnglish ? 'Stock Quantity' : 'اسٹاک کی مقدار',
                  '${product.physicalQty} ${product.unit?.symbol ?? ''}',
                  isLowStock ? Colors.red : Colors.green,
                  languageProvider,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoBox(
                  languageProvider.isEnglish ? 'Cost Price' : 'لاگت قیمت',
                  formatter.format(product.costPrice),
                  const Color(0xFF7C3AED),
                  languageProvider,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoBox(
                  languageProvider.isEnglish ? 'Sale Price' : 'فروخت قیمت',
                  formatter.format(product.salePrice),
                  const Color(0xFFF59E0B),
                  languageProvider,
                ),
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
                      languageProvider.isEnglish
                          ? 'Low stock alert! Minimum stock level is ${product.minStock}'
                          : 'کم اسٹاک الرٹ! کم از کم اسٹاک لیول ${product.minStock} ہے',
                      style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: _showUpdateStockDialog,
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6B6B)),
                    child: Text(languageProvider.isEnglish ? 'Update Stock' : 'اسٹاک اپ ڈیٹ کریں'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, Color color, LanguageProvider languageProvider) {
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
                  fontWeight: FontWeight.w500,
                  fontFamily: languageProvider.fontFamily)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: languageProvider.fontFamily)),
        ],
      ),
    );
  }

  // ─── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar(LanguageProvider languageProvider) {
    final product = Provider.of<ProductProvider>(context).selectedProduct;
    final hasBom = product?.isBom ?? false;

    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab(languageProvider.isEnglish ? 'Details' : 'تفصیلات', 0, languageProvider),
          _buildTab(languageProvider.isEnglish ? 'Images' : 'تصاویر', 1, languageProvider),
          _buildTab(languageProvider.isEnglish ? 'Prices' : 'قیمتیں', 2, languageProvider),
          if (hasBom) _buildTab(languageProvider.isEnglish ? 'BOM' : 'BOM', 4, languageProvider),
          _buildTab(languageProvider.isEnglish ? 'History' : 'تاریخ', 3, languageProvider),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, LanguageProvider languageProvider) {
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
              color: isSelected ? const Color(0xFF7C3AED) : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontFamily: languageProvider.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ProductModel product, LanguageProvider languageProvider) {
    switch (_selectedTab) {
      case 0:
        return _buildDetailsTab(product, languageProvider);
      case 1:
        return _buildImagesTab(product, languageProvider);
      case 2:
        return _buildCustomerPricesTab(product, languageProvider);
      case 3:
        return ProductHistoryTab(productId: widget.productId);
      case 4:
        return _buildBomTab(product, languageProvider);
      default:
        return _buildDetailsTab(product, languageProvider);
    }
  }

  // ─── Details Tab ──────────────────────────────────────────────────────────

  Widget _buildDetailsTab(ProductModel product, LanguageProvider languageProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            languageProvider.isEnglish ? 'Basic Information' : 'بنیادی معلومات',
            [
              _buildInfoRow(languageProvider.isEnglish ? 'Product Name' : 'پروڈکٹ کا نام', product.itemName, languageProvider),
              _buildInfoRow(
                  languageProvider.isEnglish ? 'Description' : 'تفصیل',
                  product.description ?? (languageProvider.isEnglish ? 'No description' : 'کوئی تفصیل نہیں'),
                  languageProvider),
              _buildInfoRow(languageProvider.isEnglish ? 'Category' : 'کیٹگری', product.category?.name ?? 'N/A', languageProvider),
              _buildInfoRow(
                  languageProvider.isEnglish ? 'Subcategory' : 'ذیلی کیٹگری',
                  product.subcategory?.name ?? 'N/A',
                  languageProvider),
              _buildInfoRow(languageProvider.isEnglish ? 'Unit' : 'یونٹ',
                  '${product.unit?.name ?? 'N/A'} (${product.unit?.symbol ?? ''})',
                  languageProvider),
            ],
            languageProvider,
          ),
          const SizedBox(height: 20),
          _buildInfoSection(
            languageProvider.isEnglish ? 'Pricing & Stock' : 'قیمت اور اسٹاک',
            [
              _buildInfoRow(languageProvider.isEnglish ? 'Cost Price' : 'لاگت قیمت',
                  NumberFormat.currency(symbol: 'PKR ').format(product.costPrice),
                  languageProvider),
              _buildInfoRow(languageProvider.isEnglish ? 'Sale Price' : 'فروخت قیمت',
                  NumberFormat.currency(symbol: 'PKR ').format(product.salePrice),
                  languageProvider),
              _buildInfoRow(
                languageProvider.isEnglish ? 'Profit Margin' : 'منافع کا فیصد',
                product.costPrice > 0
                    ? '${((product.salePrice - product.costPrice) / product.costPrice * 100).toStringAsFixed(1)}%'
                    : 'N/A',
                languageProvider,
              ),
              _buildInfoRow(
                  languageProvider.isEnglish ? 'Physical Quantity' : 'طبعی مقدار',
                  product.physicalQty.toString(),
                  languageProvider),
              _buildInfoRow(
                  languageProvider.isEnglish ? 'Available Quantity' : 'دستیاب مقدار',
                  product.availableQty.toString(),
                  languageProvider),
              _buildInfoRow(
                  languageProvider.isEnglish ? 'Minimum Stock' : 'کم از کم اسٹاک',
                  product.minStock.toString(),
                  languageProvider),
            ],
            languageProvider,
          ),
          const SizedBox(height: 20),
          if (product.hasMultipleLengths &&
              product.lengthCombinations != null &&
              product.lengthCombinations!.isNotEmpty) ...[
            _buildLengthCombinationsSection(product, languageProvider),
            const SizedBox(height: 20),
          ],
          _buildInfoSection(
            languageProvider.isEnglish ? 'Supplier Information' : 'سپلائر کی معلومات',
            [
              _buildInfoRow(
                  languageProvider.isEnglish ? 'Supplier' : 'سپلائر',
                  product.supplier?.name ?? (languageProvider.isEnglish ? 'No supplier' : 'کوئی سپلائر نہیں'),
                  languageProvider),
              _buildInfoRow(
                  languageProvider.isEnglish ? 'Contact' : 'رابطہ',
                  product.supplier?.contact ?? 'N/A',
                  languageProvider),
            ],
            languageProvider,
          ),
          const SizedBox(height: 20),
          _buildInfoSection(
            languageProvider.isEnglish ? 'System Information' : 'سسٹم کی معلومات',
            [
              _buildInfoRow(languageProvider.isEnglish ? 'Created At' : 'بنایا گیا',
                  DateFormat('MMM dd, yyyy HH:mm').format(product.createdAt),
                  languageProvider),
              _buildInfoRow(languageProvider.isEnglish ? 'Last Updated' : 'آخری تازہ کاری',
                  DateFormat('MMM dd, yyyy HH:mm').format(product.updatedAt),
                  languageProvider),
            ],
            languageProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildLengthCombinationsSection(ProductModel product, LanguageProvider languageProvider) {
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
          Row(
            children: [
              const Icon(Icons.straighten,
                  size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Text(
                languageProvider.isEnglish ? 'Length Combinations' : 'لمبائی کے امتزاج',
                style: const TextStyle(
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
                  languageProvider.isEnglish
                      ? '${combinations.length} total'
                      : 'کل: ${combinations.length}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: combinations.asMap().entries.map((entry) {
              final index = entry.key;
              final combo = entry.value;
              return _buildLengthChip(index + 1, combo, languageProvider);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLengthChip(int number, LengthCombination combo, LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF7C3AED).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

  Widget _buildInfoSection(String title, List<Widget> children, LanguageProvider languageProvider) {
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                  fontFamily: languageProvider.fontFamily)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontFamily: languageProvider.fontFamily)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3142),
                    fontFamily: languageProvider.fontFamily)),
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
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesTab(ProductModel product, LanguageProvider languageProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton.icon(
            onPressed: () => _navigateToImagesScreen(product),
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(languageProvider.isEnglish ? 'Manage Images' : 'تصاویر کا انتظام کریں'),
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
                      Text(languageProvider.isEnglish ? 'No images yet' : 'ابھی تک کوئی تصویر نہیں',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(languageProvider.isEnglish ? 'Add images to showcase your product' : 'اپنی پروڈکٹ دکھانے کے لیے تصاویر شامل کریں',
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

  Widget _summaryTile(String label, String value, IconData icon, LanguageProvider languageProvider) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                  fontFamily: languageProvider.fontFamily)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B7280),
                  fontFamily: languageProvider.fontFamily)),
        ],
      ),
    );
  }

  Widget _summaryDivider() =>
      Container(width: 1, height: 36, color: const Color(0xFFE5E7EB));

  Widget _buildCompactPriceRow(
      CustomerPriceModel price, ProductModel product, LanguageProvider languageProvider) {
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
                  price.customer?.name ?? (languageProvider.isEnglish ? 'Unknown' : 'نامعلوم'),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: price.isActive
                          ? const Color(0xFF2D3142)
                          : Colors.grey,
                      fontFamily: languageProvider.fontFamily),
                ),
                Text(price.customer?.customerType ?? '',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontFamily: languageProvider.fontFamily)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(symbol: 'PKR ').format(price.price),
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

  Widget _buildCustomerPricesTab(ProductModel product, LanguageProvider languageProvider) {
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(languageProvider.isEnglish ? 'Customer-specific Prices' : 'کسٹمر کے مخصوص نرخ',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                                fontFamily: languageProvider.fontFamily)),
                        const SizedBox(height: 2),
                        Text(languageProvider.isEnglish ? 'Override the standard sale price per customer' : 'معیاری فروخت قیمت کو ہر کسٹمر کے لیے تبدیل کریں',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontFamily: languageProvider.fontFamily)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToCustomerPrices(product.id),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(languageProvider.isEnglish ? 'Manage' : 'انتظام کریں'),
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
                    _summaryTile(languageProvider.isEnglish ? 'Total' : 'کل', prices.length.toString(),
                        Icons.list_alt, languageProvider),
                    _summaryDivider(),
                    _summaryTile(
                        languageProvider.isEnglish ? 'Active' : 'فعال',
                        prices
                            .where((p) => p.isActive)
                            .length
                            .toString(),
                        Icons.check_circle_outline,
                        languageProvider),
                    _summaryDivider(),
                    _summaryTile(
                      languageProvider.isEnglish ? 'Avg Price' : 'اوسط قیمت',
                      NumberFormat.currency(symbol: 'PKR ').format(
                          prices.isEmpty
                              ? 0
                              : prices.fold(
                              0.0, (s, p) => s + p.price) /
                              prices.length),
                      Icons.attach_money,
                      languageProvider,
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
                      Text(languageProvider.isEnglish ? 'No custom prices yet' : 'ابھی تک کوئی حسب ضرورت قیمت نہیں',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text(languageProvider.isEnglish ? 'Tap Manage to add customer-specific pricing' : 'کسٹمر کے لیے قیمتیں شامل کرنے کے لیے Manage پر ٹیپ کریں',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400])),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _navigateToCustomerPrices(product.id),
                        icon: const Icon(Icons.add,
                            color: Color(0xFF7C3AED)),
                        label: Text(languageProvider.isEnglish ? 'Add Price' : 'قیمت شامل کریں',
                            style: const TextStyle(
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
                            _buildCompactPriceRow(price, product, languageProvider)),
                    if (prices.length > 5) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              _navigateToCustomerPrices(product.id),
                          child: Text(
                              languageProvider.isEnglish
                                  ? 'View all ${prices.length} prices →'
                                  : 'تمام ${prices.length} قیمتیں دیکھیں →',
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

  Widget _buildBomTab(ProductModel product, LanguageProvider languageProvider) {
    if (!product.isBom) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              languageProvider.isEnglish ? 'Not a BOM Product' : 'BOM پروڈکٹ نہیں ہے',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'This product is not configured as a Bill of Materials' : 'یہ پروڈکٹ بل آف میٹریل کے طور پر ترتیب نہیں دی گئی ہے',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _editProduct(),
              icon: const Icon(Icons.edit),
              label: Text(languageProvider.isEnglish ? 'Edit Product' : 'پروڈکٹ میں ترمیم کریں'),
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
              languageProvider.isEnglish ? 'No Components Added' : 'کوئی جزو شامل نہیں',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'This BOM product has no components configured' : 'اس BOM پروڈکٹ میں کوئی جزو ترتیب نہیں دیا گیا',
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
                    Text(
                      languageProvider.isEnglish ? 'BOM Summary' : 'BOM خلاصہ',
                      style: const TextStyle(
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
                        languageProvider.isEnglish
                            ? '${product.bomComponents!.length} Components'
                            : 'اجزاء: ${product.bomComponents!.length}',
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
                        languageProvider.isEnglish ? 'Total Cost' : 'کل لاگت',
                        NumberFormat.currency(symbol: 'PKR ').format(totalCost),
                        Icons.calculate,
                        Colors.white,
                        languageProvider,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildBomSummaryItem(
                        languageProvider.isEnglish ? 'Current Sale Price' : 'موجودہ فروخت قیمت',
                        NumberFormat.currency(symbol: 'PKR ').format(product.salePrice),
                        Icons.price_change,
                        Colors.white,
                        languageProvider,
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
                            Text(
                              languageProvider.isEnglish ? 'Suggested Selling Prices' : 'تجویز کردہ فروخت قیمتیں',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  languageProvider.isEnglish
                                      ? '30% Margin: ${NumberFormat.currency(symbol: 'PKR ').format(suggestedPrice30)}'
                                      : '30% منافع: ${NumberFormat.currency(symbol: 'PKR ').format(suggestedPrice30)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                Text(
                                  languageProvider.isEnglish
                                      ? '50% Margin: ${NumberFormat.currency(symbol: 'PKR ').format(suggestedPrice50)}'
                                      : '50% منافع: ${NumberFormat.currency(symbol: 'PKR ').format(suggestedPrice50)}',
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

          Text(
            languageProvider.isEnglish ? 'Components' : 'اجزاء',
            style: const TextStyle(
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
              return _buildBomComponentCard(component, index + 1, languageProvider);
            },
          ),

          const SizedBox(height: 20),

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
                Text(
                  languageProvider.isEnglish ? 'Manufacturing Cost Breakdown' : 'تیاری کی لاگت کی تفصیل',
                  style: const TextStyle(
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
                    Text(
                      languageProvider.isEnglish ? 'Total Manufacturing Cost:' : 'کل تیاری لاگت:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildBomSummaryItem(String label, String value, IconData icon, Color color, LanguageProvider languageProvider) {
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
            fontFamily: languageProvider.fontFamily,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontFamily: languageProvider.fontFamily),
        ),
      ],
    );
  }

  Widget _buildBomComponentCard(BomComponent component, int number, LanguageProvider languageProvider) {
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                    fontFamily: languageProvider.fontFamily,
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
                  languageProvider.isEnglish ? 'Unit Cost' : 'فی یونٹ لاگت',
                  NumberFormat.currency(symbol: 'PKR ').format(component.costPerUnit),
                  Icons.attach_money,
                  languageProvider,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: const Color(0xFFE0E0E8),
              ),
              Expanded(
                child: _buildComponentDetail(
                  languageProvider.isEnglish ? 'Total Cost' : 'کل لاگت',
                  NumberFormat.currency(symbol: 'PKR ').format(component.totalCost),
                  Icons.calculate,
                  languageProvider,
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

  Widget _buildComponentDetail(String label, String value, IconData icon, LanguageProvider languageProvider) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: languageProvider.fontFamily),
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
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Product' : 'پروڈکٹ حذف کریں'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to delete this product? This action cannot be undone.'
              : 'کیا آپ واقعی اس پروڈکٹ کو حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں کیا جا سکتا۔',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider =
              Provider.of<ProductProvider>(context, listen: false);
              final result =
              await provider.deleteProduct(widget.productId);
              if (result['success'] && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(languageProvider.isEnglish
                            ? 'Product deleted successfully'
                            : 'پروڈکٹ کامیابی سے حذف ہو گئی')));
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['error'] ??
                        (languageProvider.isEnglish ? 'Failed to delete product' : 'پروڈکٹ حذف کرنے میں ناکامی'))));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B)),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
          ),
        ],
      ),
    );
  }

  void _showUpdateStockDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final quantityController = TextEditingController();
    String operation = 'add';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(languageProvider.isEnglish ? 'Update Stock' : 'اسٹاک اپ ڈیٹ کریں'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: operation,
                items: [
                  DropdownMenuItem(
                      value: 'add',
                      child: Text(languageProvider.isEnglish ? 'Add Stock' : 'اسٹاک شامل کریں')),
                  DropdownMenuItem(
                      value: 'subtract',
                      child: Text(languageProvider.isEnglish ? 'Remove Stock' : 'اسٹاک ہٹائیں')),
                  DropdownMenuItem(
                      value: 'set',
                      child: Text(languageProvider.isEnglish ? 'Set Quantity' : 'مقدار مقرر کریں')),
                ],
                onChanged: (value) =>
                    setState(() => operation = value!),
                decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Operation' : 'آپریشن',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Quantity' : 'مقدار',
                    border: const OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں')),
            ElevatedButton(
              onPressed: () async {
                if (quantityController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please enter quantity'
                              : 'براہ کرم مقدار درج کریں')));
                  return;
                }
                final quantity =
                int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(languageProvider.isEnglish
                              ? 'Please enter a valid quantity'
                              : 'براہ کرم ایک درست مقدار درج کریں')));
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
                      Text(result['data']['message'] ?? (languageProvider.isEnglish ? 'Updated' : 'اپ ڈیٹ ہو گیا'))));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result['error'] ??
                          (languageProvider.isEnglish ? 'Failed to update stock' : 'اسٹاک اپ ڈیٹ کرنے میں ناکامی'))));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED)),
              child: Text(languageProvider.isEnglish ? 'Update' : 'اپ ڈیٹ کریں'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PRODUCT HISTORY TAB
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
    final languageProvider = Provider.of<LanguageProvider>(context);

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
              label: Text(languageProvider.isEnglish ? 'Retry' : 'دوبارہ کوشش کریں'),
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
                  '${_sales.length}', languageProvider.isEnglish ? 'Sales' : 'فروخت', Colors.white, languageProvider),
              _vertDivider(),
              _summaryItem(
                  Icons.attach_money,
                  _currency.format(totalRevenue),
                  languageProvider.isEnglish ? 'Revenue ($totalSold units)' : 'آمدنی ($totalSold یونٹس)',
                  Colors.white,
                  languageProvider),
              _vertDivider(),
              _summaryItem(Icons.inventory_2_outlined,
                  '${_purchases.length}', languageProvider.isEnglish ? 'Receipts' : 'رسیدیں', Colors.white, languageProvider),
              _vertDivider(),
              _summaryItem(
                  Icons.shopping_cart_outlined,
                  _currency.format(totalCost),
                  languageProvider.isEnglish ? 'Purchased ($totalReceived units)' : 'خریداری ($totalReceived یونٹس)',
                  Colors.white,
                  languageProvider),
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
                    Text('${languageProvider.isEnglish ? 'Sales' : 'فروخت'} (${_sales.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('${languageProvider.isEnglish ? 'Purchases' : 'خریداری'} (${_purchases.length})'),
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
              _buildSalesTab(languageProvider),
              _buildPurchasesTab(languageProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTab(LanguageProvider languageProvider) {
    if (_sales.isEmpty) {
      return _buildEmpty(Icons.sell_outlined,
          languageProvider.isEnglish ? 'No sales recorded yet' : 'ابھی تک کوئی فروخت ریکارڈ نہیں',
          languageProvider.isEnglish ? 'Sales of this product will appear here' : 'اس پروڈکٹ کی فروخت یہاں ظاہر ہوگی',
          languageProvider);
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _sales.length,
        itemBuilder: (ctx, i) => _buildSaleCard(_sales[i], languageProvider),
      ),
    );
  }

  Widget _buildSaleCard(_SaleRecord sale, LanguageProvider languageProvider) {
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
                        isInvoice
                            ? (languageProvider.isEnglish ? 'Invoice' : 'انوائس')
                            : (languageProvider.isEnglish ? 'POS' : 'پی او ایس'),
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
                    languageProvider.isEnglish
                        ? sale.paymentStatus.toUpperCase()
                        : sale.paymentStatus == 'paid' ? 'ادا شدہ'
                        : sale.paymentStatus == 'partial' ? 'جزوی'
                        : 'غیر ادا شدہ',
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
                      sale.customerName ?? (languageProvider.isEnglish ? 'Walk-in' : 'واک ان'),
                      const Color(0xFF6B7280),
                      languageProvider),
                ),
                const SizedBox(width: 8),
                _infoChip(
                    Icons.calendar_today_outlined,
                    _dateFormat.format(sale.date),
                    const Color(0xFF6B7280),
                    languageProvider),
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
                  _amountCell(languageProvider.isEnglish ? 'Qty' : 'مقدار', '${sale.quantity}',
                      const Color(0xFF2D3142), languageProvider),
                  _amountDivider(),
                  _amountCell(languageProvider.isEnglish ? 'Unit Price' : 'فی یونٹ قیمت',
                      _currency.format(sale.unitPrice),
                      const Color(0xFF7C3AED),
                      languageProvider),
                  _amountDivider(),
                  _amountCell(languageProvider.isEnglish ? 'Total' : 'کل',
                      _currency.format(sale.totalPrice),
                      const Color(0xFF10B981),
                      languageProvider),
                  if (isCredit) ...[
                    _amountDivider(),
                    _amountCell(
                        'Method',
                        languageProvider.isEnglish ? 'Credit' : 'کریڈٹ',
                        const Color(0xFFEF4444),
                        languageProvider),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasesTab(LanguageProvider languageProvider) {
    if (_purchases.isEmpty) {
      return _buildEmpty(Icons.inventory_2_outlined,
          languageProvider.isEnglish ? 'No purchase receipts yet' : 'ابھی تک کوئی خریداری رسید نہیں',
          languageProvider.isEnglish ? 'Stock received for this product will appear here' : 'اس پروڈکٹ کے لیے موصول ہونے والا اسٹاک یہاں ظاہر ہوگا',
          languageProvider);
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _purchases.length,
        itemBuilder: (ctx, i) => _buildPurchaseCard(_purchases[i], languageProvider),
      ),
    );
  }

  Widget _buildPurchaseCard(_PurchaseRecord purchase, LanguageProvider languageProvider) {
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
                      purchase.supplierName ?? (languageProvider.isEnglish ? 'Unknown Supplier' : 'نامعلوم سپلائر'),
                      const Color(0xFF6B7280),
                      languageProvider),
                ),
                const SizedBox(width: 8),
                _infoChip(
                    Icons.calendar_today_outlined,
                    _dateFormat.format(purchase.date),
                    const Color(0xFF6B7280),
                    languageProvider),
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
                  _amountCell(languageProvider.isEnglish ? 'Received' : 'موصول شدہ',
                      '${purchase.quantityReceived}',
                      const Color(0xFF2D3142),
                      languageProvider),
                  _amountDivider(),
                  _amountCell(languageProvider.isEnglish ? 'Unit Cost' : 'فی یونٹ لاگت',
                      _currency.format(purchase.unitCost),
                      const Color(0xFF7C3AED),
                      languageProvider),
                  _amountDivider(),
                  _amountCell(languageProvider.isEnglish ? 'Total Cost' : 'کل لاگت',
                      _currency.format(purchase.totalCost),
                      const Color(0xFF10B981),
                      languageProvider),
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
                    Text('${languageProvider.isEnglish ? 'Batch' : 'بیچ'}: ${purchase.batchNumber}',
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
                      '${languageProvider.isEnglish ? 'Exp' : 'ختم ہونے کی تاریخ'}: ${_dateFormat.format(purchase.expiryDate!)}'
                          '${isExpired ? (languageProvider.isEnglish ? ' ⚠ Expired' : ' ⚠ ختم شدہ') : expiringSoon ? (languageProvider.isEnglish ? ' ⚠ Soon' : ' ⚠ قریب') : ''}',
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
      IconData icon, String title, String subtitle, LanguageProvider languageProvider) {
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
                  color: Colors.grey[500],
                  fontFamily: languageProvider.fontFamily)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[400],
                  fontFamily: languageProvider.fontFamily)),
        ],
      ),
    );
  }

  Widget _summaryItem(
      IconData icon, String value, String label, Color color, LanguageProvider languageProvider) {
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
                  color: color,
                  fontFamily: languageProvider.fontFamily),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.7),
                  fontFamily: languageProvider.fontFamily),
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

  Widget _infoChip(IconData icon, String text, Color color, LanguageProvider languageProvider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: color, fontFamily: languageProvider.fontFamily),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _amountCell(String label, String value, Color color, LanguageProvider languageProvider) {
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
                  color: color,
                  fontFamily: languageProvider.fontFamily),
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