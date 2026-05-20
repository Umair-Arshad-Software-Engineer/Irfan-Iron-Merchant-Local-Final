// lib/screens/purchases/add_edit_purchase_order_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/purchase_order_model.dart';
import '../services/purchase_pdf_generator.dart';

class AddEditPurchaseOrderScreen extends StatefulWidget {
  final int? orderId;

  const AddEditPurchaseOrderScreen({super.key, this.orderId});

  @override
  State<AddEditPurchaseOrderScreen> createState() =>
      _AddEditPurchaseOrderScreenState();
}

class _AddEditPurchaseOrderScreenState
    extends State<AddEditPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _notesController = TextEditingController();
  final _termsController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _shippingController = TextEditingController(text: '0');

  // Selected values
  int? _selectedSupplierId;
  DateTime? _expectedDeliveryDate;

  // Items
  final List<PurchaseOrderItemRow> _items = [];

  // Barcode search
  final TextEditingController _barcodeSearchController = TextEditingController();
  List<Map<String, dynamic>> _barcodeSearchResults = [];
  bool _isSearchingBarcode = false;

  // Totals
  double _subtotal = 0;
  double _taxAmount = 0;
  double _discountAmount = 0;
  double _shippingCost = 0;
  double _totalAmount = 0;

  bool _isLoading = false;

  final NumberFormat _currency = NumberFormat.currency(symbol: '\$');

  DateTime _orderDate = DateTime.now();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _termsController.dispose();
    _paymentTermsController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    _shippingController.dispose();
    _barcodeSearchController.dispose();
    for (final row in _items) {
      row.dispose();
    }
    super.dispose();
  }


  void _showPrintOptions(Uint8List pdfData, String filename) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Document Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
                      PurchasePdfGenerator.printPdf(pdfData);
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
                      PurchasePdfGenerator.sharePdf(pdfData, filename);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildPrintOption(
                icon: Icons.visibility,
                label: 'Preview',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPdfPreview(pdfData);
                },
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPdfPreview(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (_) => pdfData,
    );
  }


  Future<void> _printPreview() async {
    if (_formKey.currentState!.validate() == false) return;

    final items = _items.where((r) =>
    r.selectedProductId != null &&
        (double.tryParse(r.quantityController.text) ?? 0) > 0
    ).toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    // Prepare items for PDF
    final pdfItems = items.map((r) {
      final qty = double.tryParse(r.quantityController.text) ?? 0;
      final cost = double.tryParse(r.unitCostController.text) ?? 0;
      final discountPercent = double.tryParse(r.discountController.text) ?? 0;
      final taxPercent = double.tryParse(r.taxController.text) ?? 0;

      final subtotal = qty * cost;
      final afterDiscount = subtotal * (1 - discountPercent / 100);
      final lineTotal = afterDiscount * (1 + taxPercent / 100);

      return {
        'product_name': r.productName,
        'quantity': qty,
        'unit_cost': cost,
        'discount_percent': discountPercent,
        'tax_percent': taxPercent,
        'line_total': lineTotal,
      };
    }).toList();

    final tempOrder = PurchaseOrderModel(
      id: 0,
      poNumber: 'PREVIEW-${DateTime.now().millisecondsSinceEpoch}',
      supplierId: _selectedSupplierId!,
      orderDate: _orderDate,
      expectedDeliveryDate: _expectedDeliveryDate,
      deliveryDate: null,
      status: 'draft',
      items: [],
      subtotal: _subtotal,
      taxAmount: _taxAmount,
      discountAmount: _discountAmount,
      shippingCost: _shippingCost,
      totalAmount: _totalAmount,
      notes: _notesController.text,
      paymentTerms: _paymentTermsController.text,
      termsConditions: _termsController.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfData = await PurchasePdfGenerator.generatePurchaseOrderPdf(
        order: tempOrder,
        items: pdfItems,
      );

      if (mounted) Navigator.pop(context);

      _showPrintOptions(pdfData, 'PO_PREVIEW.pdf');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final supplierProvider =
      Provider.of<SupplierProvider>(context, listen: false);
      final productProvider =
      Provider.of<ProductProvider>(context, listen: false);

      await Future.wait([
        supplierProvider.fetchSuppliers(context: context),
        productProvider.fetchProducts(),
      ]);

      if (widget.orderId != null) {
        final poProvider =
        Provider.of<PurchaseOrderProvider>(context, listen: false);
        final result = await poProvider.fetchPurchaseOrderById(widget.orderId!);
        if (result['success'] && result['data'] != null) {
          _populateForm(result['data'] as PurchaseOrderModel);
        }
      } else {
        for (int i = 0; i < 5; i++) {
          _items.add(PurchaseOrderItemRow.empty());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateForm(PurchaseOrderModel order) {
    _selectedSupplierId = order.supplierId;
    _orderDate = order.orderDate;              // ← ADD THIS
    _expectedDeliveryDate = order.expectedDeliveryDate;
    _notesController.text = order.notes ?? '';
    _termsController.text = order.termsConditions ?? '';
    _paymentTermsController.text = order.paymentTerms ?? '';

    // Fix: Parse string values to double correctly
    _taxAmount = double.parse(order.taxAmount?.toString() ?? '0');
    _discountAmount = double.parse(order.discountAmount?.toString() ?? '0');
    _shippingCost = double.parse(order.shippingCost?.toString() ?? '0');

    // Set controller text with proper formatting
    _taxController.text = _taxAmount.toString();
    _discountController.text = _discountAmount.toString();
    _shippingController.text = _shippingCost.toString();

    if (order.items != null) {
      final productProvider =
      Provider.of<ProductProvider>(context, listen: false);
      for (final item in order.items!) {
        final product = productProvider.products
            .where((p) => p.id == item.productId)
            .firstOrNull;
        _items.add(PurchaseOrderItemRow(
          selectedProductId: item.productId,
          productName: item.product?.itemName ?? 'Unknown',
          unitSymbol: product?.unit?.symbol ?? '',   // ← ADD THIS

          quantityController:
          TextEditingController(text: item.quantityOrdered.toString()),
          unitCostController:
          TextEditingController(text: item.unitCost.toString()),
          discountController:
          TextEditingController(text: item.discountPercent.toString()),
          taxController:
          TextEditingController(text: item.taxPercent.toString()),
          notesController: TextEditingController(text: item.notes ?? ''),
        ));
      }
    }
    _recalculate();
  }

  void _recalculate() {
    double sub = 0;
    for (final row in _items) {
      final qty = double.tryParse(row.quantityController.text) ?? 0;
      final cost = double.tryParse(row.unitCostController.text) ?? 0;
      final discountPercent = double.tryParse(row.discountController.text) ?? 0;
      final taxPercent = double.tryParse(row.taxController.text) ?? 0;

      // Calculate line total with discount and tax
      final subtotal = qty * cost;
      final afterDiscount = subtotal * (1 - discountPercent / 100);
      final lineTotal = afterDiscount * (1 + taxPercent / 100);

      sub += lineTotal;
    }

    // Now subtotal represents the sum of all line items after their individual discounts and taxes
    _subtotal = sub;

    // These are order-level charges
    _taxAmount = double.tryParse(_taxController.text) ?? 0;
    _discountAmount = double.tryParse(_discountController.text) ?? 0;
    _shippingCost = double.tryParse(_shippingController.text) ?? 0;

    // Total includes order-level charges
    _totalAmount = _subtotal + _taxAmount + _shippingCost - _discountAmount;

    setState(() {});
  }

  void _addEmptyRow() {
    setState(() {
      _items.add(PurchaseOrderItemRow.empty());
    });
  }

  void _removeRow(int index) {
    _items[index].dispose();
    setState(() {
      _items.removeAt(index);
      _recalculate();
    });
  }

  // Barcode search methods
  Future<void> _searchByBarcode(String barcode) async {
    if (barcode.isEmpty) {
      setState(() {
        _barcodeSearchResults = [];
      });
      return;
    }

    setState(() {
      _isSearchingBarcode = true;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);

      // Search products by barcode
      final results = productProvider.products.where((product) {
        // Check if product has barcode and it matches (case-insensitive partial match)
        return product.barcode != null &&
            product.barcode!.toLowerCase().contains(barcode.toLowerCase());
      }).map((product) => {
        'id': product.id,
        'name': product.itemName,
        'barcode': product.barcode,
        'cost_price': product.costPrice,
        'selling_price': product.salePrice,
      }).toList();

      setState(() {
        _barcodeSearchResults = results;
        _isSearchingBarcode = false;
      });
    } catch (e) {
      setState(() {
        _isSearchingBarcode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching barcode: $e')),
        );
      }
    }
  }

  void _addItemFromBarcode(Map<String, dynamic> product) {
    // Find if there's an empty row or create a new one
    PurchaseOrderItemRow? targetRow;

    // First, try to find an empty row
    for (var row in _items) {
      if (row.selectedProductId == null) {
        targetRow = row;
        break;
      }
    }

    // If no empty row found, create a new one
    if (targetRow == null) {
      targetRow = PurchaseOrderItemRow.empty();
      _items.add(targetRow);
    }

    // Populate the row with product data
    setState(() {
      targetRow!.selectedProductId = product['id'];
      targetRow!.productName = product['name'];
      targetRow!.unitCostController.text = product['cost_price'].toString();

      // Clear barcode search
      _barcodeSearchController.clear();
      _barcodeSearchResults = [];

      _recalculate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.orderId != null;

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
          isEditing ? 'Edit Purchase Order' : 'New Purchase Order',
          style: const TextStyle(
              color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedSupplierId != null && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print_outlined, color: Color(0xFF7C3AED)),
              onPressed: _printPreview,
              tooltip: 'Print Preview',
            ),
          TextButton(
            onPressed: _isLoading ? null : _saveOrder,
            child: Text(
              'Save',
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
              _buildBasicInfoSection(),
              const SizedBox(height: 20),
              _buildBarcodeSearchSection(),
              const SizedBox(height: 20),
              _buildItemsTableSection(),
              const SizedBox(height: 20),
              _buildTotalsSection(),
              const SizedBox(height: 20),
              _buildAdditionalInfoSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Basic Info ────────────────────────────────────────────────────────────

  Widget _buildBasicInfoSection() {
    return _buildCard(
      title: 'Basic Information',
      child: Column(
        children: [
          Consumer<SupplierProvider>(
            builder: (context, provider, _) {
              return DropdownButtonFormField<int?>(
                value: _selectedSupplierId,
                decoration: const InputDecoration(
                  labelText: 'Supplier *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('Select Supplier')),
                  ...provider.suppliers.map((s) =>
                      DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                ],
                // onChanged: (v) => setState(() => _selectedSupplierId = v),
                onChanged: (v) => setState(() {
                  _selectedSupplierId = v;
                  if (v != null) {
                    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
                    final supplier = supplierProvider.suppliers.firstWhere((s) => s.id == v);
                    // Auto-apply supplier's fixed discount to each item
                    for (final row in _items) {
                      row.discountController.text = supplier.discountPercent.toStringAsFixed(2);
                    }
                    _recalculate();
                  }
                }),
                validator: (v) => v == null ? 'Supplier required' : null,
              );
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _orderDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
                  ),
                  child: child!,
                ),
              );
              if (date != null) setState(() => _orderDate = date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Order Date: ${DateFormat('MMM dd, yyyy').format(_orderDate)}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _expectedDeliveryDate ??
                    DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                      colorScheme:
                      const ColorScheme.light(primary: Color(0xFF7C3AED))),
                  child: child!,
                ),
              );
              if (date != null) setState(() => _expectedDeliveryDate = date);
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _expectedDeliveryDate == null
                          ? 'Expected Delivery Date (Optional)'
                          : 'Expected: ${DateFormat('MMM dd, yyyy').format(_expectedDeliveryDate!)}',
                      style: TextStyle(
                        color: _expectedDeliveryDate == null
                            ? Colors.grey[600]
                            : Colors.black87,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Barcode Search Section ────────────────────────────────────────────────

  Widget _buildBarcodeSearchSection() {
    return _buildCard(
      title: 'Quick Add by Barcode',
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeSearchController,
                    decoration: InputDecoration(
                      hintText: 'Scan or enter barcode...',
                      prefixIcon: const Icon(Icons.qr_code_scanner,
                          color: Color(0xFF7C3AED), size: 20),
                      suffixIcon: _isSearchingBarcode
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _barcodeSearchController.clear();
                          setState(() {
                            _barcodeSearchResults = [];
                          });
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: _searchByBarcode,
                  ),
                ),
              ],
            ),
          ),

          // Search results
          if (_barcodeSearchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _barcodeSearchResults.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: Color(0xFFF0F0F5),
                ),
                itemBuilder: (context, index) {
                  final product = _barcodeSearchResults[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.inventory,
                          size: 16, color: Color(0xFF7C3AED)),
                    ),
                    title: Text(
                      product['name'],
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Barcode: ${product['barcode']}  |  Cost: ${_currency.format(product['cost_price'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () => _addItemFromBarcode(product),
                      child: const Text('Add'),
                    ),
                  );
                },
              ),
            ),
          ],

          // Quick tip
          if (_barcodeSearchResults.isEmpty && _barcodeSearchController.text.isNotEmpty && !_isSearchingBarcode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No products found with this barcode. Try scanning again or add manually.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
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

  // ─── Items Table ───────────────────────────────────────────────────────────

  Widget _buildItemsTableSection() {
    return _buildCard(
      title: 'Order Items',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 32), // index col
                _headerCell('Product', flex: 4),
                _headerCell('Qty', flex: 2),
                _headerCell('Unit', flex: 2),           // ← ADD THIS
                _headerCell('Unit Cost', flex: 3),
                _headerCell('Disc %', flex: 2),
                _headerCell('Tax %', flex: 2),
                _headerCell('Line Total', flex: 3),
                const SizedBox(width: 36), // delete col
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Rows
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.table_rows_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No items yet. Click "+ Add Row" to begin.',
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                return Column(
                  children: _items.asMap().entries.map((entry) {
                    return _buildTableRow(
                        entry.key, entry.value, productProvider);
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F5)),
          const SizedBox(height: 12),

          // Add row button
          Row(
            children: [
              GestureDetector(
                onTap: _addEmptyRow,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withOpacity(0.3),
                        style: BorderStyle.solid),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF7C3AED)),
                      SizedBox(width: 6),
                      Text(
                        'Add Row',
                        style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Quick tip for barcode
              Expanded(
                child: Text(
                  '💡 Tip: Use the barcode scanner above to quickly add items',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildTableRow(
      int index, PurchaseOrderItemRow row, ProductProvider productProvider) {
    final qty = double.tryParse(row.quantityController.text) ?? 0;
    final cost = double.tryParse(row.unitCostController.text) ?? 0;
    final discountPercent = double.tryParse(row.discountController.text) ?? 0;
    final taxPercent = double.tryParse(row.taxController.text) ?? 0;

    // Calculate subtotal
    final subtotal = qty * cost;

    // Apply discount
    final afterDiscount = subtotal * (1 - discountPercent / 100);

    // Apply tax
    final lineTotal = afterDiscount * (1 + taxPercent / 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Row number
          SizedBox(
            width: 32,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w600),
            ),
          ),

          // Product dropdown
          Expanded(
            flex: 4,
            child: _buildProductDropdown(row, productProvider),
          ),
          const SizedBox(width: 6),

          // Quantity
          Expanded(
            flex: 2,
            child: _buildCompactField(
              controller: row.quantityController,
              hint: '0',
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalculate(),
            ),
          ),
          const SizedBox(width: 6),
// Unit
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row.unitSymbol.isNotEmpty ? row.unitSymbol : '—',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Unit cost
          Expanded(
            flex: 3,
            child: _buildCompactField(
              controller: row.unitCostController,
              hint: '0.00',
              prefix: '\$',
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalculate(),
            ),
          ),
          const SizedBox(width: 6),

          // Discount %
          Expanded(
            flex: 2,
            child: _buildCompactField(
              controller: row.discountController,
              hint: '0',
              suffix: '%',
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalculate(),
            ),
          ),
          const SizedBox(width: 6),

          // Tax %
          Expanded(
            flex: 2,
            child: _buildCompactField(
              controller: row.taxController,
              hint: '0',
              suffix: '%',
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalculate(),
            ),
          ),
          const SizedBox(width: 6),

          // Line Total (after discount and tax)
          Expanded(
            flex: 3,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _currency.format(lineTotal),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Delete button
          SizedBox(
            width: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(Icons.remove_circle_outline,
                  size: 18, color: Color(0xFFEF4444)),
              onPressed: () => _removeRow(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDropdown(
      PurchaseOrderItemRow row, ProductProvider productProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: row.selectedProductId,
          isExpanded: true,
          hint: const Text('Select…',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF2D3142)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          items: [
            const DropdownMenuItem<int?>(
                value: null,
                child: Text('Select…',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey))),
            ...productProvider.products.map((p) => DropdownMenuItem<int?>(
              value: p.id,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.itemName,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (p.barcode != null && p.barcode!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.qr_code, size: 10, color: Colors.grey[400]),
                    ),
                ],
              ),
            )),
          ],
          onChanged: (v) {
            setState(() {
              row.selectedProductId = v;
              if (v != null) {
                final product =
                productProvider.products.firstWhere((p) => p.id == v);
                row.productName = product.itemName;
                row.unitSymbol = product.unit?.symbol ?? '';   // ← ADD THIS
                row.unitCostController.text =
                    product.costPrice.toString();
                _recalculate();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildCompactField({
    required TextEditingController controller,
    required String hint,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 12),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        suffixText: suffix,
        suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
      ),
    );
  }

  // ─── Totals ────────────────────────────────────────────────────────────────

  Widget _buildTotalsSection() {
    return _buildCard(
      title: 'Order Totals',
      child: Column(
        children: [
          // Editable charges row
          Row(
            children: [
              Expanded(
                child: _buildLabeledField(
                  label: 'Tax Amount (\$)',
                  controller: _taxController,
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledField(
                  label: 'Discount (\$)',
                  controller: _discountController,
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledField(
                  label: 'Shipping (\$)',
                  controller: _shippingController,
                  onChanged: (_) => _recalculate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _totalLine('Subtotal', _subtotal),
                const SizedBox(height: 8),
                _totalLine('Tax', _taxAmount),
                const SizedBox(height: 8),
                _totalLine('Discount', -_discountAmount,
                    color: const Color(0xFFEF4444)),
                const SizedBox(height: 8),
                _totalLine('Shipping', _shippingCost),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFDDD6FE)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED)),
                    ),
                    Text(
                      _currency.format(_totalAmount),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED)),
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

  Widget _totalLine(String label, double amount, {Color? color}) {
    final displayColor = color ??
        (amount < 0 ? const Color(0xFFEF4444) : const Color(0xFF4B5563));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 14, color: const Color(0xFF6B7280))),
        Text(
          amount < 0
              ? '-${_currency.format(amount.abs())}'
              : _currency.format(amount),
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: displayColor),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 13),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle:
            const TextStyle(fontSize: 13, color: Colors.grey),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Additional Info ───────────────────────────────────────────────────────

  Widget _buildAdditionalInfoSection() {
    return _buildCard(
      title: 'Additional Information',
      child: Column(
        children: [
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Any additional notes...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _paymentTermsController,
            decoration: const InputDecoration(
              labelText: 'Payment Terms',
              hintText: 'e.g., Net 30',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsController,
            decoration: const InputDecoration(
              labelText: 'Terms & Conditions',
              hintText: 'Any terms and conditions...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ─── Shared card wrapper ───────────────────────────────────────────────────

  Widget _buildCard({required String title, required Widget child}) {
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
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a supplier')));
      return;
    }

    final validItems = _items
        .where((r) =>
    r.selectedProductId != null &&
        (double.tryParse(r.quantityController.text) ?? 0) > 0)
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item')));
      return;
    }

    setState(() => _isLoading = true);

    final orderData = {
      'supplier_id': _selectedSupplierId,
      'order_date': "${_orderDate.year}-${_orderDate.month.toString().padLeft(2, '0')}-${_orderDate.day.toString().padLeft(2, '0')}",
      'expected_delivery_date': _expectedDeliveryDate == null ? null
          : "${_expectedDeliveryDate!.year}-${_expectedDeliveryDate!.month.toString().padLeft(2, '0')}-${_expectedDeliveryDate!.day.toString().padLeft(2, '0')}",      'items': validItems
          .map((r) => {
        'product_id': r.selectedProductId,
        'quantity_ordered':
        int.tryParse(r.quantityController.text) ?? 1,
        'unit_cost':
        double.tryParse(r.unitCostController.text) ?? 0,
        'discount_percent':
        double.tryParse(r.discountController.text) ?? 0,
        'tax_percent': double.tryParse(r.taxController.text) ?? 0,
        'notes': r.notesController.text.isEmpty
            ? null
            : r.notesController.text,
      })
          .toList(),
      'tax_amount': _taxAmount,
      'discount_amount': _discountAmount,
      'shipping_cost': _shippingCost,
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
      'payment_terms': _paymentTermsController.text.isEmpty
          ? null
          : _paymentTermsController.text,
      'terms_conditions':
      _termsController.text.isEmpty ? null : _termsController.text,
    };

    try {
      final provider =
      Provider.of<PurchaseOrderProvider>(context, listen: false);
      Map<String, dynamic> result;

      if (widget.orderId != null) {
        result = await provider.updateOrderStatus(widget.orderId!, 'draft');
      } else {
        result = await provider.createPurchaseOrder(orderData);
      }

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.orderId != null
              ? 'Order updated successfully'
              : 'Order created successfully'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      } else {
        throw Exception(result['error'] ?? 'Failed to save order');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ─── Row data model ──────────────────────────────────────────────────────────

class PurchaseOrderItemRow {
  int? selectedProductId;
  String productName;
  String unitSymbol;          // ← ADD THIS
  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController discountController;
  final TextEditingController taxController;
  final TextEditingController notesController;

  PurchaseOrderItemRow({
    this.selectedProductId,
    this.productName = '',
    this.unitSymbol = '',      // ← ADD THIS
    required this.quantityController,
    required this.unitCostController,
    required this.discountController,
    required this.taxController,
    required this.notesController,
  });

  factory PurchaseOrderItemRow.empty() => PurchaseOrderItemRow(
    quantityController: TextEditingController(text: '1'),
    unitCostController: TextEditingController(text: '0'),
    discountController: TextEditingController(text: '0'),
    taxController: TextEditingController(text: '0'),
    notesController: TextEditingController(),
    unitSymbol: '',            // ← ADD THIS
  );

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
    discountController.dispose();
    taxController.dispose();
    notesController.dispose();
  }
}