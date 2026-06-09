import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../providers/lanprovider.dart';

class BuildBomScreen extends StatefulWidget {
  const BuildBomScreen({super.key});

  @override
  State<BuildBomScreen> createState() => _BuildBomScreenState();
}

class _BuildBomScreenState extends State<BuildBomScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _qtyCtrl    = TextEditingController(text: '1');
  final _notesCtrl  = TextEditingController();
  final _numFormat  = NumberFormat('#,##0.00');
  final _dateFmt    = DateFormat('dd MMM yyyy');

  List<ProductModel> _bomProducts = [];
  ProductModel?      _selected;
  DateTime           _buildDate = DateTime.now();
  bool               _isLoading = true;
  bool               _isBuilding = false;

  Map<int, double> _componentStock = {};
  bool _loadingStock = false;


  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(() => setState(() {}));
    _fetchBomProducts();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBomProducts() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/products?is_bom=true&limit=200');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final list = (json['data'] as List)
            .map((e) => ProductModel.fromJson(e))
            .where((p) =>
        p.isBom &&
            p.bomComponents != null &&
            p.bomComponents!.isNotEmpty)
            .toList();
        setState(() { _bomProducts = list; _isLoading = false; });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      _snack(languageProvider.isEnglish
          ? 'Error loading BOM products: $e'
          : 'BOM پروڈکٹس لوڈ کرنے میں خرابی: $e',
          isError: true);
    }
  }

  Future<void> _fetchComponentStock(ProductModel product) async {
    if (product.bomComponents == null) return;
    setState(() => _loadingStock = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/products/bom/structure/${product.id}');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final components = data['data']['components'] as List;
        final Map<int, double> stockMap = {};
        for (final comp in components) {
          final productId = comp['product_id'] as int;
          final details = comp['product_details'];
          if (details != null) {
            stockMap[productId] = (details['physical_qty'] as num).toDouble();
          }
        }
        setState(() => _componentStock = stockMap);
      }
    } catch (e) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      _snack(languageProvider.isEnglish
          ? 'Could not load component stock: $e'
          : 'جزو اسٹاک لوڈ نہیں کر سکے: $e',
          isError: true);
    } finally {
      setState(() => _loadingStock = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _buildDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _buildDate = picked);
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;

  double get _buildAmount =>
      _selected == null ? 0 : (_selected!.salePrice) * _qty;

  // Check if all components have enough stock
  List<_ComponentCheck> get _componentChecks {
    if (_selected?.bomComponents == null) return [];
    return _selected!.bomComponents!.map((c) {
      final needed    = c.quantity * _qty;
      final available = _componentStock[c.productId] ?? 0.0;
      return _ComponentCheck(
        name:      c.productName,
        unit:      c.unit,
        needed:    needed,
        available: available,
      );
    }).toList();
  }

  bool get _canBuild =>
      _selected != null &&
          _qty > 0 &&
          _componentChecks.every((c) => c.hasEnough);

  Future<void> _buildBom() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    debugPrint('========== BUILD BOM STARTED ==========');

    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      _snack(languageProvider.isEnglish
          ? 'Please fill all required fields'
          : 'براہ کرم تمام ضروری فیلڈز بھریں',
          isError: true);
      return;
    }
    debugPrint('✅ Form validation passed');

    if (_selected == null) {
      debugPrint('❌ No BOM product selected');
      _snack(languageProvider.isEnglish
          ? 'Please select a BOM product'
          : 'براہ کرم ایک BOM پروڈکٹ منتخب کریں',
          isError: true);
      return;
    }
    debugPrint('✅ Selected product: ${_selected!.itemName} (ID: ${_selected!.id})');

    setState(() => _isBuilding = true);

    try {
      final qty = _qty;
      final buildDateStr = _buildDate.toIso8601String().substring(0, 10);
      final notes = _notesCtrl.text.isEmpty ? null : _notesCtrl.text;

      debugPrint('  - Quantity: $qty');
      debugPrint('  - Build Date: $buildDateStr');
      debugPrint('  - Notes: ${notes ?? "(empty)"}');

      final body = jsonEncode({
        'quantity': qty,
        'build_date': buildDateStr,
        'notes': notes,
      });

      final uri = Uri.parse('${ApiConfig.baseUrl}/products/bom/${_selected!.id}/build');

      final stopwatch = Stopwatch()..start();
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      stopwatch.stop();
      debugPrint('  Response received in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('  Status Code: ${res.statusCode}');

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        debugPrint('✅ Build successful!');

        final successMsg = languageProvider.isEnglish
            ? 'Built ${_numFormat.format(qty)} × ${_selected!.itemName}  |  Date: ${_dateFmt.format(_buildDate)}  |  PKR ${_numFormat.format(_buildAmount)}'
            : '${_numFormat.format(qty)} × ${_selected!.itemName} تیار کیا گیا  |  تاریخ: ${_dateFmt.format(_buildDate)}  |  PKR ${_numFormat.format(_buildAmount)}';
        _snack(successMsg);

        try {
          await Provider.of<ProductProvider>(context, listen: false).fetchProducts(refresh: true);
          debugPrint('✅ Products reloaded successfully');
        } catch (e) {
          debugPrint('⚠️ Error reloading products: $e');
        }

        _formKey.currentState?.reset();
        setState(() {
          _selected = null;
          _buildDate = DateTime.now();
          _qtyCtrl.text = '1';
          _notesCtrl.clear();
          _componentStock.clear();
        });
        debugPrint('✅ Form reset complete');

      } else {
        final errorMsg = data['message'] ?? (languageProvider.isEnglish ? 'Build failed' : 'تیاری ناکام ہوگئی');
        debugPrint('❌ Build failed: $errorMsg');
        _snack(errorMsg, isError: true);
      }

    } catch (e, stackTrace) {
      debugPrint('❌❌❌ EXCEPTION CAUGHT ❌❌❌');
      debugPrint('  Error: $e');
      debugPrint('  Stack trace: $stackTrace');

      if (e is http.ClientException) {
        _snack(languageProvider.isEnglish
            ? 'Network error: Could not connect to server. Check your connection.'
            : 'نیٹورک خرابی: سرور سے منسلک نہیں ہو سکتا۔ اپنا کنکشن چیک کریں۔',
            isError: true);
      } else if (e is FormatException) {
        _snack(languageProvider.isEnglish
            ? 'Server response format error. Please contact support.'
            : 'سرور ریسپانس فارمیٹ خرابی۔ براہ کرم سپورٹ سے رابطہ کریں۔',
            isError: true);
      } else {
        _snack('${languageProvider.isEnglish ? 'Error' : 'خرابی'}: $e', isError: true);
      }
    } finally {
      setState(() => _isBuilding = false);
      debugPrint('========== BUILD BOM COMPLETED ==========\n');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF7C3AED),
      behavior: SnackBarBehavior.floating,
    ));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Build ────────────────────────────────────────────────────────

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
              icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              languageProvider.isEnglish ? 'Build BOM' : 'BOM تیار کریں',
              style: const TextStyle(
                  color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: (_isBuilding || !_canBuild) ? null : _buildBom,
                child: Text(
                  languageProvider.isEnglish ? 'Build' : 'تیار کریں',
                  style: TextStyle(
                    color: (_isBuilding || !_canBuild)
                        ? Colors.grey
                        : const Color(0xFF7C3AED),
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
                  _buildSelectorSection(languageProvider),
                  const SizedBox(height: 20),
                  _buildQtyDateSection(languageProvider),
                  const SizedBox(height: 20),
                  if (_selected != null) ...[
                    _buildSummaryCard(languageProvider),
                    const SizedBox(height: 20),
                    _buildComponentsSection(languageProvider),
                    const SizedBox(height: 20),
                  ],
                  _buildNotesSection(languageProvider),
                  const SizedBox(height: 32),
                  _buildButton(languageProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Section widgets ──────────────────────────────────────────────

  Widget _buildSelectorSection(LanguageProvider languageProvider) {
    return _card(
      languageProvider.isEnglish ? 'Select BOM Product' : 'BOM پروڈکٹ منتخب کریں',
      languageProvider,
      child: DropdownButtonFormField<ProductModel>(
        value: _selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: languageProvider.isEnglish ? 'BOM Product *' : 'BOM پروڈکٹ *',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.inventory_2),
        ),
        items: _bomProducts.map((p) {
          return DropdownMenuItem<ProductModel>(
            value: p,
            child: Text(
              '${p.itemName}  •  PKR ${_numFormat.format(p.salePrice)}/${p.unit?.symbol ?? (languageProvider.isEnglish ? 'unit' : 'یونٹ')}',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (v) {
          setState(() {
            _selected = v;
          });
          if (v != null) {
            _fetchComponentStock(v);
          }
        },
        validator: (v) => v == null
            ? (languageProvider.isEnglish ? 'Please select a BOM product' : 'براہ کرم ایک BOM پروڈکٹ منتخب کریں')
            : null,
      ),
    );
  }

  Widget _buildQtyDateSection(LanguageProvider languageProvider) {
    return _card(
      languageProvider.isEnglish ? 'Build Details' : 'تیاری کی تفصیلات',
      languageProvider,
      child: Column(
        children: [
          TextFormField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontFamily: languageProvider.fontFamily),
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish ? 'Quantity to Build *' : 'تیار کرنے کی مقدار *',
              hintText: '1',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.add_box),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return languageProvider.isEnglish ? 'Quantity is required' : 'مقدار ضروری ہے';
              }
              final d = double.tryParse(v);
              if (d == null || d <= 0) {
                return languageProvider.isEnglish ? 'Enter a valid quantity' : 'ایک درست مقدار درج کریں';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: languageProvider.isEnglish ? 'Build Date' : 'تیاری کی تاریخ',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_dateFmt.format(_buildDate),
                        style: TextStyle(fontSize: 15, fontFamily: languageProvider.fontFamily)),
                  ),
                  if (_isSameDay(_buildDate, DateTime.now()))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        languageProvider.isEnglish ? 'Today' : 'آج',
                        style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish ? 'Build Summary' : 'تیاری کا خلاصہ',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 12),
          _summaryRow(
              languageProvider.isEnglish ? 'Build Date' : 'تیاری کی تاریخ',
              _dateFmt.format(_buildDate)
          ),
          _summaryRow(
              languageProvider.isEnglish ? 'Sale Rate / unit' : 'فروخت کی شرح / یونٹ',
              'PKR ${_numFormat.format(_selected!.salePrice)}'
          ),
          _summaryRow(
              languageProvider.isEnglish ? 'BOM Cost / unit' : 'BOM لاگت / یونٹ',
              'PKR ${_numFormat.format(_selected!.bomTotalCost ?? 0)}'
          ),
          _summaryRow(
              languageProvider.isEnglish ? 'Quantity' : 'مقدار',
              _numFormat.format(_qty)
          ),
          const Divider(color: Colors.white38, height: 20),
          _summaryRow(
              languageProvider.isEnglish ? 'Total Build Amount' : 'کل تیاری کی رقم',
              'PKR ${_numFormat.format(_buildAmount)}',
              bold: true, fontSize: 16
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white70, fontSize: fontSize)),
          Text(value,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight:
                  bold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildComponentsSection(LanguageProvider languageProvider) {
    final checks = _componentChecks;
    final allOk  = checks.every((c) => c.hasEnough);

    return _card(
      languageProvider.isEnglish ? 'Required Components' : 'مطلوبہ اجزاء',
      languageProvider,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: allOk
              ? const Color(0xFF10B981).withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          allOk
              ? (languageProvider.isEnglish ? 'All available' : 'سب دستیاب')
              : (languageProvider.isEnglish ? 'Insufficient stock' : 'ناکافی اسٹاک'),
          style: TextStyle(
            color: allOk ? const Color(0xFF10B981) : Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Column(
        children: checks.map((c) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.hasEnough
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: c.hasEnough
                    ? const Color(0xFF10B981).withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  c.hasEnough ? Icons.check_circle : Icons.warning,
                  color: c.hasEnough
                      ? const Color(0xFF10B981)
                      : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${_numFormat.format(c.needed)} ${c.unit} ${languageProvider.isEnglish ? 'needed' : 'درکار'}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Available' : 'دستیاب',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[500]),
                    ),
                    Text(
                      _numFormat.format(c.available),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: c.hasEnough
                            ? const Color(0xFF10B981)
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotesSection(LanguageProvider languageProvider) {
    return _card(
      languageProvider.isEnglish ? 'Notes (optional)' : 'نوٹس (اختیاری)',
      languageProvider,
      child: TextFormField(
        controller: _notesCtrl,
        maxLines: 2,
        style: TextStyle(fontFamily: languageProvider.fontFamily),
        decoration: InputDecoration(
          hintText: languageProvider.isEnglish
              ? 'Any notes about this build...'
              : 'اس تیاری کے بارے میں کوئی نوٹس...',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.notes),
        ),
      ),
    );
  }

  Widget _buildButton(LanguageProvider languageProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isBuilding || !_canBuild) ? null : _buildBom,
        icon: _isBuilding
            ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.build, color: Colors.white),
        label: Text(
          _isBuilding
              ? (languageProvider.isEnglish ? 'Building...' : 'تیار ہو رہا ہے...')
              : (languageProvider.isEnglish ? 'Build Item' : 'آئٹم تیار کریں'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _canBuild
              ? const Color(0xFF7C3AED)
              : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── Shared card wrapper ──────────────────────────────────────────

  Widget _card(String title, LanguageProvider languageProvider,
      {required Widget child, Widget? trailing}) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3142),
                      fontFamily: languageProvider.fontFamily)),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Helper class ─────────────────────────────────────────────────────────────

class _ComponentCheck {
  final String name;
  final String unit;
  final double needed;
  final double available;

  _ComponentCheck({
    required this.name,
    required this.unit,
    required this.needed,
    required this.available,
  });

  bool get hasEnough => available >= needed;
}