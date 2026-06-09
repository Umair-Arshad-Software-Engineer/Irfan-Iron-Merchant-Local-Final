// lib/screens/sales/sale_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../models/customer.dart';
import '../../models/product_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../models/sale_model.dart';
import '../providers/sale_provider.dart';
import '../services/sale_pdf_generator.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class SaleItem {
  final ProductModel product;
  int quantity;
  double unitPrice;
  double? customerSpecificPrice;
  bool usingCustomerPrice;

  // ── Length combination fields ──
  List<String> selectedLengths;
  Map<String, double> lengthQuantities;
  String lengthsDisplay;

  // ── Weight field (only for SARYA) ──
  double weight;

  SaleItem({
    required this.product,
    this.quantity = 1,
    required this.unitPrice,
    this.customerSpecificPrice,
    this.usingCustomerPrice = false,
    this.selectedLengths = const [],
    this.lengthQuantities = const {},
    this.lengthsDisplay = '',
    this.weight = 0.0,
  });

// In SaleItem class, add this method:
  double totalForMode(bool isSaryaMode) {
    if (isSaryaMode && weight > 0) {
      return weight * unitPrice;
    } else if (!isSaryaMode) {
      return quantity.toDouble() * unitPrice;
    }
    return 0.0; // SARYA mode but weight not entered yet
  }
  double get total {
    // SARYA: weight × unitPrice (where weight is in Kg, price is per Kg)
    // FILLED: quantity × unitPrice (where quantity is in pieces)
    if (hasWeightBasedCalculation) {
      // Weight-based calculation: weight(Kg) × price(per Kg)
      return weight * unitPrice;
    } else {
      // Quantity-based calculation: quantity(pcs) × price(per pcs)
      return quantity.toDouble() * unitPrice;
    }
  }

  bool get hasWeightBasedCalculation {
    // ✅ CRITICAL: Weight must be > 0 AND product must be SARYA type
    return product.isSaryaType && weight > 0;
  }


  double get displayQuantity => hasWeightBasedCalculation ? weight : quantity.toDouble();

  String get quantityUnit => hasWeightBasedCalculation ? 'Kg' : 'pcs';

  double get standardPrice => product.salePrice.toDouble();

  bool get hasPriceDifference =>
      customerSpecificPrice != null && customerSpecificPrice != standardPrice;

  bool get hasLengthCombinations =>
      selectedLengths.isNotEmpty;

  int get totalPieces =>
      lengthQuantities.values.fold(0, (sum, qty) => sum + qty.round());
}

// ─────────────────────────────────────────────
//  LENGTH COMBINATION MODEL
//  Matches the LengthBodyCombination from invoice page
// ─────────────────────────────────────────────
class SaleLengthCombination {
  final String length;
  final String lengthDecimal;
  final double? salePricePerKg;
  final Map<String, double> customerPrices;

  const SaleLengthCombination({
    required this.length,
    required this.lengthDecimal,
    this.salePricePerKg,
    this.customerPrices = const {},
  });

