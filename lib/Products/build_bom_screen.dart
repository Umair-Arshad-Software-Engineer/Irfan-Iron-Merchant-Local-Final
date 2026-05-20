import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';

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
      _snack('Error loading BOM products: $e', isError: true);
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
      _snack('Could not load component stock: $e', isError: true);
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
      final available = _componentStock[c.productId] ?? 0.0;  // ← use live stock
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
    debugPrint('========== BUILD BOM STARTED ==========');

    // Step 1: Validate form
    debugPrint('Step 1: Validating form...');
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      _snack('Please fill all required fields', isError: true);
      return;
    }
    debugPrint('✅ Form validation passed');

    if (_selected == null) {
      debugPrint('❌ No BOM product selected');
      _snack('Please select a BOM product', isError: true);
      return;
    }
    debugPrint('✅ Selected product: ${_selected!.itemName} (ID: ${_selected!.id})');

    setState(() => _isBuilding = true);

    try {
      // Step 2: Prepare request data
      debugPrint('Step 2: Preparing request data...');
      final qty = _qty;
      final buildDateStr = _buildDate.toIso8601String().substring(0, 10);
      final notes = _notesCtrl.text.isEmpty ? null : _notesCtrl.text;

      debugPrint('  - Quantity: $qty');
      debugPrint('  - Build Date: $buildDateStr');
      debugPrint('  - Notes: ${notes ?? "(empty)"}');
      debugPrint('  - Selected Product ID: ${_selected!.id}');
      debugPrint('  - BOM Components count: ${_selected!.bomComponents?.length ?? 0}');

      // Step 3: Build request body
      final body = jsonEncode({
        'quantity': qty,
        'build_date': buildDateStr,
        'notes': notes,
      });
      debugPrint('Step 3: Request body prepared');
      debugPrint('  Body: $body');

      // Step 4: Build URI
      final uri = Uri.parse('${ApiConfig.baseUrl}/products/bom/${_selected!.id}/build');
      debugPrint('Step 4: Request URI created');
      debugPrint('  URI: $uri');
      debugPrint('  Base URL: ${ApiConfig.baseUrl}');

      // Step 5: Make HTTP request
      debugPrint('Step 5: Sending HTTP POST request...');
      final stopwatch = Stopwatch()..start();
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      stopwatch.stop();
      debugPrint('  Response received in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('  Status Code: ${res.statusCode}');

      // Step 6: Parse response
      debugPrint('Step 6: Parsing response body...');
      debugPrint('  Raw response: ${res.body}');

      final data = jsonDecode(res.body);
      debugPrint('  Parsed data: $data');

      // Step 7: Check success
      debugPrint('Step 7: Checking success flag...');
      if (data['success'] == true) {
        debugPrint('✅ Build successful!');

        // Step 8: Show success message
        final successMsg = 'Built ${_numFormat.format(qty)} × ${_selected!.itemName}  |  '
            'Date: ${_dateFmt.format(_buildDate)}  |  '
            'PKR ${_numFormat.format(_buildAmount)}';
        debugPrint('  Success message: $successMsg');
        _snack(successMsg);

        // Step 9: Reload products
        debugPrint('Step 9: Reloading products to refresh stock...');
        try {
          await Provider.of<ProductProvider>(context, listen: false).fetchProducts(refresh: true);
          debugPrint('✅ Products reloaded successfully');
        } catch (e) {
          debugPrint('⚠️ Error reloading products: $e');
        }

        // Step 10: Reset form
        debugPrint('Step 10: Resetting form...');
        _formKey.currentState?.reset();
        setState(() {
          _selected = null;
          _buildDate = DateTime.now();
          _qtyCtrl.text = '1';
          _notesCtrl.clear();
          _componentStock.clear(); // Clear stock map as well
        });
        debugPrint('✅ Form reset complete');

      } else {
        // Build failed
        final errorMsg = data['message'] ?? 'Build failed';
        debugPrint('❌ Build failed: $errorMsg');
        debugPrint('  Full response data: $data');
        _snack(errorMsg, isError: true);
      }

    } catch (e, stackTrace) {
      // Step: Handle errors
      debugPrint('❌❌❌ EXCEPTION CAUGHT ❌❌❌');
      debugPrint('  Error: $e');
      debugPrint('  Stack trace: $stackTrace');

      // Check for specific error types
      if (e is http.ClientException) {
        debugPrint('  Network error - check internet connection or server availability');
        _snack('Network error: Could not connect to server. Check your connection.', isError: true);
      } else if (e is FormatException) {
        debugPrint('  JSON parsing error - unexpected response format');
        _snack('Server response format error. Please contact support.', isError: true);
      } else {
        _snack('Error: $e', isError: true);
      }
    } finally {
      debugPrint('Step final: Cleaning up - setting _isBuilding = false');
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Build BOM',
            style: TextStyle(
                color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: (_isBuilding || !_canBuild) ? null : _buildBom,
            child: Text(
              'Build',
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
              _buildSelectorSection(),
              const SizedBox(height: 20),
              _buildQtyDateSection(),
              const SizedBox(height: 20),
              if (_selected != null) ...[
                _buildSummaryCard(),
                const SizedBox(height: 20),
                _buildComponentsSection(),
                const SizedBox(height: 20),
              ],
              _buildNotesSection(),
              const SizedBox(height: 32),
              _buildButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section widgets ──────────────────────────────────────────────

  Widget _buildSelectorSection() {
    return _card(
      'Select BOM Product',
      child: DropdownButtonFormField<ProductModel>(
        value: _selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'BOM Product *',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.inventory_2),
        ),
        items: _bomProducts.map((p) {
          return DropdownMenuItem<ProductModel>(
            value: p,
            child: Text(
              '${p.itemName}  •  PKR ${_numFormat.format(p.salePrice)}/${p.unit?.symbol ?? 'unit'}',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (v) {
          setState(() {
            _selected = v;
          });
          // Add this line to fetch stock when product is selected
          if (v != null) {
            _fetchComponentStock(v);
          }
        },
        validator: (v) => v == null ? 'Please select a BOM product' : null,
      ),
    );
  }

  Widget _buildQtyDateSection() {
    return _card(
      'Build Details',
      child: Column(
        children: [
          TextFormField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantity to Build *',
              hintText: '1',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.add_box),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Quantity is required';
              final d = double.tryParse(v);
              if (d == null || d <= 0) return 'Enter a valid quantity';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Date picker row
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Build Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_dateFmt.format(_buildDate),
                        style: const TextStyle(fontSize: 15)),
                  ),
                  if (_isSameDay(_buildDate, DateTime.now()))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Today',
                          style: TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
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

  Widget _buildSummaryCard() {
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
          const Text('Build Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 12),
          _summaryRow('Build Date', _dateFmt.format(_buildDate)),
          _summaryRow('Sale Rate / unit',
              'PKR ${_numFormat.format(_selected!.salePrice)}'),
          _summaryRow('BOM Cost / unit',
              'PKR ${_numFormat.format(_selected!.bomTotalCost ?? 0)}'),
          _summaryRow('Quantity', _numFormat.format(_qty)),
          const Divider(color: Colors.white38, height: 20),
          _summaryRow('Total Build Amount',
              'PKR ${_numFormat.format(_buildAmount)}',
              bold: true, fontSize: 16),
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

  Widget _buildComponentsSection() {
    final checks = _componentChecks;
    final allOk  = checks.every((c) => c.hasEnough);

    return _card(
      'Required Components',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: allOk
              ? const Color(0xFF10B981).withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          allOk ? 'All available' : 'Insufficient stock',
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
                        '${_numFormat.format(c.needed)} ${c.unit} needed',
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
                      'Available',
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

  Widget _buildNotesSection() {
    return _card(
      'Notes (optional)',
      child: TextFormField(
        controller: _notesCtrl,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'Any notes about this build...',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.notes),
        ),
      ),
    );
  }

  Widget _buildButton() {
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
          _isBuilding ? 'Building...' : 'Build Item',
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

  Widget _card(String title,
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
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142))),
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
