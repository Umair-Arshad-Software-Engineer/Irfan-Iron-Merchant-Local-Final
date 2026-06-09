// lib/screens/products/add_edit_product_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/subcategory_provider.dart';
import '../../providers/unit_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/product_model.dart';
import '../providers/lanprovider.dart';
import 'bom_component_selector.dart';
import 'bom_components_list.dart';

// ─────────────────────────────────────────────
// Shared helpers (copied from RegisterItemPage)
// ─────────────────────────────────────────────

double? parseFractionString(String text) {
  if (text.isEmpty) return null;
  try {
    final mixedNumberPattern =
    RegExp(r'^(\d+)\s*([¼½¾⅓⅔⅕⅖⅗⅘⅙⅚⅐⅛⅜⅝⅞⅑⅒])$');
    final mixedMatch = mixedNumberPattern.firstMatch(text);
    if (mixedMatch != null) {
      final wholeNumber = double.parse(mixedMatch.group(1)!);
      const fractionMap = {
        '½': 0.5, '⅓': 0.333, '⅔': 0.667, '¼': 0.25, '¾': 0.75,
        '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8, '⅙': 0.167,
        '⅚': 0.833, '⅐': 0.143, '⅛': 0.125, '⅜': 0.375, '⅝': 0.625,
        '⅞': 0.875, '⅑': 0.111, '⅒': 0.1,
      };
      return wholeNumber + (fractionMap[mixedMatch.group(2)!] ?? 0);
    }
    final fractionPattern = RegExp(r'^(\d+)\s*\/\s*(\d+)$');
    final fractionMatch = fractionPattern.firstMatch(text);
    if (fractionMatch != null) {
      final n = double.parse(fractionMatch.group(1)!);
      final d = double.parse(fractionMatch.group(2)!);
      return d != 0 ? n / d : null;
    }
    final mixedFractionPattern = RegExp(r'^(\d+)\s+(\d+)\s*\/\s*(\d+)$');
    final mfm = mixedFractionPattern.firstMatch(text);
    if (mfm != null) {
      final w = double.parse(mfm.group(1)!);
      final n = double.parse(mfm.group(2)!);
      final d = double.parse(mfm.group(3)!);
      return d != 0 ? w + (n / d) : null;
    }
    return double.tryParse(text);
  } catch (_) {
    return null;
  }
}

class LengthBodyCombination {
  String length;
  String lengthDecimal;
  String? id;

  LengthBodyCombination({
    required this.length,
    required this.lengthDecimal,
    this.id,
  });

  Map<String, dynamic> toMap() => {
    'length': length,
    'lengthDecimal': lengthDecimal,
    if (id != null) 'id': id,
  };

  factory LengthBodyCombination.fromMap(Map<String, dynamic> map) =>
      LengthBodyCombination(
        length: map['length'] ?? '',
        lengthDecimal: map['lengthDecimal'] ?? '',
        id: map['id'],
      );
}

// ─────────────────────────────────────────────
// FractionInputField widget
// ─────────────────────────────────────────────

class FractionInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final double fontSize;
  final double labelFontSize;

  const FractionInputField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.onChanged,
    this.validator,
    this.fontSize = 14.0,
    this.labelFontSize = 14.0,
  }) : super(key: key);

  @override
  State<FractionInputField> createState() => _FractionInputFieldState();
}

class _FractionInputFieldState extends State<FractionInputField> {
  static const Map<String, String> _fractionButtons = {
    '½': '0.5', '⅓': '0.333', '⅔': '0.667', '¼': '0.25', '¾': '0.75',
    '⅕': '0.2', '⅖': '0.4', '⅗': '0.6', '⅘': '0.8', '⅙': '0.167',
    '⅚': '0.833', '⅛': '0.125', '⅜': '0.375', '⅝': '0.625', '⅞': '0.875',
  };

  void _insertFraction(String fraction) {
    final newText = widget.controller.text + fraction;
    widget.controller.text = newText;
    widget.onChanged?.call(newText);
  }

