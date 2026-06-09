// lib/screens/products/bom_component_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../providers/lanprovider.dart';

class BomComponentSelector extends StatefulWidget {
  final Function(BomComponent) onComponentAdded;
  final List<BomComponent> existingComponents;
  final int? excludeProductId;

  const BomComponentSelector({
    Key? key,
    required this.onComponentAdded,
    required this.existingComponents,
    this.excludeProductId,
  }) : super(key: key);

  @override
  State<BomComponentSelector> createState() => _BomComponentSelectorState();
}

class _BomComponentSelectorState extends State<BomComponentSelector> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<ProductModel> _searchResults = [];
  ProductModel? _selectedProduct;
  bool _isLoading = false;
  String? _searchError;
  bool _isSearching = false;
  bool _isNegativeQuantity = false;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _searchError = null;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final result = await productProvider.searchProducts(query);

      if (result['success']) {
        final products = result['data'] as List<ProductModel>;
        setState(() {
          _searchResults = products.where((p) =>
          p.id != widget.excludeProductId &&
              !widget.existingComponents.any((c) => c.productId == p.id) &&
              p.isActive
          ).toList();
        });

        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        if (_searchResults.isEmpty && query.isNotEmpty) {
          setState(() {
            _searchError = languageProvider.isEnglish
                ? 'No products found matching "$query"'
                : '"$query" سے ملنے والی کوئی پروڈکٹ نہیں ملی';
          });
        }
      } else {
        setState(() {
          _searchError = result['error'] ?? 'Search failed';
        });
      }
    } catch (e) {
      setState(() {
        _searchError = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  void _addComponent() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Please select a product'
            : 'براہ کرم ایک پروڈکٹ منتخب کریں')),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Please enter a valid quantity'
            : 'براہ کرم ایک درست مقدار درج کریں')),
      );
      return;
    }

    if (quantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Quantity cannot be zero'
            : 'مقدار صفر نہیں ہو سکتی')),
      );
      return;
    }

    final finalQuantity = _isNegativeQuantity ? -quantity.abs() : quantity.abs();

    final component = BomComponent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.itemName,
      quantity: finalQuantity,
      unit: _selectedProduct!.unit?.symbol ?? 'Pcs',
      costPerUnit: _selectedProduct!.costPrice,
      totalCost: _selectedProduct!.costPrice * finalQuantity,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    widget.onComponentAdded(component);

    setState(() {
      _selectedProduct = null;
      _quantityController.clear();
      _notesController.clear();
      _searchController.clear();
      _searchResults = [];
      _isNegativeQuantity = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.isEnglish ? 'Add Component' : 'جزو شامل کریں',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142)
                  ),
                ),
                const SizedBox(height: 16),

                // Search field
                TextField(
                  controller: _searchController,
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Search Product' : 'پروڈکٹ تلاش کریں',
                    hintText: languageProvider.isEnglish
                        ? 'Type product name or barcode...'
                        : 'پروڈکٹ کا نام یا بارکوڈ ٹائپ کریں...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF7C3AED)),
                    suffixIcon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                        : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchProducts,
                    ),
                  ),
                  onSubmitted: (_) => _searchProducts(),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() {
                        _searchResults = [];
                        _searchError = null;
                      });
                    }
                  },
                ),

                // Search results
                if (_isSearching && _isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ] else if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    languageProvider.isEnglish ? 'Select Product:' : 'پروڈکٹ منتخب کریں:',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];
                        final isSelected = _selectedProduct?.id == product.id;

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFFEDE9FB),
                          title: Text(
                            product.itemName,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: languageProvider.fontFamily,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish
                                    ? 'Cost: ${product.costPrice.toStringAsFixed(2)} PKR / ${product.unit?.symbol ?? 'unit'}'
                                    : 'قیمت: ${product.costPrice.toStringAsFixed(2)} PKR / ${product.unit?.symbol ?? 'یونٹ'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (product.barcode != null)
                                Text(
                                  languageProvider.isEnglish
                                      ? 'Barcode: ${product.barcode}'
                                      : 'بارکوڈ: ${product.barcode}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFF7C3AED))
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedProduct = product;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],

                if (_searchError != null && _searchResults.isEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _searchError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_selectedProduct != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Selected product info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF7C3AED), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProduct!.itemName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                languageProvider.isEnglish
                                    ? 'Cost: ${_selectedProduct!.costPrice.toStringAsFixed(2)} PKR / ${_selectedProduct!.unit?.symbol ?? 'unit'}'
                                    : 'قیمت: ${_selectedProduct!.costPrice.toStringAsFixed(2)} PKR / ${_selectedProduct!.unit?.symbol ?? 'یونٹ'}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7C3AED)
                                ),
                              ),
                              if (_selectedProduct!.hasMultipleLengths && _selectedProduct!.lengthCombinations != null)
                                Text(
                                  languageProvider.isEnglish
                                      ? 'Has ${_selectedProduct!.lengthCombinations!.length} length variations'
                                      : 'لمبائی کی ${_selectedProduct!.lengthCombinations!.length} مختلف حالتیں ہیں',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Component type selector (Material vs Byproduct)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isNegativeQuantity
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isNegativeQuantity
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _isNegativeQuantity,
                          onChanged: (value) {
                            setState(() {
                              _isNegativeQuantity = false;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish
                                    ? '📦 Material (Consumable)'
                                    : '📦 مواد (خرچ ہونے والا)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                languageProvider.isEnglish
                                    ? 'This component is consumed to make the product'
                                    : 'یہ جزو پروڈکٹ بنانے کے لیے استعمال ہوتا ہے',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isNegativeQuantity
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isNegativeQuantity
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _isNegativeQuantity,
                          onChanged: (value) {
                            setState(() {
                              _isNegativeQuantity = true;
                            });
                          },
                          activeColor: Colors.orange,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish
                                    ? '♻️ Byproduct / Wastage'
                                    : '♻️ ضمنی پیداوار / ضائع',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                languageProvider.isEnglish
                                    ? 'This component is produced or wasted during manufacturing (negative quantity)'
                                    : 'یہ جزو تیاری کے دوران پیدا یا ضائع ہوتا ہے (منفی مقدار)',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quantity field
                  TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontFamily: languageProvider.fontFamily),
                    decoration: InputDecoration(
                      labelText: _isNegativeQuantity
                          ? (languageProvider.isEnglish
                          ? 'Quantity (wastage/produced)'
                          : 'مقدار (ضائع / پیدا شدہ)')
                          : (languageProvider.isEnglish
                          ? 'Quantity (consumed)'
                          : 'مقدار (استعمال شدہ)'),
                      hintText: _isNegativeQuantity
                          ? (languageProvider.isEnglish
                          ? 'e.g., 0.06 (wastage)'
                          : 'مثال: 0.06 (ضائع)')
                          : (languageProvider.isEnglish
                          ? 'Enter quantity needed'
                          : 'مطلوبہ مقدار درج کریں'),
                      border: const OutlineInputBorder(),
                      prefixIcon: _isNegativeQuantity
                          ? const Icon(Icons.delete_outline, color: Colors.orange)
                          : const Icon(Icons.numbers),
                      helperText: _isNegativeQuantity
                          ? (languageProvider.isEnglish
                          ? 'Positive number will be stored as negative (reduces total cost)'
                          : 'مثبت نمبر منفی کے طور پر محفوظ ہو گا (کل لاگت کم کرتا ہے)')
                          : (languageProvider.isEnglish
                          ? 'How many units are needed for this BOM?'
                          : 'اس BOM کے لیے کتنے یونٹس درکار ہیں؟'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Notes field
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: TextStyle(fontFamily: languageProvider.fontFamily),
                    decoration: InputDecoration(
                      labelText: languageProvider.isEnglish ? 'Notes (optional)' : 'نوٹس (اختیاری)',
                      hintText: languageProvider.isEnglish
                          ? 'Any special instructions or remarks...'
                          : 'کوئی خاص ہدایات یا تبصرے...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.note_add),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cost preview
                  if (_quantityController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isNegativeQuantity ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isNegativeQuantity ? Colors.orange.shade200 : Colors.green.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isNegativeQuantity
                                    ? (languageProvider.isEnglish ? 'Cost Reduction:' : 'لاگت میں کمی:')
                                    : (languageProvider.isEnglish ? 'Total Cost:' : 'کل لاگت:'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${(_selectedProduct!.costPrice * (double.tryParse(_quantityController.text) ?? 0)).toStringAsFixed(2)} PKR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _isNegativeQuantity ? Colors.orange : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          if (_isNegativeQuantity) ...[
                            const SizedBox(height: 8),
                            Text(
                              languageProvider.isEnglish
                                  ? 'This will REDUCE the total BOM cost'
                                  : 'یہ کل BOM لاگت کو کم کرے گا',
                              style: const TextStyle(fontSize: 11, color: Colors.orange),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addComponent,
                      icon: Icon(_isNegativeQuantity ? Icons.delete_outline : Icons.add),
                      label: Text(
                        _isNegativeQuantity
                            ? (languageProvider.isEnglish ? 'Add as Byproduct' : 'بطور ضمنی پیداوار شامل کریں')
                            : (languageProvider.isEnglish ? 'Add to BOM' : 'BOM میں شامل کریں'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isNegativeQuantity ? Colors.orange : const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}