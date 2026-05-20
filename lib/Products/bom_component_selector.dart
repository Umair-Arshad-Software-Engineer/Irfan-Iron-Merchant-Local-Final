// lib/screens/products/bom_component_selector.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';

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
  bool _isNegativeQuantity = false; // NEW: Track if this is a byproduct

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
        // Filter out products that are already added or the parent product itself
        setState(() {
          _searchResults = products.where((p) =>
          p.id != widget.excludeProductId &&
              !widget.existingComponents.any((c) => c.productId == p.id) &&
              p.isActive
          ).toList();
        });

        if (_searchResults.isEmpty && query.isNotEmpty) {
          setState(() {
            _searchError = 'No products found matching "$query"';
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
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    // Allow zero? No - zero quantity doesn't make sense
    if (quantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity cannot be zero')),
      );
      return;
    }

    // Apply negative sign if checkbox is checked
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

    // Clear form
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Component',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Product',
                hintText: 'Type product name or barcode...',
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
              const Text('Select Product:', style: TextStyle(fontWeight: FontWeight.w500)),
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
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cost: ${product.costPrice.toStringAsFixed(2)} PKR / ${product.unit?.symbol ?? 'unit'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (product.barcode != null)
                            Text(
                              'Barcode: ${product.barcode}',
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
                    Expanded(child: Text(_searchError!, style: const TextStyle(color: Colors.red))),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cost: ${_selectedProduct!.costPrice.toStringAsFixed(2)} PKR / ${_selectedProduct!.unit?.symbol ?? 'unit'}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF7C3AED)),
                          ),
                          if (_selectedProduct!.hasMultipleLengths && _selectedProduct!.lengthCombinations != null)
                            Text(
                              'Has ${_selectedProduct!.lengthCombinations!.length} length variations',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // NEW: Component type selector (Material vs Byproduct)
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📦 Material (Consumable)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'This component is consumed to make the product',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '♻️ Byproduct / Wastage',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'This component is produced or wasted during manufacturing (negative quantity)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                decoration: InputDecoration(
                  labelText: _isNegativeQuantity ? 'Quantity (wastage/produced)' : 'Quantity (consumed)',
                  hintText: _isNegativeQuantity ? 'e.g., 0.06 (wastage)' : 'Enter quantity needed',
                  border: const OutlineInputBorder(),
                  prefixIcon: _isNegativeQuantity
                      ? const Icon(Icons.delete_outline, color: Colors.orange)
                      : const Icon(Icons.numbers),
                  helperText: _isNegativeQuantity
                      ? 'Positive number will be stored as negative (reduces total cost)'
                      : 'How many units are needed for this BOM?',
                ),
              ),

              const SizedBox(height: 12),

              // Notes field
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Any special instructions or remarks...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_add),
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
                            _isNegativeQuantity ? 'Cost Reduction:' : 'Total Cost:',
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
                        const Text(
                          'This will REDUCE the total BOM cost',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
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
                  label: Text(_isNegativeQuantity ? 'Add as Byproduct' : 'Add to BOM'),
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
  }
}