  factory SaleLengthCombination.fromProductModel(LengthCombination combo) {
    return SaleLengthCombination(
      length: combo.length,
      lengthDecimal: combo.lengthDecimal,
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────

class SaleScreen extends StatefulWidget {
  final SaleModel? existingSale; // ADD THIS

  const SaleScreen({super.key, this.existingSale}); // MODIFY THIS


  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen>
    with SingleTickerProviderStateMixin {
  bool _isPosMode = false;

  final List<SaleItem> _cartItems = [];
  Customer? _selectedCustomer;
  double _discountAmount = 0.0;
  double _discountPercent = 0.0;
  bool _usePercentDiscount = true;

  bool _useCustomerPrices = false;
  bool _isFetchingCustomerPrices = false;
  Map<int, double> _customerPriceMap = {};

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _referenceController = TextEditingController();

  final TextEditingController _invoiceNoteController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  DateTime? _creditDueDate;

  String? _selectedCategory;
  String? _selectedSubcategory;
  List<ProductModel> _allProducts = [];
  bool _isLoadingProducts = false;

  late final AnimationController _toggleAnim;
  bool _showOptionsPanel = false;

  SaleType _selectedSaleType = SaleType.filled; // Default to FILLED


  late final TextEditingController _discountPercentCtrl;
  late final TextEditingController _discountAmountCtrl;
  bool _updatingDiscountCtrl = false;

  bool get _isEditMode => widget.existingSale != null;
  bool _isPrefilling = false;


  @override
  void initState() {
    super.initState();
    _toggleAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _searchController.addListener(_onSearchChanged);

    // Initialize persistent discount controllers
    _discountPercentCtrl = TextEditingController(text: _discountPercent.toStringAsFixed(1));
    _discountAmountCtrl = TextEditingController(text: _discountAmount.toStringAsFixed(2));

    // _loadAllProducts();
    _loadAllProducts().then((_) {
      if (_isEditMode) _prefillFromSale(); // ADD THIS
    });
  }


  Future<void> _prefillFromSale() async {
    setState(() => _isPrefilling = true);
    final sale = widget.existingSale!;

    // Sale type / category
    _selectedSaleType =
    sale.saleCategory == 'sarya' ? SaleType.sarya : SaleType.filled;

    // POS vs Invoice
    _isPosMode = sale.saleType == 'pos';
    if (_isPosMode) {
      _toggleAnim.reverse();
    } else {
      _toggleAnim.forward();
    }

    // Dates
    _invoiceDate = sale.saleDate;
    _dueDate = sale.dueDate;

    // Reference & notes
    _referenceController.text = sale.reference ?? '';
    _invoiceNoteController.text = sale.notes ?? '';

    // Discount
    if (sale.discountType == 'percent') {
      _usePercentDiscount = true;
      _discountPercent = sale.discountValue;
    } else {
      _usePercentDiscount = false;
      _discountAmount = sale.discountValue;
    }
    _syncDiscountControllers();

    // Customer
    if (sale.customer != null) {
      final custProvider =
      Provider.of<CustomerProvider>(context, listen: false);
      await custProvider.fetchCustomers();
      final matches =
      custProvider.customers.where((c) => c.id == sale.customer!.id).toList();
      if (matches.isNotEmpty && mounted) {
        setState(() => _selectedCustomer = matches.first);
      }
    }

    // Cart items — build from existing sale items
    if (sale.items != null) {
      for (final saleItem in sale.items!) {
        final matches =
        _allProducts.where((p) => p.id == saleItem.productId).toList();
        if (matches.isEmpty) continue;
        final product = matches.first;

        final cartItem = SaleItem(
          product: product,
          quantity: saleItem.quantity > 0 ? saleItem.quantity : 1,
          unitPrice: saleItem.unitPrice,
          weight: saleItem.weight ?? 0.0,
          selectedLengths:
          List<String>.from(saleItem.selectedLengths ?? []),
          lengthQuantities: Map<String, double>.fromEntries(
            (saleItem.lengthQuantities ?? {}).entries.map(
                  (e) => MapEntry(
                e.key,
                e.value is num
                    ? (e.value as num).toDouble()
                    : double.tryParse(e.value.toString()) ?? 1.0,
              ),
            ),
          ),
          lengthsDisplay: saleItem.selectedLengthsDisplay ?? '',
        );

        if (mounted) setState(() => _cartItems.add(cartItem));
      }
    }

    if (mounted) setState(() => _isPrefilling = false);
  }

  @override
  void dispose() {
    _toggleAnim.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _invoiceNoteController.dispose();
    _referenceController.dispose();
    _discountPercentCtrl.dispose();  // Add this
    _discountAmountCtrl.dispose();   // Add this
    super.dispose();
  }

  // Add this helper method:
  void _syncDiscountControllers() {
    _updatingDiscountCtrl = true;
    _discountPercentCtrl.text = _discountPercent.toStringAsFixed(1);
    _discountAmountCtrl.text = _discountAmount.toStringAsFixed(2);
    _updatingDiscountCtrl = false;
  }

  // ─────────────────────────────────────────────
  //  COMPUTED
  // ─────────────────────────────────────────────

  double get _subtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.totalForMode(_selectedSaleType == SaleType.sarya));

  double get _discountValue => _usePercentDiscount
      ? _subtotal * (_discountPercent / 100)
      : _discountAmount;

  double get _grandTotal => _subtotal - _discountValue;

  double get _customerPriceSavings => _cartItems
      .where((i) => i.usingCustomerPrice && i.hasPriceDifference)
      .fold(0.0,
          (sum, i) => sum + ((i.standardPrice - i.unitPrice) * i.quantity));

  // ─────────────────────────────────────────────
  //  LENGTH COMBINATION LOGIC
  //  (ported directly from invoice page)
  // ─────────────────────────────────────────────

  /// Wraps a potentially RTL string so it renders correctly
  /// inside mixed LTR content (e.g. "190ملي × 25")
  String _safeLengthLabel(String length, double qty) {
    // U+2068 = First Strong Isolate, U+2069 = Pop Directional Isolate
    // This isolates the length string from surrounding LTR text
    const fsi = '\u2068';
    const pdi = '\u2069';
    return '$fsi$length$pdi × ${qty.toStringAsFixed(0)}';
  }

  /// Shows the length + quantity selection dialog — identical UX to invoice page.
  Future<void> _showLengthSelectionDialog(int cartIndex) async {
    final item = _cartItems[cartIndex];
    final product = item.product;
    final combinations = product.lengthCombinations ?? [];

    if (combinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No length combinations available for ${product.itemName}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> currentSelections = List.from(item.selectedLengths);
    Map<String, double> currentQuantities = Map.from(item.lengthQuantities);
    final weightController =
    TextEditingController(text: item.weight > 0 ? item.weight.toStringAsFixed(2) : '');

    // ✅ Create controllers once, outside the builder
    final Map<String, TextEditingController> qtyControllers = {};
    for (final combo in combinations) {
      final qty = currentQuantities[combo.length] ?? 0.0;
      qtyControllers[combo.length] = TextEditingController(
        text: currentSelections.contains(combo.length) && qty > 0
            ? qty.toStringAsFixed(0)
            : '',
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Lengths — ${product.itemName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${combinations.length} length${combinations.length != 1 ? 's' : ''} available',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 520,
                child: Column(
                  children: [
                    // ── Manual weight input ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weight (Kg)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: 'Enter weight manually',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.scale, size: 18),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Weight is entered manually per item',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Select Lengths & Quantities',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151))),
                    ),
                    const SizedBox(height: 8),

                    // ── Length list ──
                    Expanded(
                      child: ListView.builder(
                        itemCount: combinations.length,
                        itemBuilder: (ctx, idx) {
                          final combo = combinations[idx];
                          final isSelected = currentSelections.contains(combo.length);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  dense: true,
                                  title: Text(
                                    'Length: ${combo.length}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  subtitle: combo.lengthDecimal.isNotEmpty
                                      ? Text('Decimal: ${combo.lengthDecimal}',
                                      style: const TextStyle(fontSize: 11))
                                      : null,
                                  value: isSelected,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setDlgState(() {
                                      if (val == true) {
                                        currentSelections.add(combo.length);
                                        currentQuantities[combo.length] = 1.0;
                                        // ✅ Set controller text, don't recreate it
                                        qtyControllers[combo.length]?.text = '1';
                                      } else {
                                        currentSelections.remove(combo.length);
                                        currentQuantities.remove(combo.length);
                                        // ✅ Clear controller text
                                        qtyControllers[combo.length]?.text = '';
                                      }
                                    });
                                  },
                                ),
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                    child: Row(
                                      children: [
                                        const Text('Quantity:',
                                            style: TextStyle(fontSize: 13)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            // ✅ Use the persistent controller
                                            controller: qtyControllers[combo.length],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: 'Enter qty',
                                              border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8)),
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 8),
                                            ),
                                            onChanged: (v) {
                                              final key = combinations[idx].length;
                                              currentQuantities[key] = double.tryParse(v) ?? 0.0;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Summary bar ──
                    if (currentSelections.isNotEmpty) ...[
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${currentSelections.length} length(s) selected',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF065F46)),
                                ),
                                Text(
                                  'Total: ${currentQuantities.values.fold(0.0, (s, q) => s + q).toStringAsFixed(0)} pcs',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF065F46)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Weight:', style: TextStyle(fontSize: 12)),
                                Text(
                                  '${(double.tryParse(weightController.text) ?? 0.0).toStringAsFixed(2)} Kg',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDlgState(() {
                      currentSelections.clear();
                      currentQuantities.clear();
                      // ✅ Also clear all qty controllers
                      for (final ctrl in qtyControllers.values) {
                        ctrl.text = '';
                      }
                    });
                  },
                  child: const Text('Clear All',
                      style: TextStyle(color: Color(0xFFEF4444))),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final double manualWeight =
                        double.tryParse(weightController.text) ?? 0.0;

                    // ✅ Read final values from controllers before closing
                    for (final combo in combinations) {
                      if (currentSelections.contains(combo.length)) {
                        currentQuantities[combo.length] =
                            double.tryParse(qtyControllers[combo.length]?.text ?? '') ?? 1.0;
                      }
                    }

                    final String lengthsDisplay = currentSelections.map((l) {
                      final q = currentQuantities[l] ?? 1.0;
                      // Use parentheses format with FSI/PDI isolation for RTL safety
                      return '\u2068$l\u2069 (${q.toStringAsFixed(0)})';
                    }).join(', ');

                    setState(() {
                      _cartItems[cartIndex] = SaleItem(
                        product: item.product,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        customerSpecificPrice: item.customerSpecificPrice,
                        usingCustomerPrice: item.usingCustomerPrice,
                        selectedLengths: List<String>.from(currentSelections),
                        lengthQuantities: Map<String, double>.from(currentQuantities),
                        lengthsDisplay: lengthsDisplay,
                        weight: manualWeight,
                      );
                    });

                    Navigator.pop(ctx);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    // ✅ Dispose all controllers after dialog closes
    weightController.dispose();
    for (final ctrl in qtyControllers.values) {
      ctrl.dispose();
    }
  }

  /// Removes a single length chip from a cart item
  void _removeLengthFromCartItem(int cartIndex, String length) {
    final item = _cartItems[cartIndex];
    final newLengths = List<String>.from(item.selectedLengths)..remove(length);
    final newQtys = Map<String, double>.from(item.lengthQuantities)
      ..remove(length);

    final newDisplay = newLengths.map((l) {
      final q = newQtys[l] ?? 1.0;
      return '\u2068$l\u2069 (${q.toStringAsFixed(0)})';
    }).join(', ');

    setState(() {
      _cartItems[cartIndex] = SaleItem(
        product: item.product,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        customerSpecificPrice: item.customerSpecificPrice,
        usingCustomerPrice: item.usingCustomerPrice,
        selectedLengths: newLengths,
        lengthQuantities: newQtys,
        lengthsDisplay: newDisplay,
        weight: item.weight,
      );
    });
  }

  // ─────────────────────────────────────────────
  //  CUSTOMER PRICE LOGIC
  // ─────────────────────────────────────────────

  Future<void> _fetchAndApplyCustomerPrices() async {
    if (_selectedCustomer == null || !_useCustomerPrices) {
      setState(() {
        for (final item in _cartItems) {
          item.usingCustomerPrice = false;
          item.unitPrice = item.standardPrice;
        }
        _customerPriceMap = {};
      });
      return;
    }

    setState(() => _isFetchingCustomerPrices = true);

    try {
      final productIds =
      _cartItems.map((i) => i.product.id).whereType<int>().toList();

      if (productIds.isEmpty) {
        setState(() => _isFetchingCustomerPrices = false);
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.bulkCustomerPricesUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': _selectedCustomer!.id,
          'product_ids': productIds,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final raw = json['data'] as Map<String, dynamic>;
          final priceMap = raw.map(
                  (k, v) => MapEntry(int.parse(k), double.parse(v.toString())));
          setState(() {
            _customerPriceMap = priceMap;
            for (final item in _cartItems) {
              final pid = item.product.id;
              if (pid != null && priceMap.containsKey(pid)) {
                item.customerSpecificPrice = priceMap[pid];
                item.usingCustomerPrice = true;
                item.unitPrice = priceMap[pid]!;
              } else {
                item.customerSpecificPrice = null;
                item.usingCustomerPrice = false;
                item.unitPrice = item.standardPrice;
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not fetch customer prices: $e'),
              backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingCustomerPrices = false);
    }
  }

  double _resolvePrice(ProductModel product) {
    if (_useCustomerPrices &&
        _selectedCustomer != null &&
        product.id != null &&
        _customerPriceMap.containsKey(product.id)) {
      return _customerPriceMap[product.id]!;
    }
    return product.salePrice.toDouble();
  }

  bool _hasCustomerPrice(ProductModel product) =>
      _useCustomerPrices &&
          _selectedCustomer != null &&
          product.id != null &&
          _customerPriceMap.containsKey(product.id);

  // ─────────────────────────────────────────────
  //  SEARCH
  // ─────────────────────────────────────────────

  Future<void> _loadAllProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      await provider.fetchProducts();
      if (mounted) setState(() => _allProducts = provider.products);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingProducts = false);
  }

  Future<void> _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      final result = await provider.searchProducts(query);
      if (result['success'] == true && mounted) {
        setState(() {
          _searchResults = (result['data'] as List<dynamic>?)
              ?.map((e) => e as ProductModel)
              .toList() ??
              [];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  void _addToCart(ProductModel product) {
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.product.id == product.id);
      if (idx >= 0) {
        _cartItems[idx].quantity++;
      } else {
        final customPrice = _hasCustomerPrice(product)
            ? _customerPriceMap[product.id]
            : null;
        _cartItems.add(SaleItem(
          product: product,
          unitPrice: _resolvePrice(product),
          customerSpecificPrice: customPrice,
          usingCustomerPrice: customPrice != null,
        ));
      }
      _searchController.clear();
      _searchResults = [];
    });
    HapticFeedback.lightImpact();
  }

  void _removeFromCart(int index) => setState(() => _cartItems.removeAt(index));

  void _updateQty(int index, int delta) {
    setState(() {
      _cartItems[index].quantity =
          (_cartItems[index].quantity + delta).clamp(1, 9999);
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _selectedCustomer = null;
      _discountAmount = 0;
      _discountPercent = 0;
      _useCustomerPrices = false;
      _customerPriceMap = {};
      _showOptionsPanel = false;
      _referenceController.clear();
    });
    _syncDiscountControllers();  // Add this
  }

  void _switchMode(bool pos) {
    setState(() => _isPosMode = pos);
    pos ? _toggleAnim.reverse() : _toggleAnim.forward();
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: _isPrefilling
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7C3AED)),
            SizedBox(height: 16),
            Text('Loading sale data…',
                style: TextStyle(color: Color(0xFF9CA3AF))),
          ],
        ),
      )
          : Column(
        children: [
          _buildHeader(),
          Expanded(
              child: _isPosMode
                  ? _buildPosLayout()
                  : _buildInvoiceLayout()),
        ],
      ),
    );
  }

  // ── HEADER ───────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode
                    ? 'Edit ${widget.existingSale!.invoiceNumber}'
                    : 'Sales',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D)),
              ),
              Text(
                _isEditMode
                    ? 'Editing existing sale'
                    : 'Create & manage sales transactions',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const Spacer(),
          // ── Sale Type Toggle — hidden in edit mode ──
          if (!_isEditMode) ...[
            Container(
              height: 42,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildSaleTypeToggle(SaleType.filled),
                  _buildSaleTypeToggle(SaleType.sarya),
                ],
              ),
            ),
            Container(
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F8),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _buildToggleBtn('POS Counter', Icons.point_of_sale, true),
                  _buildToggleBtn('Invoice', Icons.receipt_long, false),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ] else ...[
            // Edit mode: show read-only type badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedSaleType == SaleType.sarya
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedSaleType == SaleType.sarya
                      ? const Color(0xFF3B82F6).withOpacity(0.4)
                      : const Color(0xFF10B981).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedSaleType == SaleType.sarya
                        ? Icons.scale
                        : Icons.production_quantity_limits,
                    size: 14,
                    color: _selectedSaleType == SaleType.sarya
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedSaleType.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedSaleType == SaleType.sarya
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPosMode ? Icons.point_of_sale : Icons.receipt_long,
                    size: 14,
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isPosMode ? 'POS Counter' : 'Invoice',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (_cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFEF4444)),
              label: const Text('Clear',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildSaleTypeToggle(SaleType type) {
    final isActive = _selectedSaleType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSaleType = type;
          _clearCart(); // Clear cart when switching sale types
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive
              ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              type == SaleType.sarya ? Icons.scale : Icons.production_quantity_limits,
              size: 15,
              color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String label, IconData icon, bool isPos) {
    final isActive = _isPosMode == isPos;
    return GestureDetector(
      onTap: () => _switchMode(isPos),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive
              ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  // ── LAYOUTS ──────────────────────────────────

  Widget _buildPosLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _buildProductPanel()),
              _buildLeftOptionsPanel(),
            ],
          ),
        ),
        Container(
          width: 390,
          decoration: const BoxDecoration(
            color: Colors.white,
            border:
            Border(left: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
          ),
          child: _buildCartPanel(isPOS: true),
        ),
      ],
    );
  }

  Widget _buildInvoiceLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildInvoiceMeta(),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 12),
                if (_searchResults.isNotEmpty) _buildSearchDropdown(),
                const SizedBox(height: 16),
                _buildInvoiceItemsTable(),
                const SizedBox(height: 16),
                _buildInvoiceOptionsCard(),
                const SizedBox(height: 16),
                _buildInvoiceNotes(),
              ],
            ),
          ),
        ),
        Container(
          width: 420,
          decoration: const BoxDecoration(
            color: Colors.white,
            border:
            Border(left: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
          ),
          child: _buildCartPanel(isPOS: false),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  LEFT OPTIONS PANEL
  // ─────────────────────────────────────────────

  Widget _buildLeftOptionsPanel() {
    final hasCustomer = _selectedCustomer != null;
    final hasCustomerDiscount =
        hasCustomer && _selectedCustomer!.discountPercent > 0;
    final bool usingCustomerDiscount = hasCustomerDiscount &&
        _usePercentDiscount &&
        _discountPercent == _selectedCustomer!.discountPercent;

    int activeOptions = 0;
    if (_useCustomerPrices && _customerPriceMap.isNotEmpty) activeOptions++;
    if (_discountValue > 0) activeOptions++;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEF5))),
        boxShadow: _showOptionsPanel
            ? [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _showOptionsPanel = !_showOptionsPanel),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune,
                        size: 16, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 10),
                  const Text('Discount & Pricing',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(width: 8),
                  if (activeOptions > 0)
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$activeOptions active',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  if (_discountValue > 0) ...[
                    const SizedBox(width: 6),
                    _chip('- Rs ${_discountValue.toStringAsFixed(2)}',
                        const Color(0xFFECFDF5), const Color(0xFF065F46)),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showOptionsPanel ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 20, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _buildCompactDiscountSection(
                          usingCustomerDiscount, hasCustomerDiscount)),
                  const SizedBox(width: 12),
                  if (hasCustomer)
                    Expanded(child: _buildCompactCustomerPriceToggle()),
                ],
              ),
            ),
            crossFadeState: _showOptionsPanel
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 260),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDiscountSection(
      bool usingCustomerDiscount, bool hasCustomerDiscount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Discount',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() => _usePercentDiscount = !_usePercentDiscount);
                _syncDiscountControllers();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  _usePercentDiscount ? '% Percent' : 'Rs Fixed',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: TextField(
            // Use persistent controller instead of ValueKey
            controller: _usePercentDiscount
                ? _discountPercentCtrl
                : _discountAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: _usePercentDiscount ? '0.00 %' : '0.00 Rs',
              hintStyle: const TextStyle(fontSize: 12),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) {
              if (_updatingDiscountCtrl) return;
              final parsed = double.tryParse(v) ?? 0.0;
              setState(() {
                if (_usePercentDiscount) {
                  _discountPercent = parsed.clamp(0, 100);
                } else {
                  _discountAmount = parsed.clamp(0, _subtotal > 0 ? _subtotal : double.infinity);
                }
              });
            },
          ),
        ),
        if (hasCustomerDiscount) ...[
          const SizedBox(height: 8),
          _buildCustomerDiscountCheckbox(usingCustomerDiscount),
        ],
      ],
    );
  }

  Widget _buildCompactCustomerPriceToggle() {
    final activeCount = _cartItems.where((i) => i.usingCustomerPrice).length;
    final hasAnyCustom = _customerPriceMap.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customer Pricing',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _useCustomerPrices
                ? const Color(0xFFECFDF5)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _useCustomerPrices
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _useCustomerPrices,
                  onChanged: _isFetchingCustomerPrices
                      ? null
                      : (val) async {
                    setState(() => _useCustomerPrices = val ?? false);
                    await _fetchAndApplyCustomerPrices();
                  },
                  activeColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  side: const BorderSide(
                      color: Color(0xFF10B981), width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Customer Prices',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _useCustomerPrices
                            ? const Color(0xFF065F46)
                            : const Color(0xFF374151),
                      ),
                    ),
                    if (_useCustomerPrices && !_isFetchingCustomerPrices)
                      Text(
                        hasAnyCustom
                            ? '$activeCount item${activeCount != 1 ? 's' : ''} custom'
                            : 'No custom prices set',
                        style: TextStyle(
                            fontSize: 9,
                            color: hasAnyCustom
                                ? const Color(0xFF10B981)
                                : const Color(0xFF9CA3AF)),
                      ),
                  ],
                ),
              ),
              if (_isFetchingCustomerPrices)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF10B981)))
              else if (_useCustomerPrices && hasAnyCustom)
                const Icon(Icons.verified, size: 14, color: Color(0xFF10B981)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceOptionsCard() {
    final hasCustomer = _selectedCustomer != null;
    final hasCustomerDiscount =
        hasCustomer && _selectedCustomer!.discountPercent > 0;
    final bool usingCustomerDiscount = hasCustomerDiscount &&
        _usePercentDiscount &&
        _discountPercent == _selectedCustomer!.discountPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, size: 16, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('Discount & Pricing',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2D))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildCompactDiscountSection(
                      usingCustomerDiscount, hasCustomerDiscount)),
              if (hasCustomer) ...[
                const SizedBox(width: 16),
                Expanded(child: _buildCompactCustomerPriceToggle()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── CATEGORY CHIPS ────────────────────────────

  List<String> get _categories {
    return _allProducts
        .map((p) => p.category?.name ?? 'Uncategorized')
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _subcategories {
    if (_selectedCategory == null) return [];
    return _allProducts
        .where((p) => (p.category?.name ?? 'Uncategorized') == _selectedCategory)
        .map((p) => p.subcategory?.name ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<ProductModel> get _filteredBrowseProducts {
    return _allProducts.where((p) {
      final cat = p.category?.name ?? 'Uncategorized';
      final sub = p.subcategory?.name ?? '';
      if (_selectedCategory != null && cat != _selectedCategory) return false;
      if (_selectedSubcategory != null && sub != _selectedSubcategory)
        return false;
      return true;
    }).toList();
  }

  Widget _buildCategoryChips() {
    final cats = _categories;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _filterChip(
            label: 'All',
            icon: Icons.grid_view_rounded,
            selected: _selectedCategory == null,
            color: const Color(0xFF7C3AED),
            onTap: () => setState(() {
              _selectedCategory = null;
              _selectedSubcategory = null;
            }),
          ),
          const SizedBox(width: 6),
          ...cats.map((cat) {
            final count = _allProducts
                .where((p) => (p.category?.name ?? 'Uncategorized') == cat)
                .length;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _filterChip(
                label: '$cat ($count)',
                selected: _selectedCategory == cat,
                color: const Color(0xFF3B82F6),
                onTap: () => setState(() {
                  _selectedCategory = _selectedCategory == cat ? null : cat;
                  _selectedSubcategory = null;
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubcategoryChips() {
    final subs = _subcategories;
    if (subs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _filterChip(
            label: 'All sub',
            selected: _selectedSubcategory == null,
            color: const Color(0xFF10B981),
            small: true,
            onTap: () => setState(() => _selectedSubcategory = null),
          ),
          const SizedBox(width: 6),
          ...subs.map((sub) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _filterChip(
              label: sub,
              selected: _selectedSubcategory == sub,
              color: const Color(0xFF10B981),
              small: true,
              onTap: () => setState(() {
                _selectedSubcategory =
                _selectedSubcategory == sub ? null : sub;
              }),
            ),
          )),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
    bool small = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12, vertical: small ? 4 : 5),
        decoration: BoxDecoration(
          color:
          selected ? color.withOpacity(0.12) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: small ? 12 : 13,
                  color: selected ? color : const Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: small ? 10 : 11,
                    fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                    selected ? color : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  // ── PRODUCT PANEL ────────────────────────────

  Widget _buildProductPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              _buildSearchBar(),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSearchDropdown(),
              ],
            ],
          ),
        ),
        _buildCategoryChips(),
        if (_selectedCategory != null) _buildSubcategoryChips(),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        Expanded(
          child: _searchController.text.isNotEmpty
              ? (_searchResults.isEmpty && !_isSearching
              ? _buildNoResults()
              : const SizedBox.shrink())
              : _buildBrowseProductList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: _isPosMode,
        decoration: InputDecoration(
          hintText: 'Scan barcode or search by product name / barcode…',
          hintStyle:
          const TextStyle(fontSize: 14, color: Color(0xFFB0B7C3)),
          prefixIcon: _isSearching
              ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.search, color: Color(0xFF9CA3AF)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchResults = []);
              })
              : IconButton(
            icon: const Icon(Icons.qr_code_scanner,
                color: Color(0xFF7C3AED)),
            onPressed: _showBarcodeScanDialog,
            tooltip: 'Scan Barcode',
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) {
          if (_searchResults.length == 1) _addToCart(_searchResults.first);
        },
      ),
    );
  }

  Widget _buildSearchDropdown() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        itemBuilder: (context, i) {
          final p = _searchResults[i];
          final inCart = _cartItems.any((item) => item.product.id == p.id);
          final hasCustomPrice = _hasCustomerPrice(p);
          final displayPrice = _resolvePrice(p);
          final hasLengths = (p.lengthCombinations?.isNotEmpty ?? false);

          return ListTile(
            dense: true,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 20, color: Color(0xFF7C3AED)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(p.itemName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                if (hasLengths)
                  _chip('Multi-length', const Color(0xFFEDE9FE),
                      const Color(0xFF7C3AED)),
              ],
            ),
            subtitle: Text(
              '${p.barcode ?? 'No barcode'} · ${p.unit?.symbol ?? ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.physicalQty <= p.minStock)
                  _chip('Low Stock', const Color(0xFFFFF3CD),
                      const Color(0xFF92400E)),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs ${displayPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hasCustomPrice
                              ? const Color(0xFF10B981)
                              : const Color(0xFF7C3AED)),
                    ),
                    if (hasCustomPrice)
                      Text(
                        'Was Rs ${p.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                            decoration: TextDecoration.lineThrough),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                inCart
                    ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.check,
                        size: 16, color: Color(0xFF10B981)))
                    : ElevatedButton(
                    onPressed: () => _addToCart(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Add',
                        style: TextStyle(
                            fontSize: 12, color: Colors.white))),
              ],
            ),
            onTap: () => _addToCart(p),
          );
        },
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration:
    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(text,
        style: TextStyle(
            fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
  );

  Widget _buildNoResults() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off,
            size: 48, color: Color(0xFFD1D5DB)),
        const SizedBox(height: 12),
        Text(
          'No products found for "${_searchController.text}"',
          style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 14),
        ),
      ],
    ),
  );

  Widget _buildBrowseProductList() {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    final products = _filteredBrowseProducts;
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                  color: Color(0xFFF3F0FF), shape: BoxShape.circle),
              child: const Icon(Icons.point_of_sale,
                  size: 50, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 20),
            const Text('Ready to Scan',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D))),
            const SizedBox(height: 8),
            const Text(
              'Scan a barcode or type a product name\nto add items to the cart',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) => _buildProductCard(products[i]),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final inCart = _cartItems.any((item) => item.product.id == product.id);
    final hasCustomPrice = _hasCustomerPrice(product);
    final displayPrice = _resolvePrice(product);
    final isLowStock = product.physicalQty <= product.minStock;
    final hasLengths = product.lengthCombinations?.isNotEmpty ?? false;
    final catName = product.category?.name ?? '';
    final subName = product.subcategory?.name ?? '';
    final unitSymbol = product.unit?.symbol ?? '';

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: inCart ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart
                ? const Color(0xFF10B981).withOpacity(0.4)
                : const Color(0xFFE5E7EB),
            width: inCart ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: inCart ? const Color(0xFFDCFCE7) : const Color(0xFFF3F0FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.inventory_2_outlined,
                        size: 32, color: Color(0xFF7C3AED)),
                  ),
                  if (isLowStock)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Low',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E))),
                      ),
                    ),
                  if (hasLengths)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.lengthCombinations!.length}L',
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED)),
                        ),
                      ),
                    ),
                  if (inCart)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1E2D)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        if (catName.isNotEmpty)
                          _miniChip(catName, const Color(0xFFEDE9FE), const Color(0xFF7C3AED)),
                        if (subName.isNotEmpty)
                          _miniChip(subName, const Color(0xFFD1FAE5), const Color(0xFF065F46)),
                        if (unitSymbol.isNotEmpty)
                          _miniChip(unitSymbol, const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'Rs ${displayPrice.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: hasCustomPrice
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF7C3AED)),
                                  ),
                                  if (unitSymbol.isNotEmpty) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '/$unitSymbol',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF9CA3AF),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                              ),
                              if (hasCustomPrice)
                                Text(
                                  'Rs ${product.salePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF9CA3AF),
                                      decoration: TextDecoration.lineThrough),
                                ),
                            ],
                          ),
                        ),
                        if (inCart)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '×${_cartItems.firstWhere((i) => i.product.id == product.id).quantity}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration:
    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(text,
        style: TextStyle(
            fontSize: 9, color: fg, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis),
  );

  // ── CART PANEL (RIGHT) ─────────────────────────

  Widget _buildCartPanel({required bool isPOS}) {
    final isInvoiceMode = !isPOS;

    return Column(
      children: [
        _buildCustomerSection(),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        Expanded(
          child: _cartItems.isEmpty
              ? _buildEmptyCart()
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _cartItems.length,
            itemBuilder: (ctx, i) => isInvoiceMode
                ? _buildCartItemForInvoice(i)  // Simplified version for invoice
                : _buildCartItem(i),            // Full version with controls for POS
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        _buildSummarySection(isPOS),
      ],
    );
  }

// Simplified cart item for invoice mode (no quantity/weight controls)
  Widget _buildCartItemForInvoice(int index) {
    final item = _cartItems[index];
    final showCustomBadge = item.usingCustomerPrice && item.hasPriceDifference;
    final hasLengths = item.product.lengthCombinations?.isNotEmpty ?? false;
    final isSaryaType = _selectedSaleType == SaleType.sarya;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.usingCustomerPrice ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.usingCustomerPrice
              ? const Color(0xFF10B981).withOpacity(0.25)
              : const Color(0xFFF0F0F8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with delete button
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${item.product.itemName} (${item.product.unit?.symbol ?? ''})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showCustomBadge) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Custom ₹',
                            style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => _removeFromCart(index),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Price and Total row (no quantity/weight controls)
          Row(
            children: [
              // Price column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Rs ${item.unitPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.usingCustomerPrice ? const Color(0xFF065F46) : const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  if (showCustomBadge)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Std: Rs ${item.standardPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9CA3AF), decoration: TextDecoration.lineThrough),
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Quantity/Weight display (read-only)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSaryaType
                          ? '${item.weight.toStringAsFixed(2)} Kg'
                          : '${item.quantity} ${item.product.unit?.symbol ?? 'pcs'}',  // ← fix here
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),

              // Total column
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.usingCustomerPrice
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Rs ${item.totalForMode(isSaryaType).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: item.usingCustomerPrice ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),

          // Length chips (if any)
          if (item.hasLengthCombinations) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected Lengths & Quantities:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal[700]),
                      ),
                      Text(
                        '${item.totalPieces} pcs total',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.selectedLengths.map((length) {
                      final qty = item.lengthQuantities[length] ?? 1.0;
                      return Chip(
                        label: Text(_safeLengthLabel(length, qty), style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFFD1FAE5),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeLengthFromCartItem(index, length),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showCustomerPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedCustomer != null
                          ? const Color(0xFFF3F0FF)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedCustomer != null
                            ? const Color(0xFF7C3AED).withOpacity(0.3)
                            : const Color(0xFFEF4444).withOpacity(0.5),
                        width: _selectedCustomer == null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedCustomer != null
                              ? Icons.person
                              : Icons.person_add_alt,
                          size: 18,
                          color: _selectedCustomer != null
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCustomer?.name ?? 'Select Customer *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedCustomer != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _selectedCustomer != null
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFFEF4444),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              // ✅ ADD BALANCE DISPLAY HERE
                              if (_selectedCustomer != null && _selectedCustomer!.balance != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet,
                                        size: 10, color: _selectedCustomer!.balance! > 0
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Balance: Rs ${_selectedCustomer!.balance!.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: _selectedCustomer!.balance! > 0
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                    if (_selectedCustomer!.balance! > 0) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'Credit',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_selectedCustomer != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedCustomer = null;
                              _useCustomerPrices = false;
                              _customerPriceMap = {};
                              _discountAmount = 0;
                              _discountPercent = 0;
                              _showOptionsPanel = false;
                              for (final item in _cartItems) {
                                item.usingCustomerPrice = false;
                                item.customerSpecificPrice = null;
                                item.unitPrice = item.standardPrice;
                              }
                            }),
                            child: const Icon(Icons.close,
                                size: 14, color: Color(0xFF9CA3AF)),
                          )
                        else
                          const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showAddCustomerDialog,
                icon: const Icon(Icons.person_add, size: 20),
                tooltip: 'Add New Customer',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F0FF),
                  foregroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          if (_selectedCustomer == null && _cartItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFFEF4444)),
                SizedBox(width: 4),
                Text(
                  'Customer selection is required to proceed',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (_selectedCustomer != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_selectedCustomer!.discountPercent > 0)
                  _chip(
                      '${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% discount',
                      const Color(0xFFF3F0FF),
                      const Color(0xFF7C3AED)),
                if (_discountValue > 0) ...[
                  const SizedBox(width: 6),
                  _chip('Disc: Rs ${_discountValue.toStringAsFixed(2)}',
                      const Color(0xFFECFDF5), const Color(0xFF065F46)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildCartItem(int index) {
    final item = _cartItems[index];
    final showCustomBadge = item.usingCustomerPrice && item.hasPriceDifference;
    final hasLengths = item.product.lengthCombinations?.isNotEmpty ?? false;
    final isSaryaType = _selectedSaleType == SaleType.sarya;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.usingCustomerPrice ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.usingCustomerPrice
              ? const Color(0xFF10B981).withOpacity(0.25)
              : const Color(0xFFF0F0F8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${item.product.itemName} (${item.product.unit?.symbol ?? ''})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showCustomBadge) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Custom ₹',
                            style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => _removeFromCart(index),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Price + Quantity/Weight row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: TextFormField(
                      key: ValueKey('price_${index}_${item.unitPrice}'),
                      initialValue: item.unitPrice.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 12,
                        color: item.usingCustomerPrice ? const Color(0xFF065F46) : null,
                        fontWeight: item.usingCustomerPrice ? FontWeight.w600 : FontWeight.normal,
                      ),
                      decoration: InputDecoration(
                        prefix: Text('Rs ', style: const TextStyle(fontSize: 11)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: item.usingCustomerPrice
                                ? const Color(0xFF10B981).withOpacity(0.5)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          setState(() => _cartItems[index].unitPrice = parsed);
                        }
                      },
                    ),
                  ),
                  if (showCustomBadge)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Std: Rs ${item.standardPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9CA3AF), decoration: TextDecoration.lineThrough),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 8),

              // Quantity/Weight Input based on sale type
              if (isSaryaType)
                Expanded(
                  child: _buildWeightInputFieldWithButtons(index),
                )
              else
                Expanded(
                  child: _buildQuantityInputField(index),
                ),

              const SizedBox(width: 8),

              // Total column
              SizedBox(
                width: 72,
                child: Text(
                  'Rs ${item.totalForMode(isSaryaType).toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: item.usingCustomerPrice ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),

          // Weight field for FILLED items with lengths (optional weight tracking)
          if (!isSaryaType && hasLengths) ...[
            const SizedBox(height: 6),
            _buildWeightInputFieldSimple(index),
          ],

          // Select Lengths button (only when product has combinations)
          if (hasLengths) ...[
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: () => _showLengthSelectionDialog(index),
              icon: const Icon(Icons.straighten, size: 14),
              label: Text(
                item.hasLengthCombinations ? 'Edit Lengths' : 'Select Lengths',
                style: const TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: item.hasLengthCombinations ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],

          // Length chips
          if (item.hasLengthCombinations) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected Lengths & Quantities:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal[700]),
                      ),
                      Text(
                        '${item.totalPieces} pcs total',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.selectedLengths.map((length) {
                      final qty = item.lengthQuantities[length] ?? 1.0;
                      return Chip(
                        label: Text(_safeLengthLabel(length, qty), style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFFD1FAE5),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeLengthFromCartItem(index, length),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

// For SARYA - Weight input with increment/decrement buttons (like quantity)
  Widget _buildWeightInputFieldWithButtons(int index) {
    final item = _cartItems[index];

    return Row(
      children: [
        _weightBtn(Icons.remove, () {
          setState(() {
            final newWeight = (item.weight - 0.5).clamp(0.0, 9999.0);
            final old = _cartItems[index];
            _cartItems[index] = SaleItem(
              product: old.product,
              quantity: old.quantity,
              unitPrice: old.unitPrice,
              customerSpecificPrice: old.customerSpecificPrice,
              usingCustomerPrice: old.usingCustomerPrice,
              selectedLengths: old.selectedLengths,
              lengthQuantities: old.lengthQuantities,
              lengthsDisplay: old.lengthsDisplay,
              weight: newWeight,
            );
          });
        }),
        SizedBox(
          width: 70,
          child: TextField(
            key: ValueKey('weight_${index}_${item.weight}'),
            controller: TextEditingController(
              text: item.weight > 0 ? item.weight.toStringAsFixed(2) : '0.00',
            )..selection = TextSelection.collapsed(
              offset: (item.weight > 0 ? item.weight.toStringAsFixed(2) : '0.00').length,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              // suffixText: 'Kg',
              suffixText: _cartItems[index].product.unit?.symbol ?? 'pcs',
              suffixStyle: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
            ),
            onChanged: (v) {
              final w = double.tryParse(v) ?? 0.0;
              setState(() {
                final old = _cartItems[index];
                _cartItems[index] = SaleItem(
                  product: old.product,
                  quantity: old.quantity,
                  unitPrice: old.unitPrice,
                  customerSpecificPrice: old.customerSpecificPrice,
                  usingCustomerPrice: old.usingCustomerPrice,
                  selectedLengths: old.selectedLengths,
                  lengthQuantities: old.lengthQuantities,
                  lengthsDisplay: old.lengthsDisplay,
                  weight: w.clamp(0.0, 9999.0),
                );
              });
            },
          ),
        ),
        _weightBtn(Icons.add, () {
          setState(() {
            final newWeight = (item.weight + 0.5).clamp(0.0, 9999.0);
            final old = _cartItems[index];
            _cartItems[index] = SaleItem(
              product: old.product,
              quantity: old.quantity,
              unitPrice: old.unitPrice,
              customerSpecificPrice: old.customerSpecificPrice,
              usingCustomerPrice: old.usingCustomerPrice,
              selectedLengths: old.selectedLengths,
              lengthQuantities: old.lengthQuantities,
              lengthsDisplay: old.lengthsDisplay,
              weight: newWeight,
            );
          });
        }),
      ],
    );
  }

// For FILLED - Quantity input with increment/decrement buttons
  Widget _buildQuantityInputField(int index) {
    final item = _cartItems[index];
    return Row(
      children: [
        _qtyBtn(Icons.remove, () => _updateQty(index, -1)),
        SizedBox(
          width: 60,
          child: TextField(
            key: ValueKey('qty_$index'),
            controller: TextEditingController(text: item.quantity.toString())
              ..selection = TextSelection.collapsed(offset: item.quantity.toString().length),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              // suffixText: 'pcs',
              suffixText: item.product.unit?.symbol ?? 'pcs',
              suffixStyle: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null && parsed >= 0) {
                setState(() => _cartItems[index].quantity = parsed.clamp(0, 9999));
              }
            },
            onSubmitted: (v) {
              final parsed = int.tryParse(v);
              if (parsed == null || parsed < 0) {
                setState(() => _cartItems[index].quantity = 1);
              }
            },
          ),
        ),
        _qtyBtn(Icons.add, () => _updateQty(index, 1)),
      ],
    );
  }

// Simple weight input for FILLED items (optional weight tracking)
  Widget _buildWeightInputFieldSimple(int index) {
    final item = _cartItems[index];
    return SizedBox(
      height: 32,
      child: TextFormField(
        key: ValueKey('weight_simple_${index}_${item.weight}'),
        initialValue: item.weight > 0 ? item.weight.toStringAsFixed(2) : '',
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: 'Weight (Kg) - Optional',
          labelStyle: const TextStyle(fontSize: 11),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          prefixIcon: const Icon(Icons.scale, size: 14),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          final w = double.tryParse(v) ?? 0.0;
          setState(() {
            final old = _cartItems[index];
            _cartItems[index] = SaleItem(
              product: old.product,
              quantity: old.quantity,
              unitPrice: old.unitPrice,
              customerSpecificPrice: old.customerSpecificPrice,
              usingCustomerPrice: old.usingCustomerPrice,
              selectedLengths: old.selectedLengths,
              lengthQuantities: old.lengthQuantities,
              lengthsDisplay: old.lengthsDisplay,
              weight: w,
            );
          });
        },
      ),
    );
  }

  Future<void> _submitEdit() async {
    if (_selectedSaleType == SaleType.sarya) {
      final missing = _cartItems.where((i) => i.weight <= 0).toList();
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'SARYA mode: ${missing.length} item(s) missing weight'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final isSarya = _selectedSaleType == SaleType.sarya;

    final saleData = {
      'sale_category': _selectedSaleType.apiValue,
      'customer_id': _selectedCustomer?.id,
      'sale_date': _invoiceDate.toIso8601String().split('T').first,
      'due_date': _dueDate?.toIso8601String().split('T').first,
      'reference': _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      'notes': _invoiceNoteController.text.trim(),
      'discount_type': _usePercentDiscount ? 'percent' : 'fixed',
      'discount_value':
      _usePercentDiscount ? _discountPercent : _discountAmount,
      'items': _cartItems.map((item) {
        final Map<String, dynamic> d = {
          'product_id': item.product.id,
          'unit_price': item.unitPrice,
          'used_customer_price': item.usingCustomerPrice,
        };
        if (isSarya) {
          d['weight'] = item.weight;
          d['quantity'] = 0;
        } else {
          d['quantity'] = item.quantity;
          if (item.weight > 0) d['weight'] = item.weight;
        }
        if (item.selectedLengths.isNotEmpty) {
          d['selected_lengths'] = item.selectedLengths;
        }
        if (item.lengthQuantities.isNotEmpty) {
          d['length_quantities'] = Map<String, dynamic>.fromEntries(
            item.lengthQuantities.entries
                .map((e) => MapEntry(e.key.toString(), e.value)),
          );
        }
        return d;
      }).toList(),
    };

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final result =
    await provider.updateSale(widget.existingSale!.id, saleData);

    if (mounted) Navigator.pop(context); // dismiss loader

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sale updated successfully'),
            backgroundColor: Color(0xFF10B981)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Failed to update sale'),
            backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

// Weight button for increment/decrement
  Widget _weightBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
    ),
  );

// Quantity button
  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: const Color(0xFF7C3AED)),
    ),
  );


  Widget _buildEmptyCart() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shopping_cart_outlined,
            size: 48, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('Cart is empty',
            style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
        SizedBox(height: 4),
        Text('Add products using search',
            style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
      ],
    ),
  );

  Widget _buildCustomerDiscountCheckbox(bool usingCustomerDiscount) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: usingCustomerDiscount ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: usingCustomerDiscount
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: usingCustomerDiscount,
              onChanged: (val) {
                if (val == true) {
                  _applyCustomerDiscount();
                } else {
                  setState(() {
                    _discountPercent = 0;
                    _discountAmount = 0;
                  });
                  _syncDiscountControllers();  // Add this
                }
              },
              activeColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              usingCustomerDiscount
                  ? 'Applied ${_selectedCustomer!.discountPercent.toStringAsFixed(1)}%'
                  : '${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% for ${_selectedCustomer!.name}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: usingCustomerDiscount ? const Color(0xFF065F46) : const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyCustomerDiscount() {
    if (_selectedCustomer == null) return;
    setState(() {
      _usePercentDiscount = true;
      _discountPercent = _selectedCustomer!.discountPercent;
    });
    _syncDiscountControllers();  // Add this
  }

  // ── SUMMARY + ACTIONS ─────────────────────────

  Widget _buildSummarySection(bool isPOS) {
    final customCount = _cartItems.where((i) => i.usingCustomerPrice).length;
    final lengthCount = _cartItems.where((i) => i.hasLengthCombinations).length;
    final isSarya = _selectedSaleType == SaleType.sarya;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _summaryRow('Subtotal', 'Rs ${_subtotal.toStringAsFixed(2)}'),
          if (_discountValue > 0)
            _summaryRow(
                'Discount', '- Rs ${_discountValue.toStringAsFixed(2)}',
                color: const Color(0xFF10B981)),
          if (_customerPriceSavings > 0)
            _summaryRow(
              'Customer Savings',
              '- Rs ${_customerPriceSavings.toStringAsFixed(2)}',
              color: const Color(0xFF10B981),
              icon: Icons.sell_outlined,
            ),
          // Show calculation type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSarya ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSarya ? Icons.scale : Icons.production_quantity_limits,
                  size: 12,
                  color: isSarya ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  isSarya ? 'Calculated by weight (Kg)' : 'Calculated by pieces',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSarya ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          _summaryRow('Total', 'Rs ${_grandTotal.toStringAsFixed(2)}',
              isBold: true, fontSize: 16),

          // ── Length info badge ──
          if (lengthCount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.straighten,
                      size: 13, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    '$lengthCount item${lengthCount != 1 ? 's' : ''} with length selections',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5B21B6),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],

          if (_useCustomerPrices && customCount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.local_offer,
                      size: 13, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$customCount item${customCount != 1 ? 's' : ''} priced for ${_selectedCustomer!.name}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          if (_cartItems.isNotEmpty && _selectedCustomer != null) ...[
            OutlinedButton.icon(
              onPressed: _showQuickPrintPreview,
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Quick Print Preview',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // if (isPOS)
          //   ElevatedButton.icon(
          //     onPressed:
          //     (_cartItems.isEmpty || _selectedCustomer == null)
          //         ? null
          //         : _processPayment,
          //     icon: const Icon(Icons.payment, size: 16),
          //     label: const Text('Charge',
          //         style:
          //         TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: const Color(0xFF7C3AED),
          //       foregroundColor: Colors.white,
          //       padding: const EdgeInsets.symmetric(vertical: 14),
          //       minimumSize: const Size(double.infinity, 48),
          //       shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(10)),
          //       elevation: 0,
          //     ),
          //   )
          // else
          //   ElevatedButton.icon(
          //     onPressed: _cartItems.isEmpty ? null : _createInvoice,
          //     icon: const Icon(Icons.receipt_long, size: 16),
          //     label: const Text('Create Invoice',
          //         style: TextStyle(fontWeight: FontWeight.bold)),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: const Color(0xFF7C3AED),
          //       foregroundColor: Colors.white,
          //       padding: const EdgeInsets.symmetric(vertical: 14),
          //       minimumSize: const Size(double.infinity, 48),
          //       shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(10)),
          //       elevation: 0,
          //     ),
          //   ),
          // Replace the last if/else in _buildSummarySection:
          if (_isEditMode)
            ElevatedButton.icon(
              onPressed: _cartItems.isEmpty ? null : _submitEdit,
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save Changes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            )
          else if (isPOS)
            ElevatedButton.icon(
              onPressed:
              (_cartItems.isEmpty || _selectedCustomer == null)
                  ? null
                  : _processPayment,
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Charge',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _cartItems.isEmpty ? null : _createInvoice,
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Create Invoice',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false,
        double fontSize = 13,
        Color? color,
        IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color ?? const Color(0xFF6B7280)),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  color: color ?? const Color(0xFF6B7280))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: color ?? const Color(0xFF1E1E2D))),
        ],
      ),
    );
  }

  // ── INVOICE WIDGETS ───────────────────────────

  Widget _buildInvoiceMeta() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice Details',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D))),
          const SizedBox(height: 16),
          // Add Reference Field here (above the date row)
          _buildReferenceField(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetaField(
                  label: 'Invoice Date',
                  value: _formatDate(_invoiceDate),
                  icon: Icons.calendar_today,
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030));
                    if (picked != null)
                      setState(() => _invoiceDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetaField(
                  label: 'Due Date (Optional)',
                  value: _dueDate != null
                      ? _formatDate(_dueDate!)
                      : 'Not set',
                  icon: Icons.event,
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate:
                        _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030));
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add this new method for the reference field
  Widget _buildReferenceField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt, size: 16, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reference Number',
                    style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                TextField(
                  controller: _referenceController,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'e.g., PO-12345, Order #, etc.',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFFB0B7C3)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (_referenceController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF9CA3AF)),
              onPressed: () => _referenceController.clear(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }


  Widget _buildMetaField(
      {required String label,
        required String value,
        required IconData icon,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsTable() {
    final isSaryaMode = _selectedSaleType == SaleType.sarya;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Items',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E2D))),
                const Spacer(),
                // ✅ SALE MODE INDICATOR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSaryaMode ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSaryaMode ? Icons.scale : Icons.production_quantity_limits,
                        size: 12,
                        color: isSaryaMode ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSaryaMode ? 'Weight-based' : 'Qty-based',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSaryaMode ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_useCustomerPrices && _selectedCustomer != null) ...[
                  const SizedBox(width: 12),
                  _chip('Customer Prices Active',
                      const Color(0xFFECFDF5), const Color(0xFF065F46)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                const Expanded(
                    flex: 4,
                    child: Text('#  Product',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                Expanded(
                    child: Text(
                      isSaryaMode ? 'Weight (Kg)' : 'Quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280)),
                    )),
                const Expanded(
                    child: Text('Price/Unit',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                const Expanded(
                    child: Text('Total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280)))),
                const SizedBox(width: 32),
              ],
            ),
          ),
          if (_cartItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('No items added yet',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 14))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (ctx, i) {
                final item = _cartItems[i];
                final hasLengths =
                    item.product.lengthCombinations?.isNotEmpty ?? false;

                return Container(
                  color: item.usingCustomerPrice
                      ? const Color(0xFFF0FDF4)
                      : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}. ${item.product.itemName}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                if (item.usingCustomerPrice &&
                                    item.hasPriceDifference)
                                  Text(
                                      '${_selectedCustomer?.name ?? ''} price',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF10B981))),
                                if (item.hasLengthCombinations)
                                  Text(
                                    item.lengthsDisplay,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF7C3AED),
                                        fontStyle: FontStyle.italic),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                // ✅ SHOW WEIGHT FOR NON-SARYA ITEMS (optional tracking)
                                if (item.weight > 0 && !isSaryaMode)
                                  Text(
                                    'Weight: ${item.weight.toStringAsFixed(2)} Kg',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF1D4ED8)),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: isSaryaMode
                                ? _buildInvoiceWeightField(i)
                                : _buildInvoiceQuantityField(i),
                          ),
                          Expanded(
                            child: Text(
                              'Rs ${item.unitPrice.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: item.usingCustomerPrice
                                      ? const Color(0xFF10B981)
                                      : null),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Rs ${item.totalForMode(isSaryaMode).toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: item.usingCustomerPrice
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF7C3AED),
                                  fontSize: 13),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Color(0xFFEF4444)),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeFromCart(i),
                                ),
                                if (hasLengths)
                                  IconButton(
                                    icon: const Icon(Icons.straighten,
                                        size: 14, color: Color(0xFF7C3AED)),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Select Lengths',
                                    onPressed: () =>
                                        _showLengthSelectionDialog(i),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // ✅ WARNING FOR ZERO WEIGHT IN SARYA MODE
                      if (isSaryaMode && item.weight == 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_outlined,
                                  size: 14, color: Color(0xFF92400E)),
                              SizedBox(width: 6),
                              Text(
                                'Weight required for calculation',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // ✅ LENGTH CHIPS
                      if (item.hasLengthCombinations) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.selectedLengths.map((l) {
                              final q = item.lengthQuantities[l] ?? 1.0;
                              return Chip(
                                label: Text(_safeLengthLabel(l, q),
                                    style: const TextStyle(fontSize: 10)),
                                backgroundColor:
                                const Color(0xFFEDE9FE),
                                side: const BorderSide(
                                    color: Color(0xFF7C3AED)),
                                deleteIcon:
                                const Icon(Icons.close, size: 12),
                                onDeleted: () =>
                                    _removeLengthFromCartItem(i, l),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }


  Widget _buildInvoiceWeightField(int index) {
    final item = _cartItems[index];
    final hasValidWeight = item.weight > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _invoiceWeightBtn(Icons.remove, () {
          setState(() {
            final newWeight = (item.weight - 0.5).clamp(0.0, 9999.0);
            final old = _cartItems[index];
            _cartItems[index] = SaleItem(
              product: old.product,
              quantity: old.quantity,
              unitPrice: old.unitPrice,
              customerSpecificPrice: old.customerSpecificPrice,
              usingCustomerPrice: old.usingCustomerPrice,
              selectedLengths: old.selectedLengths,
              lengthQuantities: old.lengthQuantities,
              lengthsDisplay: old.lengthsDisplay,
              weight: newWeight,
            );
          });
        }),
        SizedBox(
          width: 70,
          child: TextFormField(
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            initialValue: item.weight > 0 ? item.weight.toStringAsFixed(2) : '0.00',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: hasValidWeight ? const Color(0xFF3B82F6) : const Color(0xFF9CA3AF),
            ),
            decoration: InputDecoration(
              suffixText: 'Kg',
              suffixStyle: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: hasValidWeight
                      ? const Color(0xFF3B82F6).withOpacity(0.5)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
            ),
            onChanged: (value) {
              final weight = double.tryParse(value);
              if (weight != null && weight > 0) {
                setState(() {
                  final old = _cartItems[index];
                  _cartItems[index] = SaleItem(
                    product: old.product,
                    quantity: old.quantity,
                    unitPrice: old.unitPrice,
                    customerSpecificPrice: old.customerSpecificPrice,
                    usingCustomerPrice: old.usingCustomerPrice,
                    selectedLengths: old.selectedLengths,
                    lengthQuantities: old.lengthQuantities,
                    lengthsDisplay: old.lengthsDisplay,
                    weight: weight.clamp(0.01, 9999.0),
                  );
                });
              } else if (weight == 0 || value.isEmpty) {
                setState(() {
                  final old = _cartItems[index];
                  _cartItems[index] = SaleItem(
                    product: old.product,
                    quantity: old.quantity,
                    unitPrice: old.unitPrice,
                    customerSpecificPrice: old.customerSpecificPrice,
                    usingCustomerPrice: old.usingCustomerPrice,
                    selectedLengths: old.selectedLengths,
                    lengthQuantities: old.lengthQuantities,
                    lengthsDisplay: old.lengthsDisplay,
                    weight: 0.0,
                  );
                });
              }
            },
            onFieldSubmitted: (value) {  // ✅ Correct for TextFormField
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Weight must be greater than 0 for SARYA items'),
                    backgroundColor: Color(0xFFEF4444),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
        _invoiceWeightBtn(Icons.add, () {
          setState(() {
            final newWeight = (item.weight + 0.5).clamp(0.0, 9999.0);
            final old = _cartItems[index];
            _cartItems[index] = SaleItem(
              product: old.product,
              quantity: old.quantity,
              unitPrice: old.unitPrice,
              customerSpecificPrice: old.customerSpecificPrice,
              usingCustomerPrice: old.usingCustomerPrice,
              selectedLengths: old.selectedLengths,
              lengthQuantities: old.lengthQuantities,
              lengthsDisplay: old.lengthsDisplay,
              weight: newWeight,
            );
          });
        }),
      ],
    );
  }

  Widget _buildInvoiceQuantityField(int index) {
    final item = _cartItems[index];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _qtyBtn(Icons.remove, () => _updateQty(index, -1)),

        SizedBox(
          width: 60,
          child: TextFormField(
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            initialValue: item.quantity.toString(),
            decoration: InputDecoration(
              // suffixText: 'pcs',
              suffixText: item.product.unit?.symbol ?? 'pcs',
              suffixStyle: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF7C3AED), width: 2),
              ),
            ),
            onChanged: (value) {
              final qty = int.tryParse(value);
              if (qty != null && qty >= 0) {
                setState(() {
                  item.quantity = qty;
                });
              }
            },
            // ✅ CORRECT: Use onFieldSubmitted instead of onSubmitted
            onFieldSubmitted: (value) {
              final qty = int.tryParse(value);
              if (qty == null || qty < 1) {
                setState(() {
                  item.quantity = 1;
                });
              }
            },
          ),
        ),

        _qtyBtn(Icons.add, () => _updateQty(index, 1)),
      ],
    );
  }

