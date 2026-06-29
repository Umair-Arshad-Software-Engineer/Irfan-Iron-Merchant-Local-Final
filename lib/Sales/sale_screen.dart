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
import '../providers/lanprovider.dart'; // Add this import

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class SaleItem {
  final ProductModel product;
  int quantity;
  double unitPrice;
  double? customerSpecificPrice;
  bool usingCustomerPrice;
  String? description;  // ✅ ADD THIS

  List<String> selectedLengths;
  Map<String, double> lengthQuantities;
  String lengthsDisplay;
  double weight;

  SaleItem({
    required this.product,
    this.quantity = 1,
    required this.unitPrice,
    this.customerSpecificPrice,
    this.description,  // ✅ ADD THIS
    this.usingCustomerPrice = false,
    this.selectedLengths = const [],
    this.lengthQuantities = const {},
    this.lengthsDisplay = '',
    this.weight = 0.0,
  });

  double totalForMode(bool isSaryaMode) {
    if (isSaryaMode && weight > 0) {
      return weight * unitPrice;
    } else if (!isSaryaMode) {
      return quantity.toDouble() * unitPrice;
    }
    return 0.0;
  }

  double get total {
    if (hasWeightBasedCalculation) {
      return weight * unitPrice;
    } else {
      return quantity.toDouble() * unitPrice;
    }
  }

  bool get hasWeightBasedCalculation {
    return product.isSaryaType && weight > 0;
  }

  double get displayQuantity => hasWeightBasedCalculation ? weight : quantity.toDouble();
  String get quantityUnit => hasWeightBasedCalculation ? 'Kg' : 'pcs';
  double get standardPrice => product.salePrice.toDouble();
  bool get hasPriceDifference => customerSpecificPrice != null && customerSpecificPrice != standardPrice;
  bool get hasLengthCombinations => selectedLengths.isNotEmpty;
  int get totalPieces => lengthQuantities.values.fold(0, (sum, qty) => sum + qty.round());

  // Helper to check if weight has been set
  bool get hasWeight => weight > 0;
}

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
  final SaleModel? existingSale;
  const SaleScreen({super.key, this.existingSale});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> with SingleTickerProviderStateMixin {
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
  SaleType _selectedSaleType = SaleType.sarya;

  late final TextEditingController _discountPercentCtrl;
  late final TextEditingController _discountAmountCtrl;
  bool _updatingDiscountCtrl = false;

  bool get _isEditMode => widget.existingSale != null;
  bool _isPrefilling = false;

  // Responsive state
  bool _isMobile = false;
  bool _isTablet = false;
  bool _showCartPanel = true;
  bool _showProductPanel = true;

  // Mobile tab: 0=Products, 1=Cart, 2=Options
  int _mobileTab = 0;

  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _descriptionControllers = {};
  final Map<String, TextEditingController> _inlineLengthQtyControllers = {};

  @override
  void initState() {
    super.initState();
    _toggleAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _searchController.addListener(_onSearchChanged);

    _discountPercentCtrl =
        TextEditingController(text: _discountPercent.toStringAsFixed(1));
    _discountAmountCtrl =
        TextEditingController(text: _discountAmount.toStringAsFixed(2));

    // Wait for both products AND frame before prefilling
    WidgetsBinding.instance.addPostFrameCallback((_) async {
// Right after _loadAllProducts() in initState:
      await _loadAllProducts();
      debugPrint('Products loaded: ${_allProducts.length}');
      if (_allProducts.isEmpty) {
        // Retry once
        await Future.delayed(const Duration(milliseconds: 300));
        final provider = Provider.of<ProductProvider>(context, listen: false);
        if (mounted) setState(() => _allProducts = List<ProductModel>.from(provider.products));
        debugPrint('Products after retry: ${_allProducts.length}');
      }
      if (_isEditMode && mounted) {
        await _prefillFromSale();
      }
    });
  }

  Future<void> _prefillFromSale() async {
    if (!mounted) return;
    setState(() => _isPrefilling = true);

    try {
      // ── CRITICAL: always re-fetch full sale data, never trust list item ──
      final provider = Provider.of<SaleProvider>(context, listen: false);
      final result = await provider.getSaleById(widget.existingSale!.id);

      if (!mounted) return;

      if (result['success'] != true || result['data'] == null) {
        debugPrint('❌ Failed to fetch sale for prefill: ${result['message']}');
        setState(() => _isPrefilling = false);
        return;
      }

      final sale = result['data'] as SaleModel;

      debugPrint('=== PREFILL START ===');
      debugPrint('All products count: ${_allProducts.length}');
      debugPrint('Sale items count: ${sale.items?.length ?? 0}');
      debugPrint('Sale items raw: ${sale.items?.map((i) => 'id=${i.id} productId=${i.productId} name=${i.productName}').toList()}');

      // ── Sale type & mode ──────────────────────────
      _selectedSaleType =
      sale.saleCategory == 'sarya' ? SaleType.sarya : SaleType.filled;
      _isPosMode = sale.saleType == 'pos';
      _isPosMode ? _toggleAnim.reverse() : _toggleAnim.forward();

      // ── Dates ────────────────────────────────────
      _invoiceDate = sale.saleDate;
      _dueDate = sale.dueDate;

      // ── Reference & notes ────────────────────────
      _referenceController.text = sale.reference ?? '';
      _invoiceNoteController.text = sale.notes ?? '';

      // ── Discount ─────────────────────────────────
      if (sale.discountType == 'percent') {
        _usePercentDiscount = true;
        _discountPercent = sale.discountValue;
        _discountAmount = 0;
      } else {
        _usePercentDiscount = false;
        _discountAmount = sale.discountValue;
        _discountPercent = 0;
      }
      _syncDiscountControllers();

      // ── Customer ─────────────────────────────────
      if (sale.customer != null) {
        final custProvider =
        Provider.of<CustomerProvider>(context, listen: false);
        if (custProvider.customers.isEmpty) {
          await custProvider.fetchCustomers();
        }
        final matches =
        custProvider.customers.where((c) => c.id == sale.customer!.id).toList();
        if (matches.isNotEmpty && mounted) {
          _selectedCustomer = matches.first;
          if (_selectedCustomer!.discountPercent > 0 && _usePercentDiscount) {
            _discountPercent = _selectedCustomer!.discountPercent;
            _syncDiscountControllers();
          }
        }
      }

      debugPrint('Customer loaded: ${_selectedCustomer?.name}');

      // ── Dispose existing controllers ──────────────
      for (final c in _weightControllers.values) c.dispose();
      _weightControllers.clear();
      for (final c in _qtyControllers.values) c.dispose();
      _qtyControllers.clear();
      for (final c in _descriptionControllers.values) c.dispose();
      _descriptionControllers.clear();
      for (final c in _inlineLengthQtyControllers.values) c.dispose();
      _inlineLengthQtyControllers.clear();
      _cartItems.clear();

      if (sale.items != null && sale.items!.isNotEmpty) {
        final List<SaleItem> builtItems = [];

        for (final saleItem in sale.items!) {
          debugPrint('Processing item: productId=${saleItem.productId} name=${saleItem.productName}');

          // ── Strategy 1: match by productId ──
          ProductModel? product;
          if (saleItem.productId != null) {
            final byId = _allProducts
                .where((p) => p.id == saleItem.productId)
                .toList();
            if (byId.isNotEmpty) {
              product = byId.first;
              debugPrint('  ✅ Found by ID: ${product.itemName}');
            }
          }

          // ── Strategy 2: match by product sub-object ──
          if (product == null && saleItem.product != null) {
            final bySubId = _allProducts
                .where((p) => p.id == saleItem.product!.id)
                .toList();
            if (bySubId.isNotEmpty) {
              product = bySubId.first;
              debugPrint('  ✅ Found by product.id: ${product.itemName}');
            }
          }

          // ── Strategy 3: match by name (last resort) ──
          if (product == null) {
            final byName = _allProducts
                .where((p) =>
            p.itemName.toLowerCase() ==
                saleItem.productName.toLowerCase())
                .toList();
            if (byName.isNotEmpty) {
              product = byName.first;
              debugPrint('  ✅ Found by name: ${product.itemName}');
            }
          }

          if (product == null) {
            debugPrint('  ❌ Product NOT FOUND: id=${saleItem.productId} name=${saleItem.productName}');
            continue;
          }

          final bool usingCustomerPrice = saleItem.usedCustomerPrice;
          final double unitPrice = saleItem.unitPrice;
          final double? customerSpecificPrice =
          usingCustomerPrice ? unitPrice : null;

          final selectedLengths =
          List<String>.from(saleItem.selectedLengths ?? []);
          final lengthQuantities = Map<String, double>.fromEntries(
            (saleItem.lengthQuantities ?? {}).entries.map(
                  (e) => MapEntry(
                e.key,
                e.value is num
                    ? (e.value as num).toDouble()
                    : double.tryParse(e.value.toString()) ?? 1.0,
              ),
            ),
          );

          final lengthsDisplay = selectedLengths.isNotEmpty
              ? selectedLengths.map((l) {
            final q = lengthQuantities[l] ?? 1.0;
            return '\u2068$l\u2069 (${q.toStringAsFixed(0)})';
          }).join(', ')
              : (saleItem.selectedLengthsDisplay ?? '');

          builtItems.add(SaleItem(
            product: product,
            quantity: saleItem.quantity > 0 ? saleItem.quantity : 1,
            unitPrice: unitPrice,
            customerSpecificPrice: customerSpecificPrice,
            usingCustomerPrice: usingCustomerPrice,
            weight: saleItem.weight ?? 0.0,
            selectedLengths: selectedLengths,
            lengthQuantities: lengthQuantities,
            lengthsDisplay: lengthsDisplay,
            description: saleItem.description,
          ));
        }

        debugPrint('Built ${builtItems.length} cart items');

        // ── Build controllers before setState ────────
        for (int i = 0; i < builtItems.length; i++) {
          final item = builtItems[i];

          _weightControllers[i] = TextEditingController(
            text: item.weight > 0 ? item.weight.toStringAsFixed(2) : '',
          );
          _qtyControllers[i] = TextEditingController(
            text: item.quantity.toString(),
          );
          _descriptionControllers[i] = TextEditingController(
            text: item.description ?? '',
          );

          final combinations = item.product.lengthCombinations ?? [];
          for (final combo in combinations) {
            final key = '${i}_${combo.length}';
            final isSelected = item.selectedLengths.contains(combo.length);
            final qty = item.lengthQuantities[combo.length] ?? 1.0;
            _inlineLengthQtyControllers[key] = TextEditingController(
              text: isSelected ? qty.toStringAsFixed(0) : '',
            );
          }
        }

        if (mounted) {
          setState(() {
            _cartItems.addAll(builtItems);
          });
        }

        debugPrint('Cart items set: ${_cartItems.length}');
      } else {
        debugPrint('⚠️ No items in sale response');
      }

      // ── Customer pricing ──────────────────────────
      if (_selectedCustomer != null &&
          sale.items != null &&
          sale.items!.any((item) => item.usedCustomerPrice == true)) {
        if (mounted) setState(() => _useCustomerPrices = true);
        await _fetchAndApplyCustomerPrices();
      }

      debugPrint('=== PREFILL COMPLETE === Cart: ${_cartItems.length} items');
    } catch (e, stack) {
      debugPrint('❌ Prefill error: $e\n$stack');
    } finally {
      if (mounted) setState(() => _isPrefilling = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    _weightControllers.clear();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _descriptionControllers.values) {
      controller.dispose();
    }
    for (final c in _inlineLengthQtyControllers.values) c.dispose();
    _inlineLengthQtyControllers.clear();
    _descriptionControllers.clear();
    _qtyControllers.clear();
    _toggleAnim.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _invoiceNoteController.dispose();
    _referenceController.dispose();
    _discountPercentCtrl.dispose();
    _discountAmountCtrl.dispose();
    super.dispose();
  }

  void _syncDiscountControllers() {
    _updatingDiscountCtrl = true;
    _discountPercentCtrl.text = _discountPercent.toStringAsFixed(1);
    _discountAmountCtrl.text = _discountAmount.toStringAsFixed(2);
    _updatingDiscountCtrl = false;
  }

  double get _subtotal => _cartItems.fold(0.0, (sum, item) => sum + item.totalForMode(_selectedSaleType == SaleType.sarya));
  double get _discountValue => _usePercentDiscount ? _subtotal * (_discountPercent / 100) : _discountAmount;
  double get _grandTotal => _subtotal - _discountValue;
  double get _customerPriceSavings => _cartItems
      .where((i) => i.usingCustomerPrice && i.hasPriceDifference)
      .fold(0.0, (sum, i) => sum + ((i.standardPrice - i.unitPrice) * i.quantity));

  String _safeLengthLabel(String length, double qty) {
    const fsi = '\u2068';
    const pdi = '\u2069';
    return '$fsi$length$pdi × ${qty.toStringAsFixed(0)}';
  }

  Future<void> _showLengthSelectionDialog(int cartIndex) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final item = _cartItems[cartIndex];
    final product = item.product;
    final combinations = product.lengthCombinations ?? [];

    if (combinations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              languageProvider.isEnglish
                  ? 'No length combinations available for ${product.itemName}'
                  : '${product.itemName} کے لیے کوئی لمبائی کا مجموعہ دستیاب نہیں ہے'
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> currentSelections = List.from(item.selectedLengths);
    Map<String, double> currentQuantities = Map.from(item.lengthQuantities);
    final weightController = TextEditingController(
      text: item.hasWeight ? item.weight.toStringAsFixed(2) : '',
    );

    final Map<String, TextEditingController> qtyControllers = {};
    for (final combo in combinations) {
      final qty = currentQuantities[combo.length] ?? 0.0;
      qtyControllers[combo.length] = TextEditingController(
        text: currentSelections.contains(combo.length) && qty > 0 ? qty.toStringAsFixed(0) : '',
      );
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.isEnglish
                        ? 'Select Lengths — ${product.itemName}'
                        : 'لمبائیاں منتخب کریں — ${product.itemName}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    languageProvider.isEnglish
                        ? '${combinations.length} length${combinations.length != 1 ? 's' : ''} available'
                        : '${combinations.length} لمبائیاں دستیاب ہیں',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.scale, size: 16, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: languageProvider.isEnglish ? 'Weight (Kg) - optional' : 'وزن (کلوگرام) - اختیاری',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        languageProvider.isEnglish ? 'Lengths & Quantities' : 'لمبائیاں اور مقداریں',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.builder(
                        itemCount: combinations.length,
                        itemBuilder: (ctx, idx) {
                          final combo = combinations[idx];
                          final isSelected = currentSelections.contains(combo.length);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  dense: true,
                                  title: Text(combo.length, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  subtitle: combo.lengthDecimal.isNotEmpty ? Text(
                                      languageProvider.isEnglish
                                          ? 'Decimal: ${combo.lengthDecimal}'
                                          : 'اعشاری: ${combo.lengthDecimal}',
                                      style: const TextStyle(fontSize: 10)
                                  ) : null,
                                  value: isSelected,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setDlgState(() {
                                      if (val == true) {
                                        currentSelections.add(combo.length);
                                        currentQuantities[combo.length] = 1.0;
                                        qtyControllers[combo.length]?.text = '1';
                                      } else {
                                        currentSelections.remove(combo.length);
                                        currentQuantities.remove(combo.length);
                                        qtyControllers[combo.length]?.text = '';
                                      }
                                    });
                                  },
                                ),
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    child: Row(
                                      children: [
                                        Text(
                                            languageProvider.isEnglish ? 'Qty:' : 'مقدار:',
                                            style: const TextStyle(fontSize: 12)
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: qtyControllers[combo.length],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    if (currentSelections.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              languageProvider.isEnglish
                                  ? '${currentSelections.length} selected'
                                  : '${currentSelections.length} منتخب',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${currentQuantities.values.fold(0.0, (s, q) => s + q).toStringAsFixed(0)} ${languageProvider.isEnglish ? 'pcs' : 'ٹکڑے'}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDlgState(() {
                      currentSelections.clear();
                      currentQuantities.clear();
                      for (final ctrl in qtyControllers.values) ctrl.text = '';
                    });
                  },
                  child: Text(
                      languageProvider.isEnglish ? 'Clear' : 'صاف کریں',
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // ✅ Dispose controllers before closing
                    // weightController.dispose();
                    // for (final ctrl in qtyControllers.values) ctrl.dispose();
                    Navigator.pop(ctx, false);
                  },
                  child: Text(
                      languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
                      style: const TextStyle(fontSize: 12)
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {
                    // ✅ CRITICAL FIX: Close the dialog immediately
                    Navigator.pop(ctx, true);
                  },
                  child: Text(
                      languageProvider.isEnglish ? 'Confirm' : 'تصدیق کریں',
                      style: const TextStyle(fontSize: 12)
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final double manualWeight = double.tryParse(weightController.text) ?? 0.0;

      // ✅ Read actual qty values from controllers BEFORE they're disposed
      for (final combo in combinations) {
        if (currentSelections.contains(combo.length)) {
          final ctrlValue = double.tryParse(qtyControllers[combo.length]?.text ?? '') ?? 1.0;
          currentQuantities[combo.length] = ctrlValue > 0 ? ctrlValue : 1.0;
        }
      }

      final String lengthsDisplay = currentSelections.map((l) {
        final q = currentQuantities[l] ?? 1.0;
        return '\u2068$l\u2069 (${q.toStringAsFixed(0)})';
      }).join(', ');

      if (mounted) {
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
            description: item.description,
          );
          _weightControllers[cartIndex]?.dispose();
          _weightControllers.remove(cartIndex);
        });
      }
    }

// ✅ Only dispose here, once, after dialog is fully closed
    weightController.dispose();
    for (final ctrl in qtyControllers.values) ctrl.dispose();
  }

  void _removeLengthFromCartItem(int cartIndex, String length) {
    final item = _cartItems[cartIndex];
    final newLengths = List<String>.from(item.selectedLengths)..remove(length);
    final newQtys = Map<String, double>.from(item.lengthQuantities)..remove(length);
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

  Future<void> _fetchAndApplyCustomerPrices() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

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
      final productIds = _cartItems.map((i) => i.product.id).whereType<int>().toList();
      if (productIds.isEmpty) {
        setState(() => _isFetchingCustomerPrices = false);
        return;
      }
      final response = await http.post(
        Uri.parse(ApiConfig.bulkCustomerPricesUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'customer_id': _selectedCustomer!.id, 'product_ids': productIds}),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final raw = json['data'] as Map<String, dynamic>;
          final priceMap = raw.map((k, v) => MapEntry(int.parse(k), double.parse(v.toString())));
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
            content: Text(
                languageProvider.isEnglish
                    ? 'Could not fetch customer prices: $e'
                    : 'کسٹمر کی قیمتیں حاصل نہیں ہو سکیں: $e'
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingCustomerPrices = false);
    }
  }

  double _resolvePrice(ProductModel product) {
    if (_useCustomerPrices && _selectedCustomer != null && product.id != null && _customerPriceMap.containsKey(product.id)) {
      return _customerPriceMap[product.id]!;
    }
    return product.salePrice.toDouble();
  }

  bool _hasCustomerPrice(ProductModel product) =>
      _useCustomerPrices && _selectedCustomer != null && product.id != null && _customerPriceMap.containsKey(product.id);

  Future<void> _loadAllProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      await provider.fetchProducts();
      if (mounted) {
        setState(() => _allProducts = List<ProductModel>.from(provider.products));
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
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
          _searchResults = (result['data'] as List<dynamic>?)?.map((e) => e as ProductModel).toList() ?? [];
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
        final customPrice = _hasCustomerPrice(product) ? _customerPriceMap[product.id] : null;
        _cartItems.add(SaleItem(
          product: product,
          unitPrice: _resolvePrice(product),
          customerSpecificPrice: customPrice,
          usingCustomerPrice: customPrice != null,
          weight: 0.0,
        ));
      }
      _searchController.clear();
      _searchResults = [];
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _showDescriptionDialog(ProductModel product) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final descriptionController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            languageProvider.isEnglish
                ? 'Add Description for ${product.itemName}'
                : '${product.itemName} کے لیے تفصیل شامل کریں',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.isEnglish
                    ? 'Add a custom description for this item (optional)'
                    : 'اس آئٹم کے لیے حسب ضرورت تفصیل شامل کریں (اختیاری)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: TextStyle(fontFamily: languageProvider.fontFamily),
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish
                      ? 'Enter description...'
                      : 'تفصیل درج کریں...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                languageProvider.isEnglish ? 'Skip' : 'چھوڑیں',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final desc = descriptionController.text.trim();
                Navigator.pop(ctx, desc.isEmpty ? null : desc);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                languageProvider.isEnglish ? 'Add' : 'شامل کریں',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );

    descriptionController.dispose();

    // Add to cart with description
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.product.id == product.id);
      if (idx >= 0) {
        final existingWeight = _cartItems[idx].weight;
        _cartItems[idx].quantity++;
        if (existingWeight > 0) {
          _cartItems[idx].weight = existingWeight;
        }
        // If description is provided, update it
        if (result != null) {
          _cartItems[idx].description = result;
        }
      } else {
        final customPrice = _hasCustomerPrice(product) ? _customerPriceMap[product.id] : null;
        _cartItems.add(SaleItem(
          product: product,
          unitPrice: _resolvePrice(product),
          customerSpecificPrice: customPrice,
          usingCustomerPrice: customPrice != null,
          weight: 0.0,
          description: result,  // ✅ ADD THIS
        ));
      }
      _searchController.clear();
      _searchResults = [];
    });
    HapticFeedback.lightImpact();
  }

  // void _removeFromCart(int index) => setState(() => _cartItems.removeAt(index));
  void _removeFromCart(int index) {
    setState(() => _cartItems.removeAt(index));
    _qtyControllers[index]?.dispose();
    _qtyControllers.remove(index);
    // Re-key controllers above the removed index
    final updated = <int, TextEditingController>{};
    _qtyControllers.forEach((k, v) {
      updated[k > index ? k - 1 : k] = v;
    });
    _qtyControllers
      ..clear()
      ..addAll(updated);
    // Do the same for weight controllers
    _weightControllers[index]?.dispose();
    _weightControllers.remove(index);
    final updatedW = <int, TextEditingController>{};
    _weightControllers.forEach((k, v) {
      updatedW[k > index ? k - 1 : k] = v;
    });
    _weightControllers
      ..clear()
      ..addAll(updatedW);
    _descriptionControllers[index]?.dispose();
    _descriptionControllers.remove(index);
    final updatedD = <int, TextEditingController>{};
    _descriptionControllers.forEach((k, v) {
      updatedD[k > index ? k - 1 : k] = v;
    });
    _descriptionControllers
      ..clear()
      ..addAll(updatedD);

    // Clean up inline length qty controllers for removed index
    final keysToRemove = _inlineLengthQtyControllers.keys
        .where((k) => k.startsWith('${index}_'))
        .toList();
    for (final k in keysToRemove) {
      _inlineLengthQtyControllers[k]?.dispose();
      _inlineLengthQtyControllers.remove(k);
    }
// Re-key for shifted items
    final updatedL = <String, TextEditingController>{};
    _inlineLengthQtyControllers.forEach((k, v) {
      final parts = k.split('_');
      final i = int.tryParse(parts[0]) ?? -1;
      if (i > index) {
        updatedL['${i - 1}_${parts.sublist(1).join('_')}'] = v;
      } else {
        updatedL[k] = v;
      }
    });
    _inlineLengthQtyControllers..clear()..addAll(updatedL);
  }

  void _updateQty(int index, int delta) {
    setState(() {
      _cartItems[index].quantity = (_cartItems[index].quantity + delta).clamp(1, 9999);
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
    for (final c in _qtyControllers.values) c.dispose();
    _qtyControllers.clear();
    _syncDiscountControllers();
    for (final c in _descriptionControllers.values) c.dispose();
    _descriptionControllers.clear();
    for (final c in _inlineLengthQtyControllers.values) c.dispose();
    _inlineLengthQtyControllers.clear();
  }

  void _switchMode(bool pos) {
    setState(() => _isPosMode = pos);
    pos ? _toggleAnim.reverse() : _toggleAnim.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final screenSize = MediaQuery.of(context).size;
        _isMobile = screenSize.width < 600;
        _isTablet = screenSize.width >= 600 && screenSize.width < 1200;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F5F9),
          body: _isPrefilling
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF7C3AED)),
                const SizedBox(height: 12),
                Text(
                  languageProvider.isEnglish ? 'Loading sale data…' : 'فروخت کا ڈیٹا لوڈ ہو رہا ہے…',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
              ],
            ),
          )
              : Column(
            children: [
              _buildHeader(languageProvider),
              Expanded(
                child: _isMobile
                    ? _buildMobileLayout(languageProvider)
                    : (_isPosMode ? _buildPosLayout(languageProvider) : _buildInvoiceLayout(languageProvider)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════
  //  MOBILE LAYOUT — FULL OPTIONS
  // ══════════════════════════════════════════════

  Widget _buildMobileLayout(LanguageProvider languageProvider) {
    return Column(
      children: [
        // ── 3-tab bar ──────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEF5))),
          ),
          child: Row(
            children: [
              _buildMobileTab(
                languageProvider.isEnglish ? 'Products' : 'پروڈکٹس',
                Icons.inventory_2,
                _mobileTab == 0,
                    () => setState(() => _mobileTab = 0),
                languageProvider: languageProvider,
              ),
              _buildMobileTab(
                '${languageProvider.isEnglish ? 'Cart' : 'کارٹ'} (${_cartItems.length})',
                Icons.shopping_cart,
                _mobileTab == 1,
                    () => setState(() => _mobileTab = 1),
                languageProvider: languageProvider,
              ),
              _buildMobileTab(
                languageProvider.isEnglish ? 'Options' : 'اختیارات',
                Icons.tune,
                _mobileTab == 2,
                    () => setState(() => _mobileTab = 2),
                badge: _hasMobileOptionsBadge ? _mobileOptionsBadgeCount : 0,
                languageProvider: languageProvider,
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _mobileTab,
            children: [
              _buildMobileProductsTab(languageProvider),
              _buildMobileCartTab(languageProvider),
              _buildMobileOptionsTab(languageProvider),
            ],
          ),
        ),
        // ── Bottom action bar ──────────────────────
        _buildMobileBottomBar(languageProvider),
      ],
    );
  }

  bool get _hasMobileOptionsBadge {
    return _discountValue > 0 || (_useCustomerPrices && _customerPriceMap.isNotEmpty) ||
        _referenceController.text.isNotEmpty || _invoiceNoteController.text.isNotEmpty;
  }

  int get _mobileOptionsBadgeCount {
    int c = 0;
    if (_discountValue > 0) c++;
    if (_useCustomerPrices && _customerPriceMap.isNotEmpty) c++;
    if (_referenceController.text.isNotEmpty) c++;
    return c;
  }

  Widget _buildMobileTab(String label, IconData icon, bool active, VoidCallback onTap,
      {int badge = 0, required LanguageProvider languageProvider}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: active ? const Color(0xFF7C3AED) : Colors.transparent, width: 2),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: active ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                ],
              ),
              if (badge > 0)
                Positioned(
                  right: 0,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(8)),
                    child: Text('$badge', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Products tab ─────────────────────────────

  Widget _buildMobileProductsTab(LanguageProvider languageProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: _buildSearchBarCompact(languageProvider),
        ),
        if (_searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildSearchDropdownCompact(languageProvider),
          ),
        if (_searchController.text.isEmpty) ...[
          // Category chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _filterChipCompact(
                  label: languageProvider.isEnglish ? 'All' : 'سب',
                  selected: _selectedCategory == null,
                  onTap: () => setState(() { _selectedCategory = null; _selectedSubcategory = null; }),
                  languageProvider: languageProvider,
                ),
                ..._categories.map((cat) => _filterChipCompact(
                  label: cat,
                  selected: _selectedCategory == cat,
                  onTap: () => setState(() { _selectedCategory = _selectedCategory == cat ? null : cat; _selectedSubcategory = null; }),
                  languageProvider: languageProvider,
                )),
              ],
            ),
          ),
          if (_selectedCategory != null && _subcategories.isNotEmpty)
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _filterChipCompact(
                    label: languageProvider.isEnglish ? 'All sub' : 'تمام ذیلی',
                    selected: _selectedSubcategory == null,
                    onTap: () => setState(() => _selectedSubcategory = null),
                    small: true,
                    languageProvider: languageProvider,
                  ),
                  ..._subcategories.map((sub) => _filterChipCompact(
                    label: sub,
                    selected: _selectedSubcategory == sub,
                    onTap: () => setState(() { _selectedSubcategory = _selectedSubcategory == sub ? null : sub; }),
                    small: true,
                    languageProvider: languageProvider,
                  )),
                ],
              ),
            ),
          Expanded(
            child: _isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : _buildBrowseProductGridCompact(languageProvider),
          ),
        ],
      ],
    );
  }

  // ── Cart tab ─────────────────────────────────

  Widget _buildMobileCartTab(LanguageProvider languageProvider) {
    return Column(
      children: [
        // Customer selector
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: _buildCustomerSectionCompact(languageProvider),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        Expanded(
          child: _cartItems.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFFD1D5DB)),
                const SizedBox(height: 8),
                Text(
                  languageProvider.isEnglish ? 'Cart is empty' : 'کارٹ خالی ہے',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => setState(() => _mobileTab = 0),
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(
                    languageProvider.isEnglish ? 'Add Products' : 'پروڈکٹس شامل کریں',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(6),
            itemCount: _cartItems.length,
            itemBuilder: (ctx, i) => _buildCartItemCompact(i, languageProvider),
          ),
        ),
        if (_cartItems.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              children: [
                _summaryRowCompact(
                  languageProvider.isEnglish ? 'Subtotal' : 'ذیلی کل',
                  'Rs ${_subtotal.toStringAsFixed(2)}',
                  languageProvider: languageProvider,
                ),
                if (_discountValue > 0)
                  _summaryRowCompact(
                    languageProvider.isEnglish ? 'Discount' : 'ڈسکاؤنٹ',
                    '- Rs ${_discountValue.toStringAsFixed(2)}',
                    color: const Color(0xFF10B981),
                    languageProvider: languageProvider,
                  ),
                const Divider(height: 8),
                _summaryRowCompact(
                  languageProvider.isEnglish ? 'Total' : 'کل',
                  'Rs ${_grandTotal.toStringAsFixed(2)}',
                  isBold: true,
                  fontSize: 14,
                  languageProvider: languageProvider,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Options tab (FULL) ────────────────────────

  Widget _buildMobileOptionsTab(LanguageProvider languageProvider) {
    final hasCustomer = _selectedCustomer != null;
    final hasCustomerDiscount = hasCustomer && _selectedCustomer!.discountPercent > 0;
    final bool usingCustomerDiscount = hasCustomerDiscount && _usePercentDiscount && _discountPercent == _selectedCustomer!.discountPercent;
    final isSarya = _selectedSaleType == SaleType.sarya;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Sale Mode ─────────────────────────────
          _buildMobileOptionCard(
            icon: Icons.tune,
            title: languageProvider.isEnglish ? 'Sale Mode' : 'فروخت کا طریقہ',
            child: Column(
              children: [
                // Sale Type: Sarya / Filled
                _buildMobileOptionLabel(
                  languageProvider.isEnglish ? 'Sale Category' : 'فروخت کی قسم',
                  languageProvider,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 36,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F8), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      _buildSaleTypeToggle(SaleType.filled, languageProvider),
                      _buildSaleTypeToggle(SaleType.sarya, languageProvider),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Invoice / POS toggle
                if (!_isEditMode) ...[
                  _buildMobileOptionLabel(
                    languageProvider.isEnglish ? 'Sale Mode' : 'فروخت کا طریقہ',
                    languageProvider,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: const Color(0xFFF0F0F8), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        _buildToggleBtn(languageProvider.isEnglish ? 'POS' : 'پی او ایس', Icons.point_of_sale, true, languageProvider),
                        _buildToggleBtn(languageProvider.isEnglish ? 'Invoice' : 'انوائس', Icons.receipt_long, false, languageProvider),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Invoice Details ───────────────────────
          _buildMobileOptionCard(
            icon: Icons.receipt,
            title: languageProvider.isEnglish ? 'Invoice Details' : 'انوائس کی تفصیلات',
            child: Column(
              children: [
                // Reference
                _buildMobileOptionLabel(
                  languageProvider.isEnglish ? 'Reference #' : 'حوالہ نمبر',
                  languageProvider,
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.receipt_long, size: 14, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _referenceController,
                          style: TextStyle(fontSize: 13, fontFamily: languageProvider.fontFamily),
                          decoration: InputDecoration(
                            hintText: languageProvider.isEnglish ? 'Enter reference number' : 'حوالہ نمبر درج کریں',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFB0B7C3)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_referenceController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 14, color: Color(0xFF9CA3AF)),
                          onPressed: () => setState(() => _referenceController.clear()),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Dates row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMobileOptionLabel(
                            languageProvider.isEnglish ? 'Sale Date' : 'فروخت کی تاریخ',
                            languageProvider,
                          ),
                          const SizedBox(height: 6),
                          _buildMobileDateField(
                            value: _formatDate(_invoiceDate),
                            icon: Icons.calendar_today,
                            onTap: () async {
                              final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _invoiceDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030)
                              );
                              if (picked != null) setState(() => _invoiceDate = picked);
                            },
                            languageProvider: languageProvider,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMobileOptionLabel(
                            languageProvider.isEnglish ? 'Due Date' : 'آخری تاریخ',
                            languageProvider,
                          ),
                          const SizedBox(height: 6),
                          _buildMobileDateField(
                            value: _dueDate != null ? _formatDate(_dueDate!) : (languageProvider.isEnglish ? 'Not set' : 'مقرر نہیں'),
                            icon: Icons.event,
                            hasValue: _dueDate != null,
                            onTap: () async {
                              final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030)
                              );
                              if (picked != null) setState(() => _dueDate = picked);
                            },
                            languageProvider: languageProvider,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Discount & Pricing ────────────────────
          _buildMobileOptionCard(
            icon: Icons.local_offer,
            title: languageProvider.isEnglish ? 'Discount & Pricing' : 'ڈسکاؤنٹ اور قیمتوں کا تعین',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Discount type toggle + field
                Row(
                  children: [
                    Expanded(child: _buildMobileOptionLabel(
                      languageProvider.isEnglish ? 'Discount' : 'ڈسکاؤنٹ',
                      languageProvider,
                    )),
                    GestureDetector(
                      onTap: () {
                        setState(() => _usePercentDiscount = !_usePercentDiscount);
                        _syncDiscountControllers();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                        ),
                        child: Text(
                          _usePercentDiscount
                              ? (languageProvider.isEnglish ? '% Percent' : 'فیصد')
                              : (languageProvider.isEnglish ? 'Rs Fixed' : 'مقررہ رقم'),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                        ),
                        child: Text(
                          _usePercentDiscount ? '%' : 'Rs',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _usePercentDiscount ? _discountPercentCtrl : _discountAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 14, fontFamily: languageProvider.fontFamily),
                          decoration: InputDecoration(
                            hintText: _usePercentDiscount ? '0.0' : '0.00',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (v) {
                            if (_updatingDiscountCtrl) return;
                            final parsed = double.tryParse(v) ?? 0.0;
                            setState(() {
                              if (_usePercentDiscount) _discountPercent = parsed.clamp(0, 100);
                              else _discountAmount = parsed.clamp(0, _subtotal > 0 ? _subtotal : double.infinity);
                            });
                          },
                        ),
                      ),
                      if (_discountValue > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '- Rs ${_discountValue.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Customer default discount button
                if (hasCustomerDiscount) ...[
                  const SizedBox(height: 8),
                  _buildCustomerDiscountCheckbox(usingCustomerDiscount, languageProvider),
                ],

                // Customer pricing toggle
                if (hasCustomer) ...[
                  const SizedBox(height: 10),
                  _buildMobileOptionLabel(
                    languageProvider.isEnglish ? 'Customer Pricing' : 'کسٹمر کی قیمتیں',
                    languageProvider,
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _useCustomerPrices ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _useCustomerPrices ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _useCustomerPrices,
                            activeColor: const Color(0xFF10B981),
                            onChanged: _isFetchingCustomerPrices ? null : (val) async {
                              setState(() => _useCustomerPrices = val);
                              await _fetchAndApplyCustomerPrices();
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.isEnglish ? 'Use Customer Prices' : 'کسٹمر کی قیمتیں استعمال کریں',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _useCustomerPrices ? const Color(0xFF065F46) : const Color(0xFF374151),
                                  fontFamily: languageProvider.fontFamily,
                                ),
                              ),
                              if (_useCustomerPrices && _customerPriceMap.isNotEmpty)
                                Text(
                                  languageProvider.isEnglish
                                      ? '${_customerPriceMap.length} custom price(s) applied'
                                      : '${_customerPriceMap.length} حسب ضرورت قیمتیں لاگو ہیں',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF10B981)),
                                ),
                            ],
                          ),
                        ),
                        if (_isFetchingCustomerPrices)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                        else if (_useCustomerPrices && _customerPriceMap.isNotEmpty)
                          const Icon(Icons.verified, size: 18, color: Color(0xFF10B981)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Notes ────────────────────────────────
          _buildMobileOptionCard(
            icon: Icons.notes,
            title: languageProvider.isEnglish ? 'Notes' : 'نوٹس',
            child: TextField(
              controller: _invoiceNoteController,
              maxLines: 3,
              style: TextStyle(fontSize: 13, fontFamily: languageProvider.fontFamily),
              decoration: InputDecoration(
                hintText: languageProvider.isEnglish ? 'Add any notes for this sale…' : 'اس فروخت کے لیے کوئی نوٹ شامل کریں…',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFB0B7C3)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                ),
                contentPadding: const EdgeInsets.all(10),
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Print Preview ─────────────────────────
          if (_cartItems.isNotEmpty && _selectedCustomer != null)
            OutlinedButton.icon(
              onPressed: _showQuickPrintPreview,
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(
                languageProvider.isEnglish ? 'Print Preview' : 'پرنٹ پیش نظارہ',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(double.infinity, 42),
              ),
            ),

          const SizedBox(height: 80), // space for bottom bar
        ],
      ),
    );
  }

  Widget _buildMobileOptionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 14, color: const Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E1E2D)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMobileOptionLabel(String label, LanguageProvider languageProvider) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6B7280),
        fontFamily: languageProvider.fontFamily,
      ),
    );
  }

  Widget _buildMobileDateField({
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool hasValue = true,
    required LanguageProvider languageProvider,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasValue ? const Color(0xFF1E1E2D) : const Color(0xFF9CA3AF),
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile bottom action bar ──────────────────

  Widget _buildMobileBottomBar(LanguageProvider languageProvider) {
    final canSubmit = _cartItems.isNotEmpty && _selectedCustomer != null;

    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEF5))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          // Mini summary
          if (_cartItems.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageProvider.isEnglish
                      ? '${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''}'
                      : '${_cartItems.length} اشیاء',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                Text(
                  'Rs ${_grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                ),
                if (_discountValue > 0)
                  Text(
                    languageProvider.isEnglish
                        ? 'Disc: -Rs ${_discountValue.toStringAsFixed(2)}'
                        : 'ڈسک: -Rs ${_discountValue.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF10B981)),
                  ),
              ],
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canSubmit
                  ? (_isEditMode ? _submitEdit : (_isPosMode ? _processPayment : _createInvoice))
                  : null,
              icon: Icon(_isEditMode ? Icons.save : (_isPosMode ? Icons.payment : Icons.receipt_long), size: 16),
              label: Text(
                _isEditMode
                    ? (languageProvider.isEnglish ? 'Save Changes' : 'تبدیلیاں محفوظ کریں')
                    : (_isPosMode
                    ? (languageProvider.isEnglish ? 'Charge' : 'چارج کریں')
                    : (languageProvider.isEnglish ? 'Create Invoice' : 'انوائس بنائیں')),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD1D5DB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar / dropdown / grid ─────────────

  Widget _buildSearchBarCompact(LanguageProvider languageProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: TextStyle(fontFamily: languageProvider.fontFamily),
              decoration: InputDecoration(
                hintText: languageProvider.isEnglish ? 'Search products…' : 'پروڈکٹس تلاش کریں…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B7C3)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (_) {
                if (_searchResults.length == 1) _addToCart(_searchResults.first);
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchResults = []);
              },
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF7C3AED)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _showBarcodeScanDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSearchDropdownCompact(LanguageProvider languageProvider) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
        itemBuilder: (context, i) {
          final p = _searchResults[i];
          final inCart = _cartItems.any((item) => item.product.id == p.id);
          final displayPrice = _resolvePrice(p);
          return ListTile(
            dense: true,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF7C3AED)),
            ),
            title: Text(
              p.itemName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
            ),
            subtitle: Text(
              p.barcode ?? '',
              style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontFamily: languageProvider.fontFamily),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rs ${displayPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 6),
                inCart
                    ? Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                )
                    : ElevatedButton(
                  onPressed: () => _addToCart(p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(0, 26),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(
                    languageProvider.isEnglish ? 'Add' : 'شامل کریں',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrowseProductGridCompact(LanguageProvider languageProvider) {
    final products = _filteredBrowseProducts;
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.point_of_sale, size: 40, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'No products' : 'کوئی پروڈکٹ نہیں',
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.85,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) => _buildProductCardCompact(products[i], languageProvider),
    );
  }

  Widget _buildProductCardCompact(ProductModel product, LanguageProvider languageProvider) {
    final inCart = _cartItems.any((item) => item.product.id == product.id);
    final displayPrice = _resolvePrice(product);
    final isLowStock = product.physicalQty <= product.minStock;

    return GestureDetector(
      onTap: () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: inCart ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: inCart ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: inCart ? const Color(0xFFDCFCE7) : const Color(0xFFF3F0FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.inventory_2_outlined, size: 24, color: Color(0xFF7C3AED))),
                  if (isLowStock)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(3)),
                        child: Text(
                          languageProvider.isEnglish ? 'Low' : 'کم',
                          style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ),
                  if (inCart)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(3)),
                        child: const Icon(Icons.check, size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E1E2D),
                        fontFamily: languageProvider.fontFamily,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Rs ${displayPrice.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                          ),
                        ),
                        if (inCart)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '×${_cartItems.firstWhere((i) => i.product.id == product.id).quantity}',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
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

  // Widget _buildCartItemCompact(int index, LanguageProvider languageProvider) {
  //   final item = _cartItems[index];
  //   final isSaryaType = _selectedSaleType == SaleType.sarya;
  //
  //   // Get or create controller for this item
  //   if (!_weightControllers.containsKey(index)) {
  //     final controller = TextEditingController(
  //       text: item.hasWeight ? item.weight.toStringAsFixed(2) : '',
  //     );
  //     _weightControllers[index] = controller;
  //   }
  //   final weightController = _weightControllers[index]!;
  //
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 4),
  //     padding: const EdgeInsets.all(8),
  //     decoration: BoxDecoration(
  //       color: item.usingCustomerPrice ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: const Color(0xFFEEEEF5)),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       mainAxisSize: MainAxisSize.min, // ✅ Add this to prevent overflow
  //       children: [
  //         Row(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // ✅ Wrap in Expanded with constrained width
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   Text(
  //                     item.product.itemName,
  //                     style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
  //                     maxLines: 1,
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                   // ✅ Show description if exists - with constrained height
  //                   if (item.description != null && item.description!.isNotEmpty)
  //                     Container(
  //                       constraints: const BoxConstraints(maxHeight: 32), // ✅ Limit height
  //                       child: Text(
  //                         item.description!,
  //                         style: TextStyle(
  //                           fontSize: 10,
  //                           color: Colors.grey[600],
  //                           fontFamily: languageProvider.fontFamily,
  //                           fontStyle: FontStyle.italic,
  //                         ),
  //                         maxLines: 2,
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //             if (item.usingCustomerPrice)
  //               Container(
  //                 margin: const EdgeInsets.only(right: 4),
  //                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
  //                 decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(3)),
  //                 child: Text(
  //                   languageProvider.isEnglish ? 'Custom' : 'حسب ضرورت',
  //                   style: const TextStyle(fontSize: 8, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
  //                 ),
  //               ),
  //             IconButton(
  //               icon: const Icon(Icons.close, size: 14, color: Color(0xFFEF4444)),
  //               padding: EdgeInsets.zero,
  //               constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
  //               onPressed: () => _removeFromCart(index),
  //             ),
  //           ],
  //         ),
  //         Row(
  //           children: [
  //             // Price badge
  //             Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //               decoration: BoxDecoration(
  //                 color: item.usingCustomerPrice ? const Color(0xFFECFDF5) : const Color(0xFFF3F0FF),
  //                 borderRadius: BorderRadius.circular(4),
  //               ),
  //               child: Text(
  //                 'Rs ${item.unitPrice.toStringAsFixed(2)}',
  //                 style: TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: FontWeight.w600,
  //                   color: item.usingCustomerPrice ? const Color(0xFF065F46) : const Color(0xFF7C3AED),
  //                   fontFamily: languageProvider.fontFamily,
  //                 ),
  //               ),
  //             ),
  //             const Spacer(),
  //             // Qty / weight controls
  //             if (isSaryaType)
  //               SizedBox(
  //                 width: 80,
  //                 child: TextField(
  //                   controller: weightController,
  //                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(fontSize: 11, fontFamily: languageProvider.fontFamily),
  //                   decoration: InputDecoration(
  //                     hintText: languageProvider.isEnglish ? 'Weight' : 'وزن',
  //                     hintStyle: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
  //                     isDense: true,
  //                     contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  //                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
  //                     suffixText: 'Kg',
  //                     suffixStyle: const TextStyle(fontSize: 8),
  //                   ),
  //                   onChanged: (v) {
  //                     final w = double.tryParse(v);
  //                     setState(() {
  //                       final old = _cartItems[index];
  //                       _cartItems[index] = SaleItem(
  //                         product: old.product,
  //                         quantity: old.quantity,
  //                         unitPrice: old.unitPrice,
  //                         customerSpecificPrice: old.customerSpecificPrice,
  //                         usingCustomerPrice: old.usingCustomerPrice,
  //                         selectedLengths: old.selectedLengths,
  //                         lengthQuantities: old.lengthQuantities,
  //                         lengthsDisplay: old.lengthsDisplay,
  //                         weight: w ?? 0.0,
  //                         description: old.description, // ✅ Preserve description
  //                       );
  //                     });
  //                   },
  //                 ),
  //               )
  //             else
  //               SizedBox(
  //                 width: 60,
  //                 child: TextField(
  //                   controller: _qtyControllers.putIfAbsent(
  //                     index,
  //                         () => TextEditingController(text: item.quantity.toString()),
  //                   ),
  //                   keyboardType: TextInputType.number,
  //                   textAlign: TextAlign.center,
  //                   style: TextStyle(fontSize: 11, fontFamily: languageProvider.fontFamily),
  //                   decoration: InputDecoration(
  //                     isDense: true,
  //                     contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  //                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
  //                   ),
  //                   onChanged: (v) {
  //                     final parsed = int.tryParse(v);
  //                     if (parsed != null && parsed >= 0) setState(() => _cartItems[index].quantity = parsed.clamp(0, 9999));
  //                   },
  //                 ),
  //               ),
  //             const SizedBox(width: 8),
  //             Text(
  //               'Rs ${item.totalForMode(isSaryaType).toStringAsFixed(2)}',
  //               style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
  //             ),
  //           ],
  //         ),
  //         // ── DESCRIPTION FIELD ──────────────────────────
  //         const SizedBox(height: 6),
  //         TextField(
  //           controller: _descriptionControllers.putIfAbsent(
  //             index,
  //                 () => TextEditingController(text: item.description ?? ''),
  //           ),
  //           style: TextStyle(
  //             fontSize: 11,
  //             fontFamily: languageProvider.fontFamily,
  //             fontStyle: FontStyle.italic,
  //           ),
  //           maxLines: 2,
  //           decoration: InputDecoration(
  //             hintText: languageProvider.isEnglish ? 'Description (optional)…' : 'تفصیل (اختیاری)…',
  //             hintStyle: const TextStyle(fontSize: 10, color: Color(0xFFB0B7C3)),
  //             isDense: true,
  //             contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(6),
  //               borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
  //             ),
  //             focusedBorder: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(6),
  //               borderSide: const BorderSide(color: Color(0xFF7C3AED)),
  //             ),
  //           ),
  //           onChanged: (v) {
  //             _cartItems[index].description = v.trim().isEmpty ? null : v;
  //           },
  //         ),
  //         // ── LENGTH SELECTION BUTTON ─────────────────
  //         // ── LENGTH SELECTION (INLINE - NO DIALOG) ──────
  //         if (item.product.lengthCombinations != null && item.product.lengthCombinations!.isNotEmpty) ...[
  //           const SizedBox(height: 6),
  //           _buildInlineLengthSelector(index, item, languageProvider),
  //         ],
  //         // if (item.product.lengthCombinations != null && item.product.lengthCombinations!.isNotEmpty) ...[
  //         //   const SizedBox(height: 6),
  //         //   Row(
  //         //     children: [
  //         //       Expanded(
  //         //         child: ElevatedButton.icon(
  //         //           onPressed: () => _showLengthSelectionDialog(index),
  //         //           icon: const Icon(Icons.straighten, size: 14),
  //         //           label: Text(
  //         //             item.hasLengthCombinations
  //         //                 ? (languageProvider.isEnglish ? 'Edit Lengths' : 'لمبائیاں ترمیم کریں')
  //         //                 : (languageProvider.isEnglish ? 'Select Lengths' : 'لمبائیاں منتخب کریں'),
  //         //             style: const TextStyle(fontSize: 11),
  //         //           ),
  //         //           style: ElevatedButton.styleFrom(
  //         //             backgroundColor: item.hasLengthCombinations
  //         //                 ? const Color(0xFF10B981)
  //         //                 : const Color(0xFF7C3AED),
  //         //             foregroundColor: Colors.white,
  //         //             padding: const EdgeInsets.symmetric(vertical: 6),
  //         //             minimumSize: const Size(0, 32),
  //         //             shape: RoundedRectangleBorder(
  //         //               borderRadius: BorderRadius.circular(6),
  //         //             ),
  //         //           ),
  //         //         ),
  //         //       ),
  //         //     ],
  //         //   ),
  //         // ],
  //         // ── LENGTH CHIPS ──────────────────────────
  //         if (item.hasLengthCombinations)
  //           Padding(
  //             padding: const EdgeInsets.only(top: 4),
  //             child: Wrap(
  //               spacing: 4,
  //               runSpacing: 2,
  //               children: item.selectedLengths.map((length) {
  //                 final qty = item.lengthQuantities[length] ?? 1.0;
  //                 return Chip(
  //                   label: Text(
  //                     _safeLengthLabel(length, qty),
  //                     style: const TextStyle(fontSize: 9),
  //                   ),
  //                   backgroundColor: const Color(0xFFEDE9FE),
  //                   side: const BorderSide(color: Color(0xFF7C3AED)),
  //                   deleteIcon: const Icon(Icons.close, size: 10),
  //                   onDeleted: () => _removeLengthFromCartItem(index, length),
  //                   visualDensity: VisualDensity.compact,
  //                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //                 );
  //               }).toList(),
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }
  Widget _buildCartItemCompact(int index, LanguageProvider languageProvider) {
    final item = _cartItems[index];
    final isSaryaType = _selectedSaleType == SaleType.sarya;
    final hasLengthCombos = item.product.lengthCombinations != null &&
        item.product.lengthCombinations!.isNotEmpty;

    // Controllers — create once, reuse (never call putIfAbsent inline in build)
    if (!_weightControllers.containsKey(index)) {
      _weightControllers[index] = TextEditingController(
        text: item.hasWeight ? item.weight.toStringAsFixed(2) : '',
      );
    }
    if (!_qtyControllers.containsKey(index)) {
      _qtyControllers[index] = TextEditingController(
        text: item.quantity.toString(),
      );
    }
    if (!_descriptionControllers.containsKey(index)) {
      _descriptionControllers[index] = TextEditingController(
        text: item.description ?? '',
      );
    }

    final weightController = _weightControllers[index]!;
    final qtyController    = _qtyControllers[index]!;
    final descController   = _descriptionControllers[index]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: item.usingCustomerPrice
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Row 1: product name + custom badge + delete ──────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.product.itemName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: languageProvider.fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null && item.description!.isNotEmpty)
                      Text(
                        item.description!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontFamily: languageProvider.fontFamily,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (item.usingCustomerPrice)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    languageProvider.isEnglish ? 'Custom' : 'حسب ضرورت',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                onPressed: () => _removeFromCart(index),
              ),
            ],
          ),

          // ── Row 2: price + qty OR weight (only when no length combos) + total
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.usingCustomerPrice
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Rs ${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.usingCustomerPrice
                        ? const Color(0xFF065F46)
                        : const Color(0xFF7C3AED),
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ),
              const Spacer(),

              // Weight field — ONLY when sarya mode AND no length combos.
              // When length combos exist, weight lives inside _buildInlineLengthSelector.
              // Showing the same controller on two TextFields crashes Flutter.
              if (isSaryaType && !hasLengthCombos)
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: weightController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, fontFamily: languageProvider.fontFamily),
                    decoration: InputDecoration(
                      hintText:
                      languageProvider.isEnglish ? 'Weight' : 'وزن',
                      hintStyle: const TextStyle(
                          fontSize: 8, color: Color(0xFF9CA3AF)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4)),
                      suffixText: 'Kg',
                      suffixStyle: const TextStyle(fontSize: 8),
                    ),
                    onChanged: (v) {
                      final w = double.tryParse(v) ?? 0.0;
                      final old = _cartItems[index];
                      setState(() {
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
                          description: old.description,
                        );
                      });
                    },
                  ),
                )

              // Qty field — filled mode only
              else if (!isSaryaType)
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, fontFamily: languageProvider.fontFamily),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed >= 0) {
                        setState(() =>
                        _cartItems[index].quantity = parsed.clamp(0, 9999));
                      }
                    },
                  ),
                ),

              const SizedBox(width: 8),
              Text(
                'Rs ${item.totalForMode(isSaryaType).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ],
          ),

          // ── Description field ─────────────────────────────────
          const SizedBox(height: 6),
          TextField(
            controller: descController,
            style: TextStyle(
              fontSize: 11,
              fontFamily: languageProvider.fontFamily,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: languageProvider.isEnglish
                  ? 'Description (optional)…'
                  : 'تفصیل (اختیاری)…',
              hintStyle:
              const TextStyle(fontSize: 10, color: Color(0xFFB0B7C3)),
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF7C3AED)),
              ),
            ),
            onChanged: (v) {
              setState(() {
                _cartItems[index].description = v.trim().isEmpty ? null : v;
              });
            },
          ),

          // ── Inline length selector — contains its own weight field ──
          if (hasLengthCombos) ...[
            const SizedBox(height: 6),
            _buildInlineLengthSelector(index, item, languageProvider),
          ],

          // ── Selected length chips ─────────────────────────────
          if (item.hasLengthCombinations)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: item.selectedLengths.map((length) {
                  final qty = item.lengthQuantities[length] ?? 1.0;
                  return Chip(
                    label: Text(
                      _safeLengthLabel(length, qty),
                      style: const TextStyle(fontSize: 9),
                    ),
                    backgroundColor: const Color(0xFFEDE9FE),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    deleteIcon: const Icon(Icons.close, size: 10),
                    onDeleted: () => _removeLengthFromCartItem(index, length),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineLengthSelector(int index, SaleItem item, LanguageProvider languageProvider) {
    final combinations = item.product.lengthCombinations ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.straighten, size: 12, color: Color(0xFF7C3AED)),
                const SizedBox(width: 4),
                Text(
                  languageProvider.isEnglish ? 'Lengths' : 'لمبائیاں',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const Spacer(),
                if (item.hasLengthCombinations)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.selectedLengths.length} ${languageProvider.isEnglish ? 'selected' : 'منتخب'}',
                      style: const TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEF5)),

          // ── Weight field ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.scale, size: 11, color: Color(0xFF3B82F6)),
                const SizedBox(width: 4),
                Text(
                  languageProvider.isEnglish ? 'Weight (Kg):' : 'وزن (کلو):',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _weightControllers.putIfAbsent(
                      index,
                          () => TextEditingController(
                        text: item.hasWeight ? item.weight.toStringAsFixed(2) : '',
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                      ),
                    ),
                    onChanged: (v) {
                      final w = double.tryParse(v) ?? 0.0;
                      final old = _cartItems[index];
                      setState(() {
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
                          description: old.description,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Length rows ──────────────────────────
          ...combinations.map((combo) {
            final isSelected = item.selectedLengths.contains(combo.length);
            final qty = item.lengthQuantities[combo.length] ?? 1.0;

            // Ensure a qty controller exists for this combo
            final ctrlKey = '${index}_${combo.length}';
            if (!_inlineLengthQtyControllers.containsKey(ctrlKey)) {
              _inlineLengthQtyControllers[ctrlKey] = TextEditingController(
                text: isSelected ? qty.toStringAsFixed(0) : '',
              );
            }
            final qtyCtrl = _inlineLengthQtyControllers[ctrlKey]!;

            return Container(
              margin: const EdgeInsets.fromLTRB(6, 2, 6, 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  // Checkbox
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF10B981),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      onChanged: (val) {
                        final old = _cartItems[index];
                        final newLengths = List<String>.from(old.selectedLengths);
                        final newQtys = Map<String, double>.from(old.lengthQuantities);

                        if (val == true) {
                          newLengths.add(combo.length);
                          newQtys[combo.length] = 1.0;
                          qtyCtrl.text = '1';
                        } else {
                          newLengths.remove(combo.length);
                          newQtys.remove(combo.length);
                          qtyCtrl.text = '';
                        }

                        final newDisplay = newLengths.map((l) {
                          final q = newQtys[l] ?? 1.0;
                          return '\u2068$l\u2069 (${q.toStringAsFixed(0)})';
                        }).join(', ');

                        setState(() {
                          _cartItems[index] = SaleItem(
                            product: old.product,
                            quantity: old.quantity,
                            unitPrice: old.unitPrice,
                            customerSpecificPrice: old.customerSpecificPrice,
                            usingCustomerPrice: old.usingCustomerPrice,
                            selectedLengths: newLengths,
                            lengthQuantities: newQtys,
                            lengthsDisplay: newDisplay,
                            weight: old.weight,
                            description: old.description,
                          );
                        });
                      },
                    ),
                  ),
                  // Length label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          combo.length,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF065F46)
                                : const Color(0xFF374151),
                          ),
                        ),
                        if (combo.lengthDecimal.isNotEmpty)
                          Text(
                            combo.lengthDecimal,
                            style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
                          ),
                      ],
                    ),
                  ),
                  // Qty field (only when selected)
                  if (isSelected) ...[
                    Text(
                      languageProvider.isEnglish ? 'Qty:' : 'مقدار:',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 48,
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFF10B981)),
                          ),
                        ),
                        onChanged: (v) {
                          final newQty = double.tryParse(v) ?? 1.0;
                          final old = _cartItems[index];
                          if (!old.selectedLengths.contains(combo.length)) return;
                          final newQtys = Map<String, double>.from(old.lengthQuantities);
                          newQtys[combo.length] = newQty > 0 ? newQty : 1.0;
                          final newDisplay = old.selectedLengths.map((l) {
                            final q = newQtys[l] ?? 1.0;
                            return '\u2068$l\u2069 (${q.toStringAsFixed(0)})';
                          }).join(', ');
                          setState(() {
                            _cartItems[index] = SaleItem(
                              product: old.product,
                              quantity: old.quantity,
                              unitPrice: old.unitPrice,
                              customerSpecificPrice: old.customerSpecificPrice,
                              usingCustomerPrice: old.usingCustomerPrice,
                              selectedLengths: old.selectedLengths,
                              lengthQuantities: newQtys,
                              lengthsDisplay: newDisplay,
                              weight: old.weight,
                              description: old.description,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }


  // ── HEADER ───────────────────────────────────
  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.fromLTRB(_isMobile ? 6 : 12, _isMobile ? 8 : 12, _isMobile ? 8 : 16, _isMobile ? 8 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF2D3142), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditMode
                      ? '${languageProvider.isEnglish ? 'Edit' : 'ترمیم'} ${widget.existingSale!.invoiceNumber}'
                      : (languageProvider.isEnglish ? 'New Sale' : 'نئی فروخت'),
                  style: TextStyle(
                    fontSize: _isMobile ? 15 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E2D),
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
                if (_isMobile)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedSaleType == SaleType.sarya ? const Color(0xFFEFF6FF) : const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _selectedSaleType.displayName,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _selectedSaleType == SaleType.sarya ? const Color(0xFF3B82F6) : const Color(0xFF7C3AED),
                            fontFamily: languageProvider.fontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          _isPosMode
                              ? (languageProvider.isEnglish ? 'POS' : 'پی او ایس')
                              : (languageProvider.isEnglish ? 'Invoice' : 'انوائس'),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (!_isMobile) ...[
            if (!_isEditMode) ...[
              Container(
                height: 32, margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: const Color(0xFFF0F0F8), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _buildSaleTypeToggle(SaleType.filled, languageProvider),
                    _buildSaleTypeToggle(SaleType.sarya, languageProvider),
                  ],
                ),
              ),
              Container(
                height: 32, padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: const Color(0xFFF0F0F8), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _buildToggleBtn(
                      languageProvider.isEnglish ? 'POS' : 'پی او ایس',
                      Icons.point_of_sale,
                      true,
                      languageProvider,
                    ),
                    _buildToggleBtn(
                      languageProvider.isEnglish ? 'Inv' : 'انوائس',
                      Icons.receipt_long,
                      false,
                      languageProvider,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
          if (_cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
              label: Text(
                languageProvider.isEnglish ? 'Clear' : 'صاف کریں',
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
              ),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
            ),
        ],
      ),
    );
  }

  Widget _buildSaleTypeToggle(SaleType type, LanguageProvider languageProvider) {
    final isActive = _selectedSaleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSaleType = type;
            _clearCart(); // Clear cart when switching types
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type == SaleType.sarya ? Icons.scale : Icons.production_quantity_limits,
                size: 12,
                color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String label, IconData icon, bool isPos, LanguageProvider languageProvider) {
    final isActive = _isPosMode == isPos;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(isPos),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DESKTOP LAYOUTS ───────────────────────────
  Widget _buildPosLayout(LanguageProvider languageProvider) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _buildProductPanelCompactWeb(languageProvider)),
              _buildLeftOptionsPanel(languageProvider),
            ],
          ),
        ),
        Container(
          width: _isTablet ? 320 : 360,
          decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Color(0xFFEEEEF5), width: 1))),
          child: _buildCartPanelWeb(isPOS: true, languageProvider: languageProvider),
        ),
      ],
    );
  }

  Widget _buildInvoiceLayout(LanguageProvider languageProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildInvoiceMetaCompact(languageProvider),
                const SizedBox(height: 8),
                _buildSearchBarCompact(languageProvider),
                const SizedBox(height: 6),
                if (_searchResults.isNotEmpty) _buildSearchDropdownCompact(languageProvider),
                const SizedBox(height: 8),
                _buildInvoiceItemsTableCompact(languageProvider),
                const SizedBox(height: 8),
                _buildInvoiceOptionsCardCompact(languageProvider),
                const SizedBox(height: 8),
                _buildInvoiceNotesCompact(languageProvider),
              ],
            ),
          ),
        ),
        Container(
          width: 360,
          decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: Color(0xFFEEEEF5), width: 1))),
          child: _buildCartPanelWeb(isPOS: false, languageProvider: languageProvider),
        ),
      ],
    );
  }

  Widget _buildProductPanelCompactWeb(LanguageProvider languageProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _buildSearchBarCompact(languageProvider),
        ),
        if (_searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSearchDropdownCompact(languageProvider),
          ),
        if (_searchController.text.isEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChipCompact(
                  label: languageProvider.isEnglish ? 'All' : 'سب',
                  selected: _selectedCategory == null,
                  onTap: () => setState(() { _selectedCategory = null; _selectedSubcategory = null; }),
                  languageProvider: languageProvider,
                ),
                ..._categories.map((cat) => _filterChipCompact(
                  label: cat,
                  selected: _selectedCategory == cat,
                  onTap: () => setState(() { _selectedCategory = _selectedCategory == cat ? null : cat; _selectedSubcategory = null; }),
                  languageProvider: languageProvider,
                )),
              ],
            ),
          ),
          if (_selectedCategory != null && _subcategories.isNotEmpty)
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _filterChipCompact(
                    label: languageProvider.isEnglish ? 'All sub' : 'تمام ذیلی',
                    selected: _selectedSubcategory == null,
                    onTap: () => setState(() => _selectedSubcategory = null),
                    small: true,
                    languageProvider: languageProvider,
                  ),
                  ..._subcategories.map((sub) => _filterChipCompact(
                    label: sub,
                    selected: _selectedSubcategory == sub,
                    onTap: () => setState(() { _selectedSubcategory = _selectedSubcategory == sub ? null : sub; }),
                    small: true,
                    languageProvider: languageProvider,
                  )),
                ],
              ),
            ),
        ],
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        Expanded(
          child: _searchController.text.isNotEmpty
              ? (_searchResults.isEmpty && !_isSearching ? _buildNoResultsCompact(languageProvider) : const SizedBox.shrink())
              : _buildBrowseProductGridCompact(languageProvider),
        ),
      ],
    );
  }

  Widget _filterChipCompact({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool small = false,
    required LanguageProvider languageProvider,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF7C3AED).withOpacity(0.12) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: small ? 9 : 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? const Color(0xFF7C3AED) : const Color(0xFF6B7280),
              fontFamily: languageProvider.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsCompact(LanguageProvider languageProvider) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off, size: 32, color: Color(0xFFD1D5DB)),
        const SizedBox(height: 8),
        Text(
          languageProvider.isEnglish ? 'No products found' : 'کوئی پروڈکٹ نہیں ملی',
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        ),
      ],
    ),
  );

  // ── LEFT OPTIONS PANEL (desktop POS) ─────────
  Widget _buildLeftOptionsPanel(LanguageProvider languageProvider) {
    final hasCustomer = _selectedCustomer != null;
    final hasCustomerDiscount = hasCustomer && _selectedCustomer!.discountPercent > 0;
    final bool usingCustomerDiscount = hasCustomerDiscount && _usePercentDiscount && _discountPercent == _selectedCustomer!.discountPercent;
    int activeOptions = 0;
    if (_useCustomerPrices && _customerPriceMap.isNotEmpty) activeOptions++;
    if (_discountValue > 0) activeOptions++;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEF5))),
        boxShadow: _showOptionsPanel ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)] : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _showOptionsPanel = !_showOptionsPanel),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.tune, size: 14, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    languageProvider.isEnglish ? 'Discount & Pricing' : 'ڈسکاؤنٹ اور قیمتوں کا تعین',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151), fontFamily: languageProvider.fontFamily),
                  ),
                  if (activeOptions > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(8)),
                      child: Text('$activeOptions', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showOptionsPanel ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCompactDiscountSection(usingCustomerDiscount, hasCustomerDiscount, languageProvider)),
                  const SizedBox(width: 8),
                  if (hasCustomer) Expanded(child: _buildCompactCustomerPriceToggle(languageProvider)),
                ],
              ),
            ),
            crossFadeState: _showOptionsPanel ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 260),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDiscountSection(bool usingCustomerDiscount, bool hasCustomerDiscount, LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              languageProvider.isEnglish ? 'Discount' : 'ڈسکاؤنٹ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF374151), fontFamily: languageProvider.fontFamily),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () { setState(() => _usePercentDiscount = !_usePercentDiscount); _syncDiscountControllers(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _usePercentDiscount ? '%' : 'Rs',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: TextField(
            controller: _usePercentDiscount ? _discountPercentCtrl : _discountAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 10, fontFamily: languageProvider.fontFamily),
            decoration: InputDecoration(
              hintText: _usePercentDiscount ? '0.0 %' : '0.00 Rs',
              hintStyle: const TextStyle(fontSize: 10),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (v) {
              if (_updatingDiscountCtrl) return;
              final parsed = double.tryParse(v) ?? 0.0;
              setState(() {
                if (_usePercentDiscount) _discountPercent = parsed.clamp(0, 100);
                else _discountAmount = parsed.clamp(0, _subtotal > 0 ? _subtotal : double.infinity);
              });
            },
          ),
        ),
        if (hasCustomerDiscount && _selectedCustomer != null) ...[
          const SizedBox(height: 4),
          _buildCustomerDiscountCheckbox(usingCustomerDiscount, languageProvider),
        ],
      ],
    );
  }

  Widget _buildCompactCustomerPriceToggle(LanguageProvider languageProvider) {
    final hasAnyCustom = _customerPriceMap.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.isEnglish ? 'Customer Pricing' : 'کسٹمر کی قیمتیں',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF374151), fontFamily: languageProvider.fontFamily),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _useCustomerPrices ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _useCustomerPrices ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: Checkbox(
                  value: _useCustomerPrices,
                  onChanged: _isFetchingCustomerPrices ? null : (val) async {
                    setState(() => _useCustomerPrices = val ?? false);
                    await _fetchAndApplyCustomerPrices();
                  },
                  activeColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  languageProvider.isEnglish ? 'Use Prices' : 'قیمتیں استعمال کریں',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _useCustomerPrices ? const Color(0xFF065F46) : const Color(0xFF374151),
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ),
              if (_isFetchingCustomerPrices)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
              else if (_useCustomerPrices && hasAnyCustom)
                const Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceOptionsCardCompact(LanguageProvider languageProvider) {
    final hasCustomer = _selectedCustomer != null;
    final hasCustomerDiscount = hasCustomer && _selectedCustomer!.discountPercent > 0;
    final bool usingCustomerDiscount = hasCustomerDiscount && _usePercentDiscount && _discountPercent == _selectedCustomer!.discountPercent;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEF5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildCompactDiscountSection(usingCustomerDiscount, hasCustomerDiscount, languageProvider)),
          if (hasCustomer) ...[const SizedBox(width: 10), Expanded(child: _buildCompactCustomerPriceToggle(languageProvider))],
        ],
      ),
    );
  }

  Widget _buildCustomerDiscountCheckbox(bool usingCustomerDiscount, LanguageProvider languageProvider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: usingCustomerDiscount ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: usingCustomerDiscount ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Checkbox(
              value: usingCustomerDiscount,
              onChanged: (val) {
                if (val == true) _applyCustomerDiscount();
                else { setState(() { _discountPercent = 0; _discountAmount = 0; }); _syncDiscountControllers(); }
              },
              activeColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              usingCustomerDiscount
                  ? (languageProvider.isEnglish
                  ? 'Applied ${_selectedCustomer!.discountPercent.toStringAsFixed(1)}%'
                  : 'لاگو ${_selectedCustomer!.discountPercent.toStringAsFixed(1)}%')
                  : (languageProvider.isEnglish
                  ? '${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% for ${_selectedCustomer!.name}'
                  : '${_selectedCustomer!.discountPercent.toStringAsFixed(1)}% ${_selectedCustomer!.name} کے لیے'),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: usingCustomerDiscount ? const Color(0xFF065F46) : const Color(0xFF374151),
                fontFamily: languageProvider.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyCustomerDiscount() {
    if (_selectedCustomer == null) return;
    setState(() { _usePercentDiscount = true; _discountPercent = _selectedCustomer!.discountPercent; });
    _syncDiscountControllers();
  }

  // ── INVOICE WIDGETS (desktop) ─────────────────
  Widget _buildInvoiceMetaCompact(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEF5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish ? 'Invoice Details' : 'انوائس کی تفصیلات',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
          ),
          const SizedBox(height: 8),
          _buildReferenceFieldCompact(languageProvider),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMetaFieldCompact(
                label: languageProvider.isEnglish ? 'Date' : 'تاریخ',
                value: _formatDate(_invoiceDate),
                icon: Icons.calendar_today,
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _invoiceDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null) setState(() => _invoiceDate = picked);
                },
                languageProvider: languageProvider,
              )),
              const SizedBox(width: 8),
              Expanded(child: _buildMetaFieldCompact(
                label: languageProvider.isEnglish ? 'Due' : 'آخری تاریخ',
                value: _dueDate != null ? _formatDate(_dueDate!) : (languageProvider.isEnglish ? 'Not set' : 'مقرر نہیں'),
                icon: Icons.event,
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime(2030));
                  if (picked != null) setState(() => _dueDate = picked);
                },
                languageProvider: languageProvider,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceFieldCompact(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(
        children: [
          const Icon(Icons.receipt, size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _referenceController,
              style: TextStyle(fontSize: 12, fontFamily: languageProvider.fontFamily),
              decoration: InputDecoration(
                hintText: languageProvider.isEnglish ? 'Reference #' : 'حوالہ نمبر',
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFB0B7C3)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_referenceController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 14, color: Color(0xFF9CA3AF)),
              onPressed: () => _referenceController.clear(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaFieldCompact({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required LanguageProvider languageProvider,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                label,
                style: TextStyle(fontSize: 8, color: const Color(0xFF9CA3AF), fontFamily: languageProvider.fontFamily),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsTableCompact(LanguageProvider languageProvider) {
    final isSaryaMode = _selectedSaleType == SaleType.sarya;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEF5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Text(
                  languageProvider.isEnglish ? 'Items' : 'اشیاء',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSaryaMode ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(isSaryaMode ? Icons.scale : Icons.production_quantity_limits, size: 10,
                          color: isSaryaMode ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                      const SizedBox(width: 2),
                      Text(
                        isSaryaMode
                            ? (languageProvider.isEnglish ? 'Weight' : 'وزن')
                            : (languageProvider.isEnglish ? 'Qty' : 'مقدار'),
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                            color: isSaryaMode ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_cartItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  languageProvider.isEnglish ? 'No items added' : 'کوئی اشیاء شامل نہیں',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (ctx, i) {
                final item = _cartItems[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${item.product.itemName}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: languageProvider.fontFamily),
                          ),
                          if (item.usingCustomerPrice && item.hasPriceDifference)
                            Text(
                              '${_selectedCustomer?.name ?? ''} ${languageProvider.isEnglish ? 'price' : 'قیمت'}',
                              style: const TextStyle(fontSize: 8, color: Color(0xFF10B981)),
                            ),
                        ],
                      )),
                      Expanded(child: isSaryaMode ? _buildInvoiceWeightFieldCompact(i, languageProvider) :
                      Text('${item.quantity}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontFamily: languageProvider.fontFamily))),
                      Expanded(child: Text('Rs ${item.unitPrice.toStringAsFixed(2)}', textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, color: item.usingCustomerPrice ? const Color(0xFF10B981) : null, fontFamily: languageProvider.fontFamily))),
                      Expanded(child: Text('Rs ${item.totalForMode(isSaryaMode).toStringAsFixed(2)}', textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                              color: item.usingCustomerPrice ? const Color(0xFF10B981) : const Color(0xFF7C3AED), fontFamily: languageProvider.fontFamily))),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        onPressed: () => _removeFromCart(i),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceWeightFieldCompact(int index, LanguageProvider languageProvider) {
    final item = _cartItems[index];

    // Get or create controller
    if (!_weightControllers.containsKey(index)) {
      final controller = TextEditingController(
        text: item.hasWeight ? item.weight.toStringAsFixed(2) : '',
      );
      _weightControllers[index] = controller;
    }

    final controller = _weightControllers[index]!;

    return SizedBox(
      width: 80,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
        decoration: InputDecoration(
          hintText: languageProvider.isEnglish ? 'Weight' : 'وزن',
          hintStyle: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onChanged: (value) {
          final weight = double.tryParse(value);
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
              weight: weight ?? 0.0,
              description: old.description,
            );
          });
        },
      ),
    );
  }

  Widget _buildInvoiceNotesCompact(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEF5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish ? 'Notes' : 'نوٹس',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _invoiceNoteController,
            maxLines: 2,
            style: TextStyle(fontFamily: languageProvider.fontFamily),
            decoration: InputDecoration(
              hintText: languageProvider.isEnglish ? 'Add notes…' : 'نوٹس شامل کریں…',
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFB0B7C3)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.all(8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── CART PANEL (desktop) ──────────────────────
  Widget _buildCartPanelWeb({required bool isPOS, required LanguageProvider languageProvider}) {
    return Column(
      children: [
        _buildCustomerSectionCompact(languageProvider),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        Expanded(
          child: _cartItems.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.shopping_cart_outlined, size: 32, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 4),
            Text(
              languageProvider.isEnglish ? 'Cart is empty' : 'کارٹ خالی ہے',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ]))
              : ListView.builder(
            padding: const EdgeInsets.all(6),
            itemCount: _cartItems.length,
            itemBuilder: (ctx, i) => isPOS ? _buildCartItem(i, languageProvider) : _buildCartItemForInvoice(i, languageProvider),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEF5)),
        _buildSummarySectionWeb(isPOS, languageProvider),
      ],
    );
  }

  Widget _buildCustomerSectionCompact(LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showCustomerPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedCustomer != null ? const Color(0xFFF3F0FF) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedCustomer != null ? const Color(0xFF7C3AED).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.5),
                    width: _selectedCustomer == null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_selectedCustomer != null ? Icons.person : Icons.person_add_alt, size: 14,
                        color: _selectedCustomer != null ? const Color(0xFF7C3AED) : const Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selectedCustomer?.name ?? (languageProvider.isEnglish ? 'Select Customer *' : 'کسٹمر منتخب کریں *'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedCustomer != null ? FontWeight.w600 : FontWeight.w400,
                          color: _selectedCustomer != null ? const Color(0xFF7C3AED) : const Color(0xFFEF4444),
                          fontFamily: languageProvider.fontFamily,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedCustomer != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedCustomer = null; _useCustomerPrices = false; _customerPriceMap = {};
                          _discountAmount = 0; _discountPercent = 0;
                          for (final item in _cartItems) { item.usingCustomerPrice = false; item.customerSpecificPrice = null; item.unitPrice = item.standardPrice; }
                        }),
                        child: const Icon(Icons.close, size: 12, color: Color(0xFF9CA3AF)),
                      )
                    else
                      const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFFEF4444)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _showAddCustomerDialog,
            icon: const Icon(Icons.person_add, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F0FF), foregroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.all(6), minimumSize: const Size(28, 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemForInvoice(int index, LanguageProvider languageProvider) {
    final item = _cartItems[index];
    final isSaryaType = _selectedSaleType == SaleType.sarya;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: item.usingCustomerPrice ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0F0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(
                item.product.itemName,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
              IconButton(icon: const Icon(Icons.close, size: 12, color: Color(0xFFEF4444)), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 18, minHeight: 18), onPressed: () => _removeFromCart(index)),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'Rs ${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.usingCustomerPrice ? const Color(0xFF065F46) : const Color(0xFF7C3AED),
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  isSaryaType
                      ? (item.hasWeight
                      ? '${item.weight.toStringAsFixed(2)} Kg'
                      : (languageProvider.isEnglish ? 'No weight' : 'کوئی وزن نہیں'))
                      : '${item.quantity} ${item.product.unit?.symbol ?? 'pcs'}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSaryaType && !item.hasWeight ? const Color(0xFFEF4444) : null,
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: item.usingCustomerPrice ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Rs ${item.totalForMode(isSaryaType).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.usingCustomerPrice ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int index, LanguageProvider languageProvider) {
    final item = _cartItems[index];
    final isSaryaType = _selectedSaleType == SaleType.sarya;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: item.usingCustomerPrice ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0F0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(
                item.product.itemName,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )),
              IconButton(icon: const Icon(Icons.close, size: 12, color: Color(0xFFEF4444)), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 18, minHeight: 18), onPressed: () => _removeFromCart(index)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: item.unitPrice.toStringAsFixed(2),
                  style: TextStyle(fontSize: 10, color: item.usingCustomerPrice ? const Color(0xFF065F46) : null, fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    prefix: const Text('Rs ', style: TextStyle(fontSize: 9)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) setState(() => _cartItems[index].unitPrice = parsed);
                  },
                ),
              ),
              const SizedBox(width: 4),
              if (isSaryaType)
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                        text: item.hasWeight ? item.weight.toStringAsFixed(2) : ''
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontFamily: languageProvider.fontFamily),
                    decoration: InputDecoration(
                      hintText: languageProvider.isEnglish ? 'Weight' : 'وزن',
                      hintStyle: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onChanged: (v) {
                      final w = double.tryParse(v);
                      setState(() {
                        final old = _cartItems[index];
                        _cartItems[index] = SaleItem(
                          product: old.product, quantity: old.quantity, unitPrice: old.unitPrice,
                          customerSpecificPrice: old.customerSpecificPrice, usingCustomerPrice: old.usingCustomerPrice,
                          selectedLengths: old.selectedLengths, lengthQuantities: old.lengthQuantities,
                          lengthsDisplay: old.lengthsDisplay, weight: w ?? 0.0,
                        );
                      });
                    },
                  ),
                )
              else
                Expanded(
                  child: TextField(
                    controller: _qtyControllers.putIfAbsent(
                      index,
                          () => TextEditingController(text: item.quantity.toString()),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontFamily: languageProvider.fontFamily),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed >= 0) setState(() => _cartItems[index].quantity = parsed.clamp(0, 9999));
                    },
                  ),
                ),
              const SizedBox(width: 4),
              SizedBox(
                width: 60,
                child: Text(
                  'Rs ${item.totalForMode(isSaryaType).toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.usingCustomerPrice ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
              ),
            ],
          ),
          if (item.hasLengthCombinations) ...[
            const SizedBox(height: 4),
            ElevatedButton.icon(
              onPressed: () => _showLengthSelectionDialog(index),
              icon: const Icon(Icons.straighten, size: 12),
              label: Text(
                item.hasLengthCombinations
                    ? (languageProvider.isEnglish ? 'Edit Lengths' : 'لمبائیاں ترمیم کریں')
                    : (languageProvider.isEnglish ? 'Select Lengths' : 'لمبائیاں منتخب کریں'),
                style: const TextStyle(fontSize: 9),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: item.hasLengthCombinations ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: const Size(0, 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4, runSpacing: 2,
              children: item.selectedLengths.map((length) {
                final qty = item.lengthQuantities[length] ?? 1.0;
                return Chip(
                  label: Text(
                    _safeLengthLabel(length, qty),
                    style: const TextStyle(fontSize: 8),
                  ),
                  backgroundColor: const Color(0xFFD1FAE5),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  deleteIcon: const Icon(Icons.close, size: 8),
                  onDeleted: () => _removeLengthFromCartItem(index, length),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySectionWeb(bool isPOS, LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _summaryRowCompact(
            languageProvider.isEnglish ? 'Subtotal' : 'ذیلی کل',
            'Rs ${_subtotal.toStringAsFixed(2)}',
            languageProvider: languageProvider,
          ),
          if (_discountValue > 0)
            _summaryRowCompact(
              languageProvider.isEnglish ? 'Discount' : 'ڈسکاؤنٹ',
              '- Rs ${_discountValue.toStringAsFixed(2)}',
              color: const Color(0xFF10B981),
              languageProvider: languageProvider,
            ),
          const Divider(height: 8),
          _summaryRowCompact(
            languageProvider.isEnglish ? 'Total' : 'کل',
            'Rs ${_grandTotal.toStringAsFixed(2)}',
            isBold: true,
            fontSize: 14,
            languageProvider: languageProvider,
          ),
          const SizedBox(height: 8),
          if (_cartItems.isNotEmpty && _selectedCustomer != null) ...[
            OutlinedButton.icon(
              onPressed: _showQuickPrintPreview,
              icon: const Icon(Icons.print_outlined, size: 14),
              label: Text(
                languageProvider.isEnglish ? 'Print Preview' : 'پرنٹ پیش نظارہ',
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size(double.infinity, 30),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_isEditMode)
            ElevatedButton.icon(
              onPressed: _cartItems.isEmpty ? null : _submitEdit,
              icon: const Icon(Icons.save, size: 14),
              label: Text(
                languageProvider.isEnglish ? 'Save Changes' : 'تبدیلیاں محفوظ کریں',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          else if (isPOS)
            ElevatedButton.icon(
              onPressed: (_cartItems.isEmpty || _selectedCustomer == null) ? null : _processPayment,
              icon: const Icon(Icons.payment, size: 14),
              label: Text(
                languageProvider.isEnglish ? 'Charge' : 'چارج کریں',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _cartItems.isEmpty ? null : _createInvoice,
              icon: const Icon(Icons.receipt_long, size: 14),
              label: Text(
                languageProvider.isEnglish ? 'Create Invoice' : 'انوائس بنائیں',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRowCompact(
      String label,
      String value, {
        bool isBold = false,
        double fontSize = 11,
        Color? color,
        required LanguageProvider languageProvider,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color ?? const Color(0xFF6B7280),
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF1E1E2D),
              fontFamily: languageProvider.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  // ── Categories helper ─────────────────────────
  List<String> get _categories {
    return _allProducts.map((p) => p.category?.name ?? 'Uncategorized').toSet().toList()..sort();
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
      if (_selectedSubcategory != null && sub != _selectedSubcategory) return false;
      return true;
    }).toList();
  }

  // ── DIALOGS ───────────────────────────────────
  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          languageProvider.isEnglish ? 'Scan Barcode' : 'بارکوڈ اسکین کریں',
          style: const TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: const Center(child: Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFF7C3AED))),
            ),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'Use scanner or enter manually' : 'اسکینر استعمال کریں یا دستی درج کریں',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              style: TextStyle(fontFamily: languageProvider.fontFamily),
              decoration: InputDecoration(
                hintText: languageProvider.isEnglish ? 'Enter barcode' : 'بارکوڈ درج کریں',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.qr_code, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            child: Text(
              languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── SALE ACTIONS ──────────────────────────────
  void _processPayment() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              languageProvider.isEnglish ? 'Please select a customer' : 'براہ کرم کسٹمر منتخب کریں'
          ),
          backgroundColor: const Color(0xFFEF4444),
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
          if (method == 'credit' && paymentDetails != null && paymentDetails['due_date'] != null) {
            setState(() => _creditDueDate = DateTime.parse(paymentDetails['due_date']));
          } else {
            setState(() => _creditDueDate = null);
          }
          Navigator.pop(ctx);
          await _submitSale(saleType: 'pos', paymentMethod: method, amountPaid: amountReceived, paymentDetails: paymentDetails);
        },
      ),
    );
  }

  void _createInvoice() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              languageProvider.isEnglish ? 'Please select a customer' : 'براہ کرم کسٹمر منتخب کریں'
          ),
          backgroundColor: const Color(0xFFEF4444),
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
          if (method == 'credit' && paymentDetails != null && paymentDetails['due_date'] != null) {
            setState(() => _creditDueDate = DateTime.parse(paymentDetails['due_date']));
          } else {
            setState(() => _creditDueDate = null);
          }
          Navigator.pop(ctx);
          await _submitSale(saleType: 'invoice', paymentMethod: method, amountPaid: amountReceived, paymentDetails: paymentDetails);
        },
      ),
    );
  }

  void _showPrintDialog(Uint8List pdfData, String invoiceNumber) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          languageProvider.isEnglish ? 'Document Generated' : 'دستاویز تیار ہوگئی',
          style: const TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFFF3F0FF), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long, size: 32, color: Color(0xFF7C3AED))),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish ? 'Created successfully!' : 'کامیابی سے تیار ہوگیا!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              invoiceNumber,
              style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontFamily: languageProvider.fontFamily),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); SalePdfGenerator.sharePdf(pdfData, '$invoiceNumber.pdf'); },
            child: Text(
              languageProvider.isEnglish ? 'Share' : 'شیئر کریں',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); SalePdfGenerator.printPdf(pdfData); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: Text(
              languageProvider.isEnglish ? 'Print' : 'پرنٹ کریں',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrintOptionsSheet(Uint8List pdfData) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 32, height: 3, margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2))),
            Text(
              languageProvider.isEnglish ? 'Print Options' : 'پرنٹ کے اختیارات',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildPrintOptionCompact(
                  icon: Icons.print,
                  label: languageProvider.isEnglish ? 'Print' : 'پرنٹ کریں',
                  color: const Color(0xFF7C3AED),
                  onTap: () { Navigator.pop(ctx); SalePdfGenerator.printPdf(pdfData); },
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildPrintOptionCompact(
                  icon: Icons.share,
                  label: languageProvider.isEnglish ? 'Share' : 'شیئر کریں',
                  color: const Color(0xFF10B981),
                  onTap: () { Navigator.pop(ctx); SalePdfGenerator.sharePdf(pdfData, 'receipt.pdf'); },
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildPrintOptionCompact(
                  icon: Icons.visibility,
                  label: languageProvider.isEnglish ? 'Preview' : 'پیش نظارہ',
                  color: const Color(0xFF3B82F6),
                  onTap: () { Navigator.pop(ctx); _showPdfPreview(pdfData); },
                )),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOptionCompact({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (_) => pdfData);
  }

  Future<void> _showQuickPrintPreview() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_cartItems.isEmpty || _selectedCustomer == null) return;

    // ✅ Get previous balance
    final double previousBalance = _selectedCustomer?.balance ?? 0.0;

    final items = _cartItems.map((item) {
      final total = _selectedSaleType == SaleType.sarya
          ? item.weight * item.unitPrice
          : item.quantity * item.unitPrice;

      return {
        'product_name': item.product.itemName,
        'description': item.description ?? '',
        'quantity': _selectedSaleType == SaleType.sarya ? 0 : item.quantity,
        'unit_price': item.unitPrice,
        'selected_lengths': item.selectedLengths,
        'lengths_display': item.lengthsDisplay,
        'length_quantities': Map<String, dynamic>.fromEntries(
            item.lengthQuantities.entries.map((e) => MapEntry(e.key.toString(), e.value))
        ),
        'weight': item.weight,
        'total': total,
      };
    }).toList();

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final pdfData = await SalePdfGenerator.generateSalePdf(
        saleData: {
          'invoice_number': 'PREVIEW-${DateTime.now().millisecondsSinceEpoch}',
          'reference': _referenceController.text.trim(),
          'sale_category': _selectedSaleType.apiValue,
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
        previousBalance: previousBalance, // ✅ Pass the balance
      );
      if (mounted) Navigator.pop(context);
      _showPrintOptionsSheet(pdfData);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              languageProvider.isEnglish
                  ? 'Failed to generate preview: $e'
                  : 'پیش نظارہ بنانے میں ناکامی: $e'
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── SUBMIT ────────────────────────────────────
  Future<void> _submitEdit() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_selectedSaleType == SaleType.sarya) {
      final missing = _cartItems.where((i) => i.weight <= 0).toList();
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                languageProvider.isEnglish
                    ? 'SARYA mode: ${missing.length} item(s) missing weight'
                    : 'SARYA موڈ: ${missing.length} اشیاء میں وزن درج نہیں'
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final isSarya = _selectedSaleType == SaleType.sarya;
    final saleData = {
      'sale_category': _selectedSaleType.apiValue,
      'customer_id': _selectedCustomer?.id,
      'sale_date': _invoiceDate.toIso8601String().split('T').first,
      'due_date': _dueDate?.toIso8601String().split('T').first,
      'reference': _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      'notes': _invoiceNoteController.text.trim(),
      'discount_type': _usePercentDiscount ? 'percent' : 'fixed',
      'discount_value': _usePercentDiscount ? _discountPercent : _discountAmount,
      'items': _cartItems.map((item) {
        final Map<String, dynamic> d = {
          'product_id': item.product.id,
          'unit_price': item.unitPrice,
          'used_customer_price': item.usingCustomerPrice,
          'description': item.description, // ✅ ADD DESCRIPTION
        };
        if (isSarya) {
          d['weight'] = item.weight;
          d['quantity'] = 0;
        } else {
          d['quantity'] = item.quantity;
          if (item.weight > 0) d['weight'] = item.weight;
        }
        if (item.selectedLengths.isNotEmpty) d['selected_lengths'] = item.selectedLengths;
        if (item.lengthQuantities.isNotEmpty) {
          d['length_quantities'] = Map<String, dynamic>.fromEntries(
              item.lengthQuantities.entries.map((e) => MapEntry(e.key.toString(), e.value))
          );
        }
        return d;
      }).toList(),
    };

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final result = await provider.updateSale(widget.existingSale!.id, saleData);
    if (mounted) Navigator.pop(context);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              languageProvider.isEnglish ? 'Sale updated successfully' : 'فروخت کامیابی سے اپ ڈیٹ ہوگئی'
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result['message'] ?? (languageProvider.isEnglish ? 'Failed to update sale' : 'فروخت اپ ڈیٹ کرنے میں ناکامی')
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _submitSale({required String saleType, required String paymentMethod, required double amountPaid, Map<String, dynamic>? paymentDetails}) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_selectedSaleType == SaleType.sarya) {
      final itemsWithoutWeight = _cartItems.where((item) => item.weight <= 0).toList();
      if (itemsWithoutWeight.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                languageProvider.isEnglish
                    ? 'SARYA mode requires weight for all items. ${itemsWithoutWeight.length} item(s) have missing weight.'
                    : 'SARYA موڈ میں تمام اشیاء کے لیے وزن درکار ہے۔ ${itemsWithoutWeight.length} اشیاء میں وزن درج نہیں۔'
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    }
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final bool isCredit = paymentMethod == 'credit';
    final finalAmountPaid = isCredit ? 0.0 : amountPaid;
    double discountAmount = _usePercentDiscount ? _subtotal * (_discountPercent / 100) : _discountAmount;
    discountAmount = discountAmount.clamp(0, _subtotal);

    // ✅ Get previous balance BEFORE creating the sale
    final double previousBalance = _selectedCustomer?.balance ?? 0.0;

    final saleData = {
      'sale_type': saleType,
      'sale_category': _selectedSaleType.apiValue,
      'customer_id': _selectedCustomer?.id,
      'sale_date': _invoiceDate.toIso8601String().split('T').first,
      'reference': _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      'due_date': isCredit && _creditDueDate != null ? _creditDueDate!.toIso8601String().split('T').first : _dueDate?.toIso8601String().split('T').first,
      'items': _cartItems.map((item) {
        final Map<String, dynamic> itemData = {
          'product_id': item.product.id,
          'unit_price': item.unitPrice,
          'used_customer_price': item.usingCustomerPrice,
          'description': item.description,
        };
        if (_selectedSaleType == SaleType.sarya) {
          itemData['weight'] = item.weight;
          itemData['quantity'] = 0;
        } else {
          itemData['quantity'] = item.quantity;
          if (item.weight > 0) itemData['weight'] = item.weight;
        }
        if (item.selectedLengths.isNotEmpty) itemData['selected_lengths'] = item.selectedLengths;
        if (item.lengthQuantities.isNotEmpty) {
          itemData['length_quantities'] = Map<String, dynamic>.fromEntries(
              item.lengthQuantities.entries.map((e) => MapEntry(e.key.toString(), e.value))
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

    if (paymentDetails != null && !isCredit) {
      saleData['payment_details'] = paymentDetails;
    } else if (isCredit && paymentDetails != null) {
      saleData['credit_details'] = {'due_date': paymentDetails['due_date'], 'notes': paymentDetails['notes']};
    }

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final result = await provider.createSale(saleData);
    if (mounted) Navigator.pop(context);

    if (result['success'] == true) {
      final resultData = result['data'] as Map<String, dynamic>;
      final invoiceNumber = resultData['invoice_number'] ?? 'N/A';

      // ✅ Build items list with proper data
      final items = _cartItems.map((item) {
        final total = _selectedSaleType == SaleType.sarya
            ? item.weight * item.unitPrice
            : item.quantity * item.unitPrice;

        return {
          'product_name': item.product.itemName,
          'description': item.description ?? '',
          'quantity': _selectedSaleType == SaleType.sarya ? 0 : item.quantity,
          'unit_price': item.unitPrice,
          'selected_lengths': item.selectedLengths,
          'lengths_display': item.lengthsDisplay,
          'weight': item.weight,
          'total': total,
        };
      }).toList();

      try {
        // ✅ Pass previousBalance explicitly
        final pdfData = await SalePdfGenerator.generateSalePdf(
          saleData: {
            'invoice_number': invoiceNumber,
            'reference': _referenceController.text.trim(),
            'sale_category': _selectedSaleType.apiValue,
          },
          customer: _selectedCustomer,
          items: items,
          subtotal: _subtotal,
          discountValue: _discountValue,
          grandTotal: _grandTotal,
          isPosMode: _isPosMode,
          paymentMethod: paymentMethod,
          amountPaid: finalAmountPaid,
          dueDate: isCredit && _creditDueDate != null ? _creditDueDate : _dueDate,
          notes: _buildNotes(paymentMethod, paymentDetails),
          previousBalance: previousBalance, // ✅ Use the stored value
        );

        if (mounted) {
          _clearCart();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  isCredit
                      ? (languageProvider.isEnglish ? 'Credit sale created!' : 'کریڈٹ فروخت بن گئی!')
                      : (languageProvider.isEnglish ? 'Sale completed!' : 'فروخت مکمل ہوگئی!')
              ),
              backgroundColor: isCredit ? const Color(0xFF7C3AED) : const Color(0xFF10B981),
            ),
          );
          _showPrintDialog(pdfData, invoiceNumber);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          _clearCart();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  languageProvider.isEnglish
                      ? 'Sale saved but PDF failed: $e'
                      : 'فروخت محفوظ ہوگئی لیکن PDF ناکام: $e'
              ),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result['message'] ?? (languageProvider.isEnglish ? 'Failed to save sale' : 'فروخت محفوظ کرنے میں ناکامی')
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _buildNotes(String paymentMethod, Map<String, dynamic>? paymentDetails) {
    final List<String> notesParts = [];
    if (_invoiceNoteController.text.trim().isNotEmpty) notesParts.add(_invoiceNoteController.text.trim());
    if (paymentMethod == 'credit' && paymentDetails != null) {
      if (paymentDetails['notes'] != null && paymentDetails['notes'].toString().trim().isNotEmpty) notesParts.add('Credit Note: ${paymentDetails['notes']}');
      if (paymentDetails['due_date'] != null) notesParts.add('Due Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(paymentDetails['due_date']))}');
    }
    return notesParts.isNotEmpty ? notesParts.join('\n') : '';
  }

  String _formatDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// ═════════════════════════════════════════════════════════════════
//  CUSTOMER PICKER SHEET
// ═════════════════════════════════════════════════════════════════

class _CustomerPickerSheet extends StatefulWidget {
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelected;
  final VoidCallback onAddNew;

  const _CustomerPickerSheet({required this.selectedCustomer, required this.onSelected, required this.onAddNew});

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
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      await provider.fetchCustomers(search: query);
      if (mounted) setState(() => _filtered = provider.customers);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

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
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2))),
                Row(
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Select Customer' : 'کسٹمر منتخب کریں',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onAddNew,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        languageProvider.isEnglish ? 'New' : 'نیا',
                      ),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    hintText: languageProvider.isEnglish ? 'Search customers…' : 'کسٹمرز تلاش کریں…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                ? Center(
              child: Text(
                languageProvider.isEnglish ? 'No customers found' : 'کوئی کسٹمر نہیں ملا',
                style: const TextStyle(color: Color(0xFF9CA3AF)),
              ),
            )
                : ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final c = _filtered[i];
                final sel = widget.selectedCustomer?.id == c.id;
                final hasPositiveBalance = (c.balance ?? 0) > 0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasPositiveBalance ? const Color(0xFFFEF3C7) : const Color(0xFFF3F0FF),
                    child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: TextStyle(color: hasPositiveBalance ? const Color(0xFF92400E) : const Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(
                    c.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: languageProvider.fontFamily),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.contact,
                        style: TextStyle(fontFamily: languageProvider.fontFamily),
                      ),
                      if (c.balance != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, size: 10, color: hasPositiveBalance ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(
                              languageProvider.isEnglish
                                  ? 'Balance: Rs ${c.balance!.toStringAsFixed(2)}'
                                  : 'بقایا: Rs ${c.balance!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: hasPositiveBalance ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                                fontFamily: languageProvider.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: sel ? const Icon(Icons.check_circle, color: Color(0xFF7C3AED)) : null,
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
//  ADD CUSTOMER DIALOG
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
    _nameCtrl.dispose(); _contactCtrl.dispose(); _addressCtrl.dispose();
    _emailCtrl.dispose(); _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      final discountPercent = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
      final result = await provider.createCustomer(
        name: _nameCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        customerType: _type,
        balance: 0,
        discountPercent: discountPercent,
      );
      if (result['success'] == true && mounted) {
        widget.onCreated(result['data'] as Customer);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                languageProvider.isEnglish ? 'Customer added successfully' : 'کسٹمر کامیابی سے شامل ہوگیا'
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                languageProvider.isEnglish ? 'Error: $e' : 'خرابی: $e'
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.person_add, color: Color(0xFF7C3AED), size: 22),
          const SizedBox(width: 10),
          Text(
            languageProvider.isEnglish ? 'Add New Customer' : 'نیا کسٹمر شامل کریں',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
          ),
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
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Customer Name *' : 'کسٹمر کا نام *',
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return languageProvider.isEnglish ? 'Name required' : 'نام درکار ہے';
                    }
                    if (v.trim().length < 2) {
                      return languageProvider.isEnglish ? 'Min 2 characters' : 'کم از کم 2 حروف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactCtrl,
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Contact Number *' : 'رابطہ نمبر *',
                    prefixIcon: const Icon(Icons.phone),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return languageProvider.isEnglish ? 'Contact required' : 'رابطہ درکار ہے';
                    }
                    if (v.trim().length < 10) {
                      return languageProvider.isEnglish ? 'Enter valid number' : 'درست نمبر درج کریں';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Email Address' : 'ای میل ایڈریس',
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Address' : 'پتہ',
                    prefixIcon: const Icon(Icons.location_on),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _type,
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Customer Type' : 'کسٹمر کی قسم',
                    prefixIcon: const Icon(Icons.category),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'regular',
                      child: Text(languageProvider.isEnglish ? 'Regular Customer' : 'عام کسٹمر'),
                    ),
                    DropdownMenuItem(
                      value: 'retail',
                      child: Text(languageProvider.isEnglish ? 'Retail Customer' : 'خوردہ کسٹمر'),
                    ),
                    DropdownMenuItem(
                      value: 'wholesale',
                      child: Text(languageProvider.isEnglish ? 'Wholesale Customer' : 'تھوک کسٹمر'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _discountCtrl,
                  style: TextStyle(fontFamily: languageProvider.fontFamily),
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Default Discount (%)' : 'ڈیفالٹ ڈسکاؤنٹ (%)',
                    hintText: languageProvider.isEnglish ? 'e.g. 10 for 10% off' : 'مثال: 10 (10% ڈسکاؤنٹ)',
                    prefixIcon: const Icon(Icons.local_offer, color: Color(0xFF7C3AED)),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
            languageProvider.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  PAYMENT DIALOG
// ═════════════════════════════════════════════════════════════════

class _PaymentDialog extends StatefulWidget {
  final double total;
  final String customerName;
  final bool isInvoice;
  final void Function(String method, double amount, Map<String, dynamic>? paymentDetails) onConfirm;

  const _PaymentDialog({required this.total, required this.customerName, this.isInvoice = false, required this.onConfirm});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> with SingleTickerProviderStateMixin {
  String _method = 'credit';
  final TextEditingController _receivedCtrl = TextEditingController();
  DateTime? _creditDueDate;
  final TextEditingController _creditNotesCtrl = TextEditingController();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _methodColors = {
    'cash': Color(0xFF10B981), 'bank': Color(0xFF3B82F6),
    'cheque': Color(0xFFF59E0B), 'slip': Color(0xFF8B5CF6), 'credit': Color(0xFF7C3AED),
  };

  static const _methodIcons = {
    'cash': Icons.payments_outlined, 'bank': Icons.account_balance_outlined,
    'cheque': Icons.receipt_long_outlined, 'slip': Icons.receipt_outlined, 'credit': Icons.credit_card_outlined,
  };

  static const _methodLabels = {
    'cash': 'Cash', 'bank': 'Bank', 'cheque': 'Cheque', 'slip': 'Slip', 'credit': 'Credit',
  };

  @override
  void initState() {
    super.initState();
    _receivedCtrl.text = widget.total.toStringAsFixed(2);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose(); _receivedCtrl.dispose(); _creditNotesCtrl.dispose();
    super.dispose();
  }

  Color get _activeColor => _methodColors[_method] ?? const Color(0xFF10B981);
  double get _received => double.tryParse(_receivedCtrl.text) ?? widget.total;
  double get _change => (_received - widget.total).clamp(0, double.infinity);
  bool get _isValid { if (_method == 'cash') return _received >= widget.total; return true; }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(languageProvider),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfo(languageProvider),
                    const SizedBox(height: 20),
                    _buildMethodSelector(languageProvider),
                    const SizedBox(height: 20),
                    if (_method == 'cash') _buildCashFields(languageProvider),
                    if (_method == 'credit') _buildCreditFields(languageProvider),
                    const SizedBox(height: 24),
                    _buildSubmitButton(languageProvider),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        color: _activeColor.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: _activeColor.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _activeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(_methodIcons[_method], color: _activeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isInvoice
                      ? (languageProvider.isEnglish ? 'Create Invoice' : 'انوائس بنائیں')
                      : (languageProvider.isEnglish ? 'Process Payment' : 'ادائیگی کا عمل'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  languageProvider.isEnglish ? 'Select payment method' : 'ادائیگی کا طریقہ منتخب کریں',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _activeColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _activeColor.withOpacity(0.2))),
      child: Row(
        children: [
          const Icon(Icons.person, color: Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Text(
            'Rs ${widget.total.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _activeColor, fontFamily: languageProvider.fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector(LanguageProvider languageProvider) {
    const methods = ['credit'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.isEnglish ? 'Payment Method *' : 'ادائیگی کا طریقہ *',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: methods.map((method) {
              final selected = _method == method;
              final color = _methodColors[method]!;
              final label = languageProvider.isEnglish
                  ? _methodLabels[method]!
                  : _methodLabels[method] == 'Credit' ? 'کریڈٹ' : _methodLabels[method]!;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _method = method),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.1) : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? color : const Color(0xFFE5E5EA), width: selected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(_methodIcons[method], size: 18, color: selected ? color : const Color(0xFF8E8E93)),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? color : const Color(0xFF8E8E93),
                            fontFamily: languageProvider.fontFamily,
                          ),
                        ),
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

  Widget _buildCashFields(LanguageProvider languageProvider) {
    return Column(
      children: [
        TextField(
          controller: _receivedCtrl,
          style: TextStyle(fontFamily: languageProvider.fontFamily),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: languageProvider.isEnglish ? 'Amount Received' : 'وصول شدہ رقم',
            prefixText: 'Rs ',
            prefixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _activeColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _activeColor, width: 1.5)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_received >= widget.total)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Text(
                  languageProvider.isEnglish ? 'Change' : 'باقی رقم',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                ),
                const Spacer(),
                Text(
                  'Rs ${_change.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCreditFields(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3))),
          child: Text(
            languageProvider.isEnglish
                ? 'No payment collected now. Amount added to customer balance.'
                : 'ابھی کوئی ادائیگی نہیں لی گئی۔ رقم کسٹمر کے بیلنس میں شامل کر دی گئی ہے۔',
            style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _creditDueDate ?? DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _creditDueDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: _creditDueDate != null ? const Color(0xFFF5F3FF) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _creditDueDate != null ? const Color(0xFF7C3AED).withOpacity(0.3) : const Color(0xFFE5E5EA)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 20, color: _creditDueDate != null ? const Color(0xFF7C3AED) : Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _creditDueDate != null
                        ? DateFormat('MMM dd, yyyy').format(_creditDueDate!)
                        : (languageProvider.isEnglish ? 'Set due date (Optional)' : 'آخری تاریخ مقرر کریں (اختیاری)'),
                    style: TextStyle(
                      fontSize: 14,
                      color: _creditDueDate != null ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC),
                      fontFamily: languageProvider.fontFamily,
                    ),
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
          style: TextStyle(fontFamily: languageProvider.fontFamily),
          decoration: InputDecoration(
            labelText: languageProvider.isEnglish ? 'Notes (optional)' : 'نوٹس (اختیاری)',
            hintText: languageProvider.isEnglish ? 'Add any notes about this credit sale...' : 'اس کریڈٹ فروخت کے بارے میں کوئی نوٹ شامل کریں...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(LanguageProvider languageProvider) {
    String buttonText;
    if (_method == 'credit') {
      buttonText = widget.isInvoice
          ? (languageProvider.isEnglish ? 'Create Credit Invoice' : 'کریڈٹ انوائس بنائیں')
          : (languageProvider.isEnglish ? 'Process on Credit' : 'کریڈٹ پر عمل کریں');
    } else {
      buttonText = widget.isInvoice
          ? (languageProvider.isEnglish ? 'Create Invoice' : 'انوائس بنائیں')
          : (languageProvider.isEnglish ? 'Confirm Payment' : 'ادائیگی کی تصدیق کریں');
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isValid ? () => _confirmPayment(languageProvider) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _activeColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            color: _isValid ? Colors.white : Colors.grey.shade600,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: languageProvider.fontFamily,
          ),
        ),
      ),
    );
  }

  void _confirmPayment(LanguageProvider languageProvider) {
    Map<String, dynamic>? paymentDetails;
    switch (_method) {
      case 'cash':
        paymentDetails = {'amount_received': _received, 'change': _change};
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

// ── SaleType enum ────────────────────────────────

enum SaleType {
  sarya,
  filled,
}

extension SaleTypeExtension on SaleType {
  String get displayName {
    switch (this) {
      case SaleType.sarya:
        return 'Sarya';
      case SaleType.filled:
        return 'Filled';
    }
  }

  String get apiValue {
    switch (this) {
      case SaleType.sarya:
        return 'sarya';
      case SaleType.filled:
        return 'filled';
    }
  }
  bool get isSarya => this == SaleType.sarya;

}