  void _showFractionPopup() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, __) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.isEnglish ? 'Insert fraction' : 'کسر داخل کریں',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fractionButtons.entries.map((e) {
                  return ActionChip(
                    label: Text(e.key,
                        style: TextStyle(fontSize: widget.fontSize * 1.2)),
                    backgroundColor: const Color(0xFFEDE9FB),
                    onPressed: () {
                      Navigator.pop(context);
                      _insertFraction(e.key);
                    },
                    tooltip: '${e.key} = ${e.value}',
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: widget.controller,
              style: TextStyle(fontSize: widget.fontSize, fontFamily: languageProvider.fontFamily),
              validator: widget.validator,
              decoration: InputDecoration(
                labelText: widget.labelText,
                labelStyle: TextStyle(fontSize: widget.labelFontSize, fontFamily: languageProvider.fontFamily),
                hintText: widget.hintText ?? (languageProvider.isEnglish ? 'e.g. 2½ or 2 1/2' : 'مثال: 2½ یا 2 1/2'),
                hintStyle: TextStyle(fontSize: widget.fontSize * 0.9, fontFamily: languageProvider.fontFamily),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calculate),
                  onPressed: _showFractionPopup,
                  tooltip: languageProvider.isEnglish ? 'Insert fraction' : 'کسر داخل کریں',
                ),
              ),
              onChanged: widget.onChanged,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _fractionButtons.entries.map((e) {
                return ActionChip(
                  label: Text(e.key,
                      style: TextStyle(fontSize: widget.fontSize * 1.1)),
                  backgroundColor: const Color(0xFFEDE9FB),
                  onPressed: () => _insertFraction(e.key),
                  tooltip: '${e.key} = ${e.value}',
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Unit widget
// ─────────────────────────────────────────────

class _UnitSearchDialog extends StatefulWidget {
  final List<dynamic> units;
  final String? selectedId;

  const _UnitSearchDialog({required this.units, this.selectedId});

  @override
  State<_UnitSearchDialog> createState() => _UnitSearchDialogState();
}

class _UnitSearchDialogState extends State<_UnitSearchDialog> {
  final _searchController = TextEditingController();
  List<dynamic> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.units;
    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.units
            : widget.units
            .where((u) =>
        u.name.toLowerCase().contains(q) ||
            u.symbol.toLowerCase().contains(q))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.square_foot, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        languageProvider.isEnglish ? 'Select Unit' : 'یونٹ منتخب کریں',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: languageProvider.isEnglish ? 'Search units...' : 'یونٹس تلاش کریں...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF7C3AED)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                        : null,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: _filtered.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    languageProvider.isEnglish ? 'No units found' : 'کوئی یونٹ نہیں ملا',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) {
                    final unit = _filtered[index];
                    final isSelected = unit.id == widget.selectedId;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFFEDE9FB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unit.symbol,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      title: Text(
                        unit.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: const Color(0xFF2D3142),
                          fontFamily: languageProvider.fontFamily,
                        ),
                      ),
                      subtitle: Text(
                        languageProvider.isEnglish
                            ? 'Symbol: ${unit.symbol}'
                            : 'علامت: ${unit.symbol}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                          color: Color(0xFF7C3AED))
                          : null,
                      onTap: () => Navigator.pop(context, unit.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────

class AddEditProductScreen extends StatefulWidget {
  final int? productId;

  const AddEditProductScreen({super.key, this.productId});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _minStockController = TextEditingController();
  final _physicalQtyController = TextEditingController();
  final _lengthController = TextEditingController();

  // Selected values
  String? _selectedSupplierId;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  String? _selectedUnitId;
  bool _isActive = true;
  bool _isLoading = false;

  // Length combinations
  List<LengthBodyCombination> _lengthCombinations = [];

  bool _isBom = false;
  List<BomComponent> _bomComponents = [];


  @override
  void initState() {
    super.initState();
    if (widget.productId == null) {
      _barcodeController.text = _generateBarcode();
    }
    _barcodeController.addListener(() => setState(() {}));
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _barcodeController.dispose();
    _minStockController.dispose();
    _physicalQtyController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────

  String _generateBarcode() {
    final random = Random();
    final barcode = List.generate(8, (_) => random.nextInt(10)).join();
    return barcode;
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final categoryProvider =
      Provider.of<CategoryProvider>(context, listen: false);
      final unitProvider = Provider.of<UnitProvider>(context, listen: false);
      final supplierProvider =
      Provider.of<SupplierProvider>(context, listen: false);

      await Future.wait([
        categoryProvider.loadCategories(),
        unitProvider.loadUnits(),
        supplierProvider.fetchSuppliers(context: context),
      ]);

      if (widget.productId != null) {
        final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
        final result =
        await productProvider.fetchProductById(widget.productId!);
        if (result['success'] && result['data'] != null) {
          _populateForm(result['data'] as ProductModel);
        }
      }
    } catch (e) {
      print(e);
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'Error loading data: $e'
              : 'ڈیٹا لوڈ کرنے میں خرابی: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateForm(ProductModel product) {
    _nameController.text = product.itemName;
    _descriptionController.text = product.description ?? '';
    _costPriceController.text = product.costPrice.toString();
    _salePriceController.text = product.salePrice.toString();
    _barcodeController.text = product.barcode ?? '';
    _minStockController.text = product.minStock.toString();
    _physicalQtyController.text = product.physicalQty.toString();

    setState(() {
      _selectedSupplierId = product.supplierId?.toString();
      _selectedCategoryId = product.categoryId.toString();
      _selectedSubcategoryId = product.subcategoryId?.toString();
      _selectedUnitId = product.unitId.toString();
      _isActive = product.isActive;

      if (product.lengthCombinations != null) {
        _lengthCombinations = product.lengthCombinations!
            .map((e) => LengthBodyCombination(
          length: e.length,
          lengthDecimal: e.lengthDecimal,
          id: e.id,
        ))
            .toList();
      }

      _isBom = product.isBom;
      if (product.bomComponents != null) {
        _bomComponents = product.bomComponents!.map((c) => BomComponent(
          id: c.id,
          productId: c.productId,
          productName: c.productName,
          quantity: c.quantity,
          unit: c.unit,
          costPerUnit: c.costPerUnit,
          totalCost: c.totalCost,
          notes: c.notes,
        )).toList();
      }
    });

    if (product.categoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<SubcategoryProvider>(context, listen: false)
            .fetchSubcategoriesByCategory(
            int.parse(product.categoryId.toString()));
      });
    }
  }

  // ── Length helpers ────────────────────────────

  void _addLength() {
    final text = _lengthController.text.trim();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Please enter a length value'
            : 'براہ کرم لمبائی کی قیمت درج کریں')),
      );
      return;
    }
    setState(() {
      _lengthCombinations.add(LengthBodyCombination(
        length: text,
        lengthDecimal:
        parseFractionString(text)?.toStringAsFixed(4) ?? '',
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      ));
      _lengthController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languageProvider.isEnglish
          ? 'Length added'
          : 'لمبائی شامل کر دی گئی')),
    );
  }

  void _editLength(int index) {
    final combination = _lengthCombinations[index];
    _lengthController.text = combination.length;
    setState(() => _lengthCombinations.removeAt(index));
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(languageProvider.isEnglish
          ? 'Length loaded for editing'
          : 'لمبائی ترمیم کے لیے لوڈ کر دی گئی')),
    );
  }

  void _removeLength(int index) =>
      setState(() => _lengthCombinations.removeAt(index));

  // ── Save ─────────────────────────────────────

  Future<void> _saveProduct() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Please select a category'
            : 'براہ کرم ایک کیٹگری منتخب کریں')),
      );
      return;
    }
    if (_selectedUnitId == null || _selectedUnitId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Please select a unit'
            : 'براہ کرم ایک یونٹ منتخب کریں')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final productData = {
      'item_name': _nameController.text,
      'description': _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      'cost_price': double.parse(_costPriceController.text),
      'sale_price': double.parse(_salePriceController.text),
      'supplier_id': _selectedSupplierId != null
          ? int.tryParse(_selectedSupplierId!)
          : null,
      'category_id': int.parse(_selectedCategoryId!),
      'subcategory_id': _selectedSubcategoryId != null
          ? int.tryParse(_selectedSubcategoryId!)
          : null,
      'unit_id': int.parse(_selectedUnitId!),
      'barcode':
      _barcodeController.text.isEmpty ? null : _barcodeController.text,
      'min_stock': int.parse(_minStockController.text),
      'physical_qty': int.parse(_physicalQtyController.text),
      'length_combinations':
      _lengthCombinations.map((c) => c.toMap()).toList(),
      'has_multiple_lengths': _lengthCombinations.isNotEmpty,
      if (widget.productId != null) 'is_active': _isActive,
      'is_bom': _isBom,
      'bom_components': _isBom
          ? _bomComponents.map((c) => {
        'id': c.id,
        'product_id': c.productId,
        'quantity': c.quantity,
        'unit': c.unit,
        'cost_per_unit': c.costPerUnit,
        'total_cost': c.totalCost,
        'notes': c.notes,
      }).toList()
          : [],
    };

    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      final result = widget.productId != null
          ? await provider.updateProduct(widget.productId!, productData)
          : await provider.createProduct(productData);

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productId != null
                ? (languageProvider.isEnglish ? 'Product updated successfully' : 'پروڈکٹ کامیابی سے اپ ڈیٹ ہو گئی')
                : (languageProvider.isEnglish ? 'Product created successfully' : 'پروڈکٹ کامیابی سے بن گئی')),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(result['error'] ?? (languageProvider.isEnglish ? 'Failed to save product' : 'پروڈکٹ محفوظ کرنے میں ناکامی'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${languageProvider.isEnglish ? 'Error' : 'خرابی'}: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isEditing
                  ? (languageProvider.isEnglish ? 'Edit Product' : 'پروڈکٹ میں ترمیم کریں')
                  : (languageProvider.isEnglish ? 'Add Product' : 'پروڈکٹ شامل کریں'),
              style: const TextStyle(
                  color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : _saveProduct,
                child: Text(
                  languageProvider.isEnglish ? 'Save' : 'محفوظ کریں',
                  style: TextStyle(
                    color: _isLoading ? Colors.grey : const Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfoSection(languageProvider),
                  const SizedBox(height: 20),
                  _buildPricingSection(languageProvider),
                  const SizedBox(height: 20),
                  _buildStockSection(languageProvider),
                  const SizedBox(height: 20),
                  _buildCategorySection(languageProvider),
                  const SizedBox(height: 20),
                  _buildLengthCombinationsSection(languageProvider),
                  const SizedBox(height: 20),
                  _buildAdditionalSection(languageProvider),
                  const SizedBox(height: 20),
                  if (isEditing) _buildStatusSection(languageProvider),
                  _buildBomSection(languageProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Section builders ──────────────────────────

  Widget _buildBasicInfoSection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Basic Information' : 'بنیادی معلومات',
      languageProvider,
      children: [
        FractionInputField(
          controller: _nameController,
          labelText: languageProvider.isEnglish ? 'Product Name *' : 'پروڈکٹ کا نام *',
          hintText: languageProvider.isEnglish ? 'e.g. Pipe 2½" or Rod 3 1/4"' : 'مثال: پائپ 2½" یا راڈ 3 1/4"',
          validator: (value) =>
          (value == null || value.isEmpty)
              ? (languageProvider.isEnglish ? 'Product name is required' : 'پروڈکٹ کا نام ضروری ہے')
              : null,
        ),
        _buildDecimalHint(_nameController.text, languageProvider),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
            hintText: languageProvider.isEnglish ? 'Enter product description' : 'پروڈکٹ کی تفصیل درج کریں',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.description),
          ),
          maxLines: 3,
          style: TextStyle(fontFamily: languageProvider.fontFamily),
        ),
        const SizedBox(height: 16),
        Consumer<SupplierProvider>(
          builder: (context, provider, _) => DropdownButtonFormField<String?>(
            value: _selectedSupplierId,
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish ? 'Supplier' : 'سپلائر',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.business),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  languageProvider.isEnglish
                      ? 'Select Supplier'
                      : 'سپلائر منتخب کریں',
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              ...provider.suppliers.map(
                    (s) => DropdownMenuItem<String?>(
                  value: s.id.toString(),
                  child: Text(
                    s.name,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedSupplierId = v),
            style: TextStyle(
              fontFamily: languageProvider.fontFamily,
              color: Colors.black,
            ),
            dropdownColor: Colors.white,
            iconEnabledColor: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildPricingSection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Pricing Information' : 'قیمت کی معلومات',
      languageProvider,
      children: [
        TextFormField(
          controller: _costPriceController,
          decoration: InputDecoration(
            labelText: languageProvider.isEnglish ? 'Cost Price *' : 'لاگت قیمت *',
            hintText: '0.00',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.number,
          style: TextStyle(fontFamily: languageProvider.fontFamily),
          validator: (v) {
            if (v == null || v.isEmpty) return languageProvider.isEnglish ? 'Cost price is required' : 'لاگت قیمت ضروری ہے';
            if (double.tryParse(v) == null) return languageProvider.isEnglish ? 'Enter a valid number' : 'ایک درست نمبر درج کریں';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _salePriceController,
          decoration: InputDecoration(
            labelText: languageProvider.isEnglish ? 'Sale Price *' : 'فروخت قیمت *',
            hintText: '0.00',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.number,
          style: TextStyle(fontFamily: languageProvider.fontFamily),
          validator: (v) {
            if (v == null || v.isEmpty) return languageProvider.isEnglish ? 'Sale price is required' : 'فروخت قیمت ضروری ہے';
            if (double.tryParse(v) == null) return languageProvider.isEnglish ? 'Enter a valid number' : 'ایک درست نمبر درج کریں';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStockSection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Stock Information' : 'اسٹاک کی معلومات',
      languageProvider,
      children: [
        TextFormField(
          controller: _physicalQtyController,
          decoration: InputDecoration(
            labelText: languageProvider.isEnglish ? 'Physical Quantity *' : 'طبعی مقدار *',
            hintText: '0',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.inventory),
          ),
          keyboardType: TextInputType.number,
          style: TextStyle(fontFamily: languageProvider.fontFamily),
          validator: (v) {
            if (v == null || v.isEmpty) return languageProvider.isEnglish ? 'Quantity is required' : 'مقدار ضروری ہے';
            if (int.tryParse(v) == null) return languageProvider.isEnglish ? 'Enter a valid number' : 'ایک درست نمبر درج کریں';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _minStockController,
          decoration: InputDecoration(
            labelText: languageProvider.isEnglish ? 'Minimum Stock Level *' : 'کم از کم اسٹاک لیول *',
            hintText: '0',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.warning),
          ),
          keyboardType: TextInputType.number,
          style: TextStyle(fontFamily: languageProvider.fontFamily),
          validator: (v) {
            if (v == null || v.isEmpty) return languageProvider.isEnglish ? 'Minimum stock is required' : 'کم از کم اسٹاک ضروری ہے';
            if (int.tryParse(v) == null) return languageProvider.isEnglish ? 'Enter a valid number' : 'ایک درست نمبر درج کریں';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Category Information' : 'کیٹگری کی معلومات',
      languageProvider,
      children: [
        Consumer<CategoryProvider>(
          builder: (context, provider, _) =>
              DropdownButtonFormField<String?>(
                value: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Category *' : 'کیٹگری *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      languageProvider.isEnglish
                          ? 'Select Category'
                          : 'کیٹگری منتخب کریں',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),

                  ...provider.categories.map(
                        (c) => DropdownMenuItem<String?>(
                      value: c.id.toString(),
                      child: Text(
                        c.name,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() {
                    _selectedCategoryId = value;
                    _selectedSubcategoryId = null;
                  });
                  if (value != null) {
                    await Provider.of<SubcategoryProvider>(context, listen: false)
                        .fetchSubcategoriesByCategory(int.parse(value));
                  }
                },
                validator: (v) =>
                (v == null || v.isEmpty)
                    ? (languageProvider.isEnglish ? 'Category is required' : 'کیٹگری ضروری ہے')
                    : null,
                style: TextStyle(fontFamily: languageProvider.fontFamily),
              ),
        ),
        const SizedBox(height: 16),
        Consumer<SubcategoryProvider>(
          builder: (context, provider, _) {
            final subcategoryIds = provider.subcategories
                .map((s) => s.id.toString())
                .toList();
            final safeValue = subcategoryIds.contains(_selectedSubcategoryId)
                ? _selectedSubcategoryId
                : null;

            return DropdownButtonFormField<String?>(
              value: safeValue,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish ? 'Subcategory' : 'ذیلی کیٹگری',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.category),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    languageProvider.isEnglish
                        ? 'Select Subcategory'
                        : 'ذیلی کیٹگری منتخب کریں',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),

                ...provider.subcategories.map(
                      (s) => DropdownMenuItem<String?>(
                    value: s.id.toString(),
                    child: Text(
                      s.name,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedSubcategoryId = v),
              style: TextStyle(fontFamily: languageProvider.fontFamily),
            );
          },
        ),
        const SizedBox(height: 16),
        Consumer<UnitProvider>(
          builder: (context, provider, _) {
            return FormField<String>(
              validator: (v) =>
              (_selectedUnitId == null || _selectedUnitId!.isEmpty)
                  ? (languageProvider.isEnglish ? 'Unit is required' : 'یونٹ ضروری ہے')
                  : null,
              builder: (fieldState) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (ctx) => _UnitSearchDialog(
                          units: provider.units,
                          selectedId: _selectedUnitId,
                        ),
                      );
                      if (result != null) {
                        setState(() => _selectedUnitId = result);
                        fieldState.didChange(result);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Unit *' : 'یونٹ *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.square_foot),
                        errorText: fieldState.errorText,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedUnitId != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() => _selectedUnitId = null);
                                  fieldState.didChange(null);
                                },
                              ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                      child: Text(
                        _selectedUnitId != null
                            ? () {
                          try {
                            final unit = provider.units.firstWhere(
                                  (u) => u.id == _selectedUnitId,
                            );
                            return '${unit.name} (${unit.symbol})';
                          } catch (e) {
                            return languageProvider.isEnglish ? 'Select Unit' : 'یونٹ منتخب کریں';
                          }
                        }()
                            : (languageProvider.isEnglish ? 'Select Unit' : 'یونٹ منتخب کریں'),
                        style: TextStyle(
                          color: _selectedUnitId != null
                              ? const Color(0xFF2D3142)
                              : Colors.grey[600],
                          fontFamily: languageProvider.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLengthCombinationsSection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Length Combinations' : 'لمبائی کے امتزاج',
      languageProvider,
      children: [
        FractionInputField(
          controller: _lengthController,
          labelText: languageProvider.isEnglish ? 'Length' : 'لمبائی',
          hintText: languageProvider.isEnglish ? 'e.g. 3¼ or 3 1/4' : 'مثال: 3¼ یا 3 1/4',
          onChanged: (_) => setState(() {}),
        ),
        _buildDecimalHint(_lengthController.text, languageProvider),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addLength,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(languageProvider.isEnglish ? 'Add Length' : 'لمبائی شامل کریں',
                style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${languageProvider.isEnglish ? 'Added Lengths' : 'شامل کردہ لمبائیاں'} (${_lengthCombinations.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
            ),
            if (_lengthCombinations.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _lengthCombinations.clear()),
                icon: const Icon(Icons.delete_sweep,
                    color: Colors.red, size: 18),
                label: Text(languageProvider.isEnglish ? 'Clear all' : 'سب صاف کریں',
                    style: const TextStyle(color: Colors.red)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
          ],
        ),
        const SizedBox(height: 8),

        _buildLengthList(languageProvider),
      ],
    );
  }

  Widget _buildLengthList(LanguageProvider languageProvider) {
    if (_lengthCombinations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFE0E0E8), style: BorderStyle.solid),
        ),
        child: Text(
          languageProvider.isEnglish ? 'No lengths added yet' : 'ابھی تک کوئی لمبائی شامل نہیں کی گئی',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _lengthCombinations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final c = _lengthCombinations[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E8)),
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FB),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              '${languageProvider.isEnglish ? 'Length' : 'لمبائی'}: ${c.length}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: c.lengthDecimal.isNotEmpty
                ? Text('${languageProvider.isEnglish ? 'Decimal' : 'اعشاریہ'}: ${c.lengthDecimal}',
                style: const TextStyle(fontSize: 12, color: Colors.grey))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit,
                      color: Color(0xFF7C3AED), size: 20),
                  onPressed: () => _editLength(index),
                  tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeLength(index),
                  tooltip: languageProvider.isEnglish ? 'Remove' : 'ہٹائیں',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdditionalSection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Additional Information' : 'اضافی معلومات',
      languageProvider,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: languageProvider.isEnglish ? 'Barcode' : 'بارکوڈ',
                  hintText: languageProvider.isEnglish ? '8-digit barcode' : '8 ہندسوں کا بارکوڈ',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 8,
                style: TextStyle(fontFamily: languageProvider.fontFamily),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (value.length != 8) {
                      return languageProvider.isEnglish
                          ? 'Barcode must be exactly 8 digits'
                          : 'بارکوڈ بالکل 8 ہندسوں کا ہونا چاہیے';
                    }
                    if (int.tryParse(value) == null) {
                      return languageProvider.isEnglish
                          ? 'Barcode must be numeric'
                          : 'بارکوڈ عددی ہونا چاہیے';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _barcodeController.text = _generateBarcode();
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(languageProvider.isEnglish ? 'Generate' : 'بنائیں'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_barcodeController.text.isNotEmpty &&
            _barcodeController.text.length == 8)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 8),
                Text(
                  _barcodeController.text,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Color(0xFF2D3142),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusSection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Status' : 'حالت',
      languageProvider,
      children: [
        SwitchListTile(
          title: Text(languageProvider.isEnglish ? 'Active' : 'فعال'),
          subtitle: Text(languageProvider.isEnglish
              ? 'Product is available for sale'
              : 'پروڈکٹ فروخت کے لیے دستیاب ہے'),
          value: _isActive,
          onChanged: (v) => setState(() => _isActive = v),
          activeColor: const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────

  Widget _buildDecimalHint(String text, LanguageProvider languageProvider) {
    final decimal = parseFractionString(text);
    if (decimal == null || text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FB),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calculate, size: 14, color: Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Text(
            '${languageProvider.isEnglish ? 'Decimal value' : 'اعشاریہ قیمت'} = ${decimal.toStringAsFixed(4)}',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF7C3AED)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, LanguageProvider languageProvider,
      {required List<Widget> children}) {
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
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3142),
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // ── BOM Code ────────────────────────────
  double get _bomTotalCost {
    return _bomComponents.fold(0.0, (sum, c) => sum + c.totalCost);
  }

  void _editBomComponent(BomComponent component) {
    final index = _bomComponents.indexWhere((c) => c.id == component.id);
    if (index != -1) {
      setState(() {
        _bomComponents.removeAt(index);
      });
      _showEditComponentDialog(component);
    }
  }

  void _showEditComponentDialog(BomComponent component) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final quantityController = TextEditingController(
      text: component.quantity.abs().toString(),
    );
    final notesController = TextEditingController(text: component.notes ?? '');
    final wasByproduct = component.quantity < 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں'} ${component.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: wasByproduct ? Colors.orange.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    wasByproduct ? Icons.recycling : Icons.inventory,
                    color: wasByproduct ? Colors.orange : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    wasByproduct
                        ? (languageProvider.isEnglish
                        ? 'Type: Byproduct / Wastage'
                        : 'قسم: ضمنی پیداوار / ضائع')
                        : (languageProvider.isEnglish
                        ? 'Type: Material (Consumable)'
                        : 'قسم: مواد (خرچ ہونے والا)'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: wasByproduct ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: wasByproduct
                    ? (languageProvider.isEnglish
                    ? 'Quantity (wastage/produced)'
                    : 'مقدار (ضائع / پیدا شدہ)')
                    : (languageProvider.isEnglish
                    ? 'Quantity (consumed)'
                    : 'مقدار (استعمال شدہ)'),
                hintText: wasByproduct
                    ? (languageProvider.isEnglish ? 'Positive number only' : 'صرف مثبت نمبر')
                    : (languageProvider.isEnglish ? 'Enter quantity' : 'مقدار درج کریں'),
                border: const OutlineInputBorder(),
                helperText: wasByproduct
                    ? (languageProvider.isEnglish
                    ? 'This will be stored as negative quantity'
                    : 'یہ منفی مقدار کے طور پر محفوظ ہو گا')
                    : (languageProvider.isEnglish
                    ? 'This will be stored as positive quantity'
                    : 'یہ مثبت مقدار کے طور پر محفوظ ہو گا'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish ? 'Notes' : 'نوٹس',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () {
              final newQuantity = double.tryParse(quantityController.text);
              if (newQuantity != null && newQuantity > 0) {
                final finalQuantity = wasByproduct ? -newQuantity : newQuantity;
                final updatedComponent = BomComponent(
                  id: component.id,
                  productId: component.productId,
                  productName: component.productName,
                  quantity: finalQuantity,
                  unit: component.unit,
                  costPerUnit: component.costPerUnit,
                  totalCost: component.costPerUnit * finalQuantity,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );

                setState(() {
                  final index = _bomComponents.indexWhere((c) => c.id == component.id);
                  if (index != -1) {
                    _bomComponents.removeAt(index);
                    _bomComponents.add(updatedComponent);
                  }
                });
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(languageProvider.isEnglish
                      ? 'Please enter a valid positive quantity'
                      : 'براہ کرم ایک درست مثبت مقدار درج کریں')),
                );
              }
            },
            child: Text(languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'),
          ),
        ],
      ),
    );
  }

  Widget _buildBomSection(LanguageProvider languageProvider) {
    return _buildSection(
      languageProvider.isEnglish ? 'Bill of Materials (BOM)' : 'مواد کی فہرست (BOM)',
      languageProvider,
      children: [
        SwitchListTile(
          title: Text(languageProvider.isEnglish ? 'This is a BOM Product' : 'یہ ایک BOM پروڈکٹ ہے'),
          subtitle: Text(languageProvider.isEnglish
              ? 'Product will be assembled from components'
              : 'پروڈکٹ اجزاء سے تیار کی جائے گی'),
          value: _isBom,
          onChanged: (value) {
            setState(() {
              _isBom = value;
              if (!value) {
                _bomComponents.clear();
              }
            });
          },
          activeColor: const Color(0xFF7C3AED),
        ),

        if (_isBom) ...[
          const SizedBox(height: 16),

          BomComponentSelector(
            onComponentAdded: (component) {
              setState(() {
                _bomComponents.add(component);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${languageProvider.isEnglish ? 'Added' : 'شامل کیا گیا'} ${component.productName} ${languageProvider.isEnglish ? 'to BOM' : 'BOM میں'}')),
              );
            },
            existingComponents: _bomComponents,
            excludeProductId: widget.productId,
          ),

          const SizedBox(height: 20),

          BomComponentsList(
            components: _bomComponents,
            onRemove: (index) {
              setState(() {
                final removed = _bomComponents[index];
                _bomComponents.removeAt(index);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${languageProvider.isEnglish ? 'Removed' : 'ہٹا دیا گیا'} ${removed.productName} ${languageProvider.isEnglish ? 'from BOM' : 'BOM سے'}}')),
                );
              });
            },
            onEdit: _editBomComponent,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.isEnglish ? 'Auto-calculate Cost Price' : 'خودکار قیمت کا حساب',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${languageProvider.isEnglish ? 'Set cost price from BOM total' : 'BOM کل سے قیمت مقرر کریں'} (${_bomTotalCost.toStringAsFixed(2)} PKR)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _bomComponents.isEmpty
                      ? null
                      : () {
                    setState(() {
                      _costPriceController.text = _bomTotalCost.toStringAsFixed(2);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(languageProvider.isEnglish
                          ? 'Cost price updated from BOM'
                          : 'BOM سے قیمت اپ ڈیٹ ہو گئی')),
                    );
                  },
                  child: Text(languageProvider.isEnglish ? 'Apply' : 'لاگو کریں'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}