// Invoice weight button for increment/decrement
  Widget _invoiceWeightBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
    ),
  );

  Widget _buildInvoiceNotes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes / Terms',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D))),
          const SizedBox(height: 10),
          TextField(
            controller: _invoiceNoteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add notes or payment terms…',
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFB0B7C3)),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS ───────────────────────────────────

  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CustomerPickerSheet(
        selectedCustomer: _selectedCustomer,
        onSelected: (c) async {
          Navigator.pop(ctx);
          setState(() => _selectedCustomer = c);
          if (_useCustomerPrices) await _fetchAndApplyCustomerPrices();
        },
        onAddNew: () {
          Navigator.pop(ctx);
          _showAddCustomerDialog();
        },
      ),
    );
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddCustomerDialog(
        onCreated: (customer) async {
          setState(() => _selectedCustomer = customer);
          if (_useCustomerPrices) await _fetchAndApplyCustomerPrices();
        },
      ),
    );
  }

  void _showBarcodeScanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Scan Barcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                  child: Icon(Icons.qr_code_scanner,
                      size: 80, color: Color(0xFF7C3AED))),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use a barcode scanner device or enter manually below',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter or scan barcode',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.qr_code),
              ),
              onSubmitted: (barcode) {
                Navigator.pop(ctx);
                _searchController.text = barcode;
                _onSearchChanged();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  // ── SALE ACTIONS ──────────────────────────────

  void _processPayment() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer before processing payment'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PaymentDialog(
        total: _grandTotal,
        customerName: _selectedCustomer!.name,
        onConfirm: (method, amountReceived, paymentDetails) async {
          if (method == 'credit' && paymentDetails != null) {
            if (paymentDetails['due_date'] != null) {
              setState(
                      () => _creditDueDate = DateTime.parse(paymentDetails['due_date']));
            }
          } else {
            setState(() => _creditDueDate = null);
          }
          Navigator.pop(ctx);
          await _submitSale(
            saleType: 'pos',
            paymentMethod: method,
            amountPaid: amountReceived,
            paymentDetails: paymentDetails,
          );
        },
      ),
    );
  }

  void _createInvoice() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer for the invoice'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PaymentDialog(
        total: _grandTotal,
        customerName: _selectedCustomer!.name,
        isInvoice: true,
        onConfirm: (method, amountReceived, paymentDetails) async {
          if (method == 'credit' && paymentDetails != null) {
            if (paymentDetails['due_date'] != null) {
              setState(
                      () => _creditDueDate = DateTime.parse(paymentDetails['due_date']));
            }
          } else {
            setState(() => _creditDueDate = null);
          }
          Navigator.pop(ctx);
          await _submitSale(
            saleType: 'invoice',
            paymentMethod: method,
            amountPaid: amountReceived,
            paymentDetails: paymentDetails,
          );
        },
      ),
    );
  }

  void _showPrintDialog(Uint8List pdfData, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Document Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F0FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long,
                  size: 40, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your document has been created successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(invoiceNumber,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF7C3AED))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SalePdfGenerator.sharePdf(pdfData, '$invoiceNumber.pdf');
            },
            child: const Text('Share'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SalePdfGenerator.printPdf(pdfData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  void _showPrintOptionsSheet(Uint8List pdfData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    borderRadius: BorderRadius.circular(2))),
            const Text('Print Options',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPrintOption(
                    icon: Icons.print,
                    label: 'Print',
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.pop(ctx);
                      SalePdfGenerator.printPdf(pdfData);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrintOption(
                    icon: Icons.share,
                    label: 'Share',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(ctx);
                      SalePdfGenerator.sharePdf(pdfData, 'receipt.pdf');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPrintOption(
              icon: Icons.visibility,
              label: 'Preview',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.pop(ctx);
                _showPdfPreview(pdfData);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
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
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (_) => pdfData);
  }

  Future<void> _showQuickPrintPreview() async {
    if (_cartItems.isEmpty || _selectedCustomer == null) return;

    // In both _showQuickPrintPreview and _submitSale, update the items map:
    final items = _cartItems.map((item) => {
      'product_name': item.product.itemName,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'selected_lengths': item.selectedLengths,
      'lengths_display': item.lengthsDisplay,
      // ✅ ADD THIS — needed by PDF for the breakdown chips
      'length_quantities': Map<String, dynamic>.fromEntries(
        item.lengthQuantities.entries.map(
              (e) => MapEntry(e.key.toString(), e.value),
        ),
      ),
      'weight': item.weight,
    }).toList();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfData = await SalePdfGenerator.generateSalePdf(
        saleData: {
          'invoice_number': 'PREVIEW-${DateTime.now().millisecondsSinceEpoch}',
          'reference': _referenceController.text.trim(),  // ✅ ADD THIS LINE
        },
        customer: _selectedCustomer,
        items: items,
        subtotal: _subtotal,
        discountValue: _discountValue,
        grandTotal: _grandTotal,
        isPosMode: _isPosMode,
        paymentMethod: 'preview',
        amountPaid: _grandTotal,
        dueDate: null,
        notes: _invoiceNoteController.text,
        previousBalance: _selectedCustomer?.balance ?? 0.0, // ✅ ADD THIS LINE
      );

      if (mounted) Navigator.pop(context);
      _showPrintOptionsSheet(pdfData);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to generate preview: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // ── SUBMIT ─────────────────────────────────────

  Future<void> _submitSale({
    required String saleType,
    required String paymentMethod,
    required double amountPaid,
    Map<String, dynamic>? paymentDetails,
  }) async {
    // VALIDATION: SARYA mode requires weight for all items
    if (_selectedSaleType == SaleType.sarya) {
      final itemsWithoutWeight = _cartItems.where((item) => item.weight <= 0).toList();
      if (itemsWithoutWeight.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SARYA mode requires weight for all items. '
                  '${itemsWithoutWeight.length} item(s) have missing weight.',
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final bool isCredit = paymentMethod == 'credit';
    final finalAmountPaid = isCredit ? 0.0 : amountPaid;

    double discountAmount = _usePercentDiscount
        ? _subtotal * (_discountPercent / 100)
        : _discountAmount;
    discountAmount = discountAmount.clamp(0, _subtotal);

    // CRITICAL FIX: Build items with correct fields based on sale type
    final saleData = {
      'sale_type': saleType,
      'sale_category': _selectedSaleType.apiValue,
      'customer_id': _selectedCustomer?.id,
      'sale_date': _invoiceDate.toIso8601String().split('T').first,
      'reference': _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      'due_date': isCredit && _creditDueDate != null
          ? _creditDueDate!.toIso8601String().split('T').first
          : _dueDate?.toIso8601String().split('T').first,
      'items': _cartItems.map((item) {
        // Base item data
        final Map<String, dynamic> itemData = {
          'product_id': item.product.id,
          'unit_price': item.unitPrice,
          'used_customer_price': item.usingCustomerPrice,
        };

        if (_selectedSaleType == SaleType.sarya) {
          // SARYA mode: weight is primary, quantity is ALWAYS 0
          itemData['weight'] = item.weight;
          itemData['quantity'] = 0; // ✅ CRITICAL: Set quantity to 0 for weight-based items
        } else {
          // FILLED mode: quantity is primary
          itemData['quantity'] = item.quantity;
          // Weight is optional for FILLED items (for tracking only)
          if (item.weight > 0) {
            itemData['weight'] = item.weight;
          }
        }

        // Add length fields if present
        if (item.selectedLengths.isNotEmpty) {
          itemData['selected_lengths'] = item.selectedLengths;
        }
        if (item.lengthQuantities.isNotEmpty) {
          itemData['length_quantities'] = Map<String, dynamic>.fromEntries(
            item.lengthQuantities.entries.map(
                  (e) => MapEntry(e.key.toString(), e.value),
            ),
          );
        }

        return itemData;
      }).toList(),
      'discount_type': _usePercentDiscount ? 'percent' : 'fixed',
      'discount_value': _usePercentDiscount ? _discountPercent : _discountAmount,
      'payment_method': paymentMethod,
      'amount_paid': finalAmountPaid,
      'payment_status': isCredit ? 'unpaid' : null,
      'notes': _buildNotes(paymentMethod, paymentDetails),
    };

    // Debug log to verify quantities (FIXED: null-safe iteration)
    print('Submitting sale:');
    print('  Sale category: ${_selectedSaleType.apiValue}');
    final itemsList = saleData['items'] as List<dynamic>?;
    if (itemsList != null) {
      for (var item in itemsList) {
        print('  Product ${item['product_id']}: quantity=${item['quantity']}, weight=${item['weight']}');
      }
    } else {
      print('  No items in sale data');
    }

    if (paymentDetails != null && !isCredit) {
      saleData['payment_details'] = paymentDetails;
    } else if (isCredit && paymentDetails != null) {
      saleData['credit_details'] = {
        'due_date': paymentDetails['due_date'],
        'notes': paymentDetails['notes'],
      };
    }

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final result = await provider.createSale(saleData);

    if (mounted) Navigator.pop(context);

    if (result['success'] == true) {
      final resultData = result['data'] as Map<String, dynamic>;
      final invoiceNumber = resultData['invoice_number'] ?? 'N/A';

      final items = _cartItems.map((item) => {
        'product_name': item.product.itemName,
        'quantity': _selectedSaleType == SaleType.sarya ? 0 : item.quantity,
        'unit_price': item.unitPrice,
        'selected_lengths': item.selectedLengths,
        'lengths_display': item.lengthsDisplay,
        'weight': item.weight,
        'total': _selectedSaleType == SaleType.sarya
            ? item.weight * item.unitPrice
            : item.quantity * item.unitPrice,
      }).toList();

      try {
        final pdfData = await SalePdfGenerator.generateSalePdf(
          saleData: {
            'invoice_number': invoiceNumber,
            'reference': _referenceController.text.trim(),  // ✅ ADD THIS LINE
          },
          customer: _selectedCustomer,
          items: items,
          subtotal: _subtotal,
          discountValue: _discountValue,
          grandTotal: _grandTotal,
          isPosMode: _isPosMode,
          paymentMethod: paymentMethod,
          amountPaid: finalAmountPaid,
          dueDate: isCredit && _creditDueDate != null
              ? _creditDueDate
              : _dueDate,
          notes: _buildNotes(paymentMethod, paymentDetails),
          previousBalance: _selectedCustomer?.balance ?? 0.0, // ✅ ADD THIS LINE
        );

        if (mounted) {
          _clearCart();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isCredit
                ? 'Credit sale created successfully!'
                : 'Sale completed successfully!'),
            backgroundColor: isCredit
                ? const Color(0xFF7C3AED)
                : const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ));
          _showPrintDialog(pdfData, invoiceNumber);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          _clearCart();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sale saved but PDF failed: $e'),
            backgroundColor: Colors.orange,
          ));
          Navigator.pop(context, true);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Failed to save sale'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  String _buildNotes(
      String paymentMethod, Map<String, dynamic>? paymentDetails) {
    final List<String> notesParts = [];
    if (_invoiceNoteController.text.trim().isNotEmpty) {
      notesParts.add(_invoiceNoteController.text.trim());
    }
    if (paymentMethod == 'credit' && paymentDetails != null) {
      if (paymentDetails['notes'] != null &&
          paymentDetails['notes'].toString().trim().isNotEmpty) {
        notesParts.add('Credit Note: ${paymentDetails['notes']}');
      }
      if (paymentDetails['due_date'] != null) {
        final dueDate = DateTime.parse(paymentDetails['due_date']);
        notesParts.add('Due Date: ${DateFormat('dd/MM/yyyy').format(dueDate)}');
      }
    }
    return notesParts.isNotEmpty ? notesParts.join('\n') : '';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// ═════════════════════════════════════════════════════════════════
//  CUSTOMER PICKER SHEET
// ═════════════════════════════════════════════════════════════════

class _CustomerPickerSheet extends StatefulWidget {
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelected;
  final VoidCallback onAddNew;

  const _CustomerPickerSheet(
      {required this.selectedCustomer,
        required this.onSelected,
        required this.onAddNew});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Customer> _filtered = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers([String query = '']) async {
    setState(() => _loading = true);
    try {
      final provider =
      Provider.of<CustomerProvider>(context, listen: false);
      await provider.fetchCustomers(search: query);
      if (mounted) setState(() => _filtered = provider.customers);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              children: [
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2))),
                Row(
                  children: [
                    const Text('Select Customer',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onAddNew,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search customers…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: _loadCustomers,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const Center(
                child: Text('No customers found',
                    style: TextStyle(color: Color(0xFF9CA3AF))))
                : ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final c = _filtered[i];
                final sel = widget.selectedCustomer?.id == c.id;
                final hasPositiveBalance = (c.balance ?? 0) > 0;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasPositiveBalance
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF3F0FF),
                    child: Text(
                      c.name.isNotEmpty
                          ? c.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: hasPositiveBalance
                              ? const Color(0xFF92400E)
                              : const Color(0xFF7C3AED),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.contact),
                      if (c.balance != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet,
                                size: 10,
                                color: hasPositiveBalance
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(
                              'Balance: Rs ${c.balance!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: hasPositiveBalance
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: sel
                      ? const Icon(Icons.check_circle,
                      color: Color(0xFF7C3AED))
                      : null,
                  onTap: () => widget.onSelected(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  ADD CUSTOMER DIALOG  (unchanged from original)
// ═════════════════════════════════════════════════════════════════

class _AddCustomerDialog extends StatefulWidget {
  final ValueChanged<Customer> onCreated;
  const _AddCustomerDialog({required this.onCreated});

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  String _type = 'regular';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final provider =
      Provider.of<CustomerProvider>(context, listen: false);
      final discountPercent =
          double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
      final result = await provider.createCustomer(
        name: _nameCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        address: _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : null,
        email: _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : null,
        customerType: _type,
        balance: 0,
        discountPercent: discountPercent,
      );
      if (result['success'] == true && mounted) {
        widget.onCreated(result['data'] as Customer);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Customer added successfully'),
              backgroundColor: Color(0xFF10B981)),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Color(0xFF7C3AED), size: 22),
          SizedBox(width: 10),
          Text('Add New Customer',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D))),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name required';
                    if (v.trim().length < 2) return 'Min 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Contact Number *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Contact required';
                    if (v.trim().length < 10) return 'Enter valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                      labelText: 'Customer Type',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'regular', child: Text('Regular Customer')),
                    DropdownMenuItem(
                        value: 'retail', child: Text('Retail Customer')),
                    DropdownMenuItem(
                        value: 'wholesale', child: Text('Wholesale Customer')),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _discountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Default Discount (%)',
                    hintText: 'e.g. 10 for 10% off',
                    prefixIcon: Icon(Icons.local_offer,
                        color: Color(0xFF7C3AED)),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Text('Add Customer',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  PAYMENT DIALOG  (unchanged from original)
// ═════════════════════════════════════════════════════════════════

class _PaymentDialog extends StatefulWidget {
  final double total;
  final String customerName;
  final bool isInvoice;
  final void Function(String method, double amount,
      Map<String, dynamic>? paymentDetails) onConfirm;

  const _PaymentDialog({
    required this.total,
    required this.customerName,
    this.isInvoice = false,
    required this.onConfirm,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog>
    with SingleTickerProviderStateMixin {
  String _method = 'credit';
  final TextEditingController _receivedCtrl = TextEditingController();
  DateTime? _creditDueDate;
  final TextEditingController _creditNotesCtrl = TextEditingController();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _methodColors = {
    'cash': Color(0xFF10B981),
    'bank': Color(0xFF3B82F6),
    'cheque': Color(0xFFF59E0B),
    'slip': Color(0xFF8B5CF6),
    'credit': Color(0xFF7C3AED),
  };

  static const _methodIcons = {
    'cash': Icons.payments_outlined,
    'bank': Icons.account_balance_outlined,
    'cheque': Icons.receipt_long_outlined,
    'slip': Icons.receipt_outlined,
    'credit': Icons.credit_card_outlined,
  };

  static const _methodLabels = {
    'cash': 'Cash',
    'bank': 'Bank',
    'cheque': 'Cheque',
    'slip': 'Slip',
    'credit': 'Credit',
  };

  @override
  void initState() {
    super.initState();
    _receivedCtrl.text = widget.total.toStringAsFixed(2);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _receivedCtrl.dispose();
    _creditNotesCtrl.dispose();
    super.dispose();
  }

  Color get _activeColor =>
      _methodColors[_method] ?? const Color(0xFF10B981);
  double get _received =>
      double.tryParse(_receivedCtrl.text) ?? widget.total;
  double get _change =>
      (_received - widget.total).clamp(0, double.infinity);

  bool get _isValid {
    if (_method == 'cash') return _received >= widget.total;
    if (_method == 'credit') return true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfo(),
                    const SizedBox(height: 20),
                    _buildMethodSelector(),
                    const SizedBox(height: 20),
                    if (_method == 'cash') _buildCashFields(),
                    if (_method == 'credit') _buildCreditFields(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.06),
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            bottom:
            BorderSide(color: _activeColor.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _activeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_methodIcons[_method],
                color: _activeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isInvoice ? 'Create Invoice' : 'Process Payment',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Text('Select payment method',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: _activeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.customerName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Text(
            'Rs ${widget.total.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _activeColor),
          ),
        ],
      ),
    );
  }

  // Widget _buildMethodSelector() {
  //   final methods = ['cash', 'bank', 'cheque', 'slip', 'credit'];
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text('Payment Method *',
  //           style: TextStyle(
  //               fontSize: 12,
  //               fontWeight: FontWeight.w600,
  //               color: Color(0xFF8E8E93))),
  //       const SizedBox(height: 8),
  //       SingleChildScrollView(
  //         scrollDirection: Axis.horizontal,
  //         child: Row(
  //           children: methods.map((method) {
  //             final selected = _method == method;
  //             final color = _methodColors[method]!;
  //             return Padding(
  //               padding: const EdgeInsets.only(right: 6),
  //               child: GestureDetector(
  //                 onTap: () => setState(() => _method = method),
  //                 child: AnimatedContainer(
  //                   duration: const Duration(milliseconds: 180),
  //                   padding: const EdgeInsets.symmetric(
  //                       horizontal: 14, vertical: 10),
  //                   decoration: BoxDecoration(
  //                     color: selected
  //                         ? color.withOpacity(0.1)
  //                         : const Color(0xFFF5F5F7),
  //                     borderRadius: BorderRadius.circular(12),
  //                     border: Border.all(
  //                       color: selected ? color : const Color(0xFFE5E5EA),
  //                       width: selected ? 2 : 1,
  //                     ),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Icon(_methodIcons[method],
  //                           size: 18,
  //                           color: selected
  //                               ? color
  //                               : const Color(0xFF8E8E93)),
  //                       const SizedBox(width: 6),
  //                       Text(_methodLabels[method]!,
  //                           style: TextStyle(
  //                               fontSize: 12,
  //                               fontWeight: selected
  //                                   ? FontWeight.bold
  //                                   : FontWeight.normal,
  //                               color: selected
  //                                   ? color
  //                                   : const Color(0xFF8E8E93))),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             );
  //           }).toList(),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildMethodSelector() {
    // Only show credit method
    final methods = ['credit'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93))),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: methods.map((method) {
              final selected = _method == method;
              final color = _methodColors[method]!;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _method = method),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.1)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : const Color(0xFFE5E5EA),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_methodIcons[method],
                            size: 18,
                            color: selected
                                ? color
                                : const Color(0xFF8E8E93)),
                        const SizedBox(width: 6),
                        Text(_methodLabels[method]!,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? color
                                    : const Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCashFields() {
    return Column(
      children: [
        TextField(
          controller: _receivedCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount Received',
            prefixText: 'Rs ',
            prefixStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _activeColor),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
              BorderSide(color: _activeColor, width: 1.5),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_received >= widget.total)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('Change',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981))),
                const Spacer(),
                Text('Rs ${_change.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCreditFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF7C3AED).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No payment collected now. Amount added to customer balance.',
                  style:
                  TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _creditDueDate ??
                  DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _creditDueDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: _creditDueDate != null
                  ? const Color(0xFFF5F3FF)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _creditDueDate != null
                    ? const Color(0xFF7C3AED).withOpacity(0.3)
                    : const Color(0xFFE5E5EA),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 20,
                    color: _creditDueDate != null
                        ? const Color(0xFF7C3AED)
                        : Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _creditDueDate != null
                        ? DateFormat('MMM dd, yyyy').format(_creditDueDate!)
                        : 'Set due date (Optional)',
                    style: TextStyle(
                        fontSize: 14,
                        color: _creditDueDate != null
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFC7C7CC)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _creditNotesCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Add any notes about this credit sale...',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    String buttonText =
    widget.isInvoice ? 'Create Invoice' : 'Confirm Payment';
    if (_method == 'credit') {
      buttonText = widget.isInvoice
          ? 'Create Credit Invoice'
          : 'Process on Credit';
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isValid ? () => _confirmPayment() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _activeColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: Text(
          buttonText,
          style: TextStyle(
              color: _isValid ? Colors.white : Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _confirmPayment() {
    Map<String, dynamic>? paymentDetails;

    switch (_method) {
      case 'cash':
        paymentDetails = {
          'amount_received': _received,
          'change': _change,
        };
        break;
      case 'credit':
        paymentDetails = {
          'payment_method': 'credit',
          'due_date': _creditDueDate?.toIso8601String(),
          'notes': _creditNotesCtrl.text.trim(),
        };
        break;
      default:
        paymentDetails = {'method': _method};
    }

    widget.onConfirm(_method, _received, paymentDetails);
  }
}
