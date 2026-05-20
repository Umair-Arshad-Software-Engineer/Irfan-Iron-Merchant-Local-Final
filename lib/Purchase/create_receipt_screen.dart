// lib/screens/purchases/create_receipt_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/purchase_receipt_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/purchase_order_model.dart';
import '../models/product_model.dart';
import '../services/purchase_pdf_generator.dart';

class CreateReceiptScreen extends StatefulWidget {
  final int orderId;

  const CreateReceiptScreen({super.key, required this.orderId});

  @override
  State<CreateReceiptScreen> createState() => _CreateReceiptScreenState();
}

class _CreateReceiptScreenState extends State<CreateReceiptScreen> {
  final _notesController = TextEditingController();

  // Per-item controllers keyed by item.id (for PO items)
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, TextEditingController> _batchControllers = {};
  final Map<int, DateTime?> _expiryDates = {};
  final Map<int, String?> _quantityErrors = {};
  // Whether each PO item is included in this receipt
  final Map<int, bool> _itemIncluded = {};

  // Extra items added manually (not from the PO)
  final List<_ExtraReceiptItem> _extraItems = [];

  DateTime _receiptDate = DateTime.now();
  bool _isLoading = false;
  bool _showAddExtra = false;

  final _currencyFormat = NumberFormat.currency(symbol: 'Pkr');
  final _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrder());
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var c in _quantityControllers.values) c.dispose();
    for (var c in _batchControllers.values) c.dispose();
    for (var e in _extraItems) e.dispose();
    super.dispose();
  }

  Future<void> _printReceiptPreview() async {
    final order = Provider.of<PurchaseOrderProvider>(context, listen: false).selectedPurchaseOrder;
    if (order == null) return;

    // Prepare items for PDF
    final items = <Map<String, dynamic>>[];

    // PO items
    for (var item in order.items ?? []) {
      if (item.remainingQuantity <= 0) continue;
      final isIncluded = _itemIncluded[item.id] ?? true;
      if (!isIncluded) continue;

      final controller = _quantityControllers[item.id];
      if (controller == null) continue;
      final quantity = int.tryParse(controller.text);
      if (quantity == null || quantity <= 0) continue;

      final cost = item.unitCost;
      final subtotal = quantity * cost;
      final afterDiscount = subtotal * (1 - item.discountPercent / 100);
      final lineTotal = afterDiscount * (1 + item.taxPercent / 100);

      items.add({
        'product_name': item.product?.itemName ?? 'Unknown',
        'barcode': item.product?.barcode,
        'quantity': quantity,
        'unit_cost': cost,
        'discount_percent': item.discountPercent,
        'tax_percent': item.taxPercent,
        'line_total': lineTotal,
        'batch_number': (_batchControllers[item.id]?.text.isEmpty ?? true) ? null : _batchControllers[item.id]?.text,
      });
    }

    // Extra items
    for (var extra in _extraItems) {
      if (extra.selectedProductId == null) continue;
      final quantity = int.tryParse(extra.quantityController.text);
      if (quantity == null || quantity <= 0) continue;

      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final product = productProvider.products.firstWhere(
            (p) => p.id == extra.selectedProductId,
        orElse: () => ProductModel(
          id: 0,
          itemName: 'Unknown Product',
          barcode: null,
          categoryId: 0,
          unitId: 0,
          salePrice: 0,
          costPrice: double.tryParse(extra.unitCostController.text) ?? 0,
          physicalQty: 0,
          minStock: 0,
          isActive: true,
          availableQty: 0,
          createdAt: DateTime.now(), // Provide current date instead of null
          updatedAt: DateTime.now(), // Provide current date instead of null
          description: null,
          supplierId: null,
          subcategoryId: null,
          supplier: null,
          category: null,
          subcategory: null,
          unit: null,
          customerPrices: null,
        ),
      );

      final cost = double.tryParse(extra.unitCostController.text) ?? 0;
      final discountPercent = double.tryParse(extra.discountController.text) ?? 0;
      final subtotal = quantity * cost;
      final afterDiscount = subtotal * (1 - discountPercent / 100);
      final lineTotal = afterDiscount; // No tax for extra items in this example

      items.add({
        'product_name': product.itemName,
        'barcode': product.barcode,
        'quantity': quantity,
        'unit_cost': cost,
        'discount_percent': discountPercent,
        'tax_percent': 0,
        'line_total': lineTotal,
        'batch_number': extra.batchController.text.isEmpty ? null : extra.batchController.text,
      });
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to preview'), backgroundColor: Colors.red),
      );
      return;
    }

    // Create temporary receipt for preview
    final tempReceipt = PurchaseReceiptModel(
      id: 0,
      receiptNumber: 'REC-PREVIEW-${DateTime.now().millisecondsSinceEpoch}',
      purchaseOrderId: widget.orderId,
      receiptDate: DateTime.now(),
      items: [],
      totalAmount: items.fold(0, (sum, item) => sum + (item['line_total'] as double)),
      notes: _notesController.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(), status: '',
    );

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfData = await PurchasePdfGenerator.generatePurchaseReceiptPdf(
        receipt: tempReceipt,
        order: order,
        items: items,
      );

      if (mounted) Navigator.pop(context);

      _showPrintOptions(pdfData, 'RECEIPT_PREVIEW.pdf');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
      );
    }
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
              'Receipt Options',
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

  Future<void> _loadOrder() async {
    final poProvider = Provider.of<PurchaseOrderProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    await Future.wait([
      poProvider.fetchPurchaseOrderById(widget.orderId),
      productProvider.fetchProducts(),
    ]);

    if (poProvider.selectedPurchaseOrder?.items != null) {
      for (var item in poProvider.selectedPurchaseOrder!.items!) {
        if (item.remainingQuantity > 0) {
          _quantityControllers[item.id] = TextEditingController(
            text: item.remainingQuantity.toString(),
          );
          _batchControllers[item.id] = TextEditingController();
          _itemIncluded[item.id] = true; // included by default
        }
      }
    }
    setState(() {});
  }

  Widget _buildReceiptDateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 18, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text(
                'Receipt Date',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _receiptDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: Color(0xFF7C3AED)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _receiptDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month,
                        size: 18, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Date',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateFormat.format(_receiptDate),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined,
                      size: 18, color: Color(0xFF8E8E93)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: _buildAppBar(),
      body: Consumer<PurchaseOrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
            );
          }

          final order = provider.selectedPurchaseOrder;
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          final items = order.items
              ?.where((i) => i.remainingQuantity > 0)
              .toList() ??
              [];

          if (items.isEmpty && _extraItems.isEmpty) {
            return _buildAllReceivedState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderInfoCard(order),
                const SizedBox(height: 16),
                if (items.isNotEmpty) _buildItemsTable(items),
                const SizedBox(height: 16),
                _buildExtraItemsSection(),
                const SizedBox(height: 16),
                _buildReceiptDateCard(),
                const SizedBox(height: 16),
                _buildNotesCard(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFF1C1C1E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receive Items',
            style: TextStyle(
              color: Color(0xFF1C1C1E),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'Record incoming stock',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
      IconButton(
        icon: const Icon(Icons.print_outlined, color: Color(0xFF7C3AED)),
        onPressed: _printReceiptPreview,
        tooltip: 'Print Preview',
      ),
    ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE5E5EA)),
      ),
    );
  }

  // ─── Order Info Card ───────────────────────────────────────────────────────

  Widget _buildOrderInfoCard(PurchaseOrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
            const Icon(Icons.assignment, color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.poNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.supplier?.name ?? 'Unknown Supplier',
                  style:
                  const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.statusText,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PO Items Table ────────────────────────────────────────────────────────

  Widget _buildItemsTable(List<PurchaseOrderItemModel> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                const Text(
                  'Items to Receive',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length} item${items.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Helper text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Toggle the checkbox to include/exclude each item. Set quantity to 0 or uncheck to skip.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
// Over-quantity warning banner
          Builder(builder: (context) {
            final overItems = _quantityErrors.entries
                .where((e) => e.value?.contains('Exceeds') ?? false)
                .length;
            if (overItems == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$overItems item${overItems > 1 ? 's exceed' : ' exceeds'} the remaining quantity. '
                          'You can still save — this allows over-receiving.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Table Header
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F7),
              border: Border(
                top: BorderSide(color: Color(0xFFE5E5EA)),
                bottom: BorderSide(color: Color(0xFFE5E5EA)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 32), // checkbox col
                const Expanded(
                  flex: 3,
                  child: Text(
                    'PRODUCT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildHeaderCell('ORDERED', flex: 2),
                _buildHeaderCell('RECV\'D', flex: 2),
                _buildHeaderCell('REM.', flex: 2),
                _buildHeaderCell('UNIT', flex: 2),       // ← ADD THIS
                _buildHeaderCell('QTY NOW', flex: 3, alignRight: false),
              ],
            ),
          ),

          // Table Rows
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;
            return Column(
              children: [
                _buildTableRow(item, isLast),
                _buildDetailRow(item),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text,
      {int flex = 2, bool alignRight = true}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableRow(PurchaseOrderItemModel item, bool isLast) {
    final isIncluded = _itemIncluded[item.id] ?? true;
    final hasError = _quantityErrors[item.id] != null;

    return Container(
      decoration: BoxDecoration(
        color: isIncluded ? Colors.white : const Color(0xFFFAFAFC),
        border: isLast
            ? null
            : const Border(
          bottom: BorderSide(color: Color(0xFFF0F0F5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Include checkbox
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isIncluded,
              activeColor: const Color(0xFF7C3AED),
              onChanged: (val) {
                setState(() {
                  _itemIncluded[item.id] = val ?? false;
                  if (val == true) {
                    // Restore to remaining quantity
                    _quantityControllers[item.id]?.text =
                        item.remainingQuantity.toString();
                    _quantityErrors.remove(item.id);
                  }
                });
              },
            ),
          ),

          // Product name
          Expanded(
            flex: 3,
            child: Opacity(
              opacity: isIncluded ? 1.0 : 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product?.itemName ?? 'Unknown Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  if (item.product?.barcode != null)
                    Text(
                      item.product!.barcode!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Ordered
          Expanded(
            flex: 2,
            child: Text(
              '${item.quantityOrdered}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF3C3C43)),
            ),
          ),

          // Received
          Expanded(
            flex: 2,
            child: Text(
              '${item.quantityReceived}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: item.quantityReceived > 0
                    ? Colors.green[700]
                    : const Color(0xFF8E8E93),
                fontWeight: item.quantityReceived > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),

          // Remaining badge
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.remainingQuantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.product?.unit?.symbol ?? '—',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
          ),
          // Qty to receive (editable)
          Expanded(
            flex: 3,
            child: isIncluded
                ? Column(
              children: [
                Row(
                  children: [
                    _buildQtyButton(
                      icon: Icons.remove,
                      onTap: () => _decrementQty(item),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityControllers[item.id],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hasError
                              ? Colors.red
                              : const Color(0xFF1C1C1E),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: hasError
                                  ? Colors.red
                                  : const Color(0xFFE5E5EA),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF7C3AED),
                                width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: hasError
                                  ? Colors.red
                                  : const Color(0xFFE5E5EA),
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            _validateQty(item, value),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildQtyButton(
                      icon: Icons.add,
                      onTap: () => _incrementQty(item),
                    ),
                  ],
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _quantityErrors[item.id]!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            )
                : const Center(
              child: Text(
                'Skipped',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E8E93),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF3C3C43)),
      ),
    );
  }

  Widget _buildDetailRow(PurchaseOrderItemModel item) {
    final isIncluded = _itemIncluded[item.id] ?? true;
    if (!isIncluded) return const SizedBox.shrink();
    // Guard: controllers not yet initialized (still loading)
    if (!_batchControllers.containsKey(item.id)) return const SizedBox.shrink();

    // Use currently entered qty, not the PO ordered qty
    final enteredQty = double.tryParse(
        _quantityControllers[item.id]?.text ?? '${item.quantityOrdered}')
        ?? item.quantityOrdered.toDouble();
    final rawTotal = enteredQty * item.unitCost;
    final afterDiscount = rawTotal * (1 - item.discountPercent / 100);
    final lineTotal = afterDiscount * (1 + item.taxPercent / 100);

    return Container(
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: Column(
        children: [
          // Live calculation row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B).withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
            ),
            child: Row(
              children: [
                // Qty × Cost
                _buildCalcChip(
                  label: 'Qty × Cost',
                  value: '$enteredQty × ${_currencyFormat.format(item.unitCost)}',
                  color: const Color(0xFF6366F1),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('=', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                _buildCalcChip(
                  label: 'Subtotal',
                  value: _currencyFormat.format(rawTotal),
                  color: Colors.blue,
                ),

                if (item.discountPercent > 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('−', style: TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _buildCalcChip(
                    label: 'Disc ${item.discountPercent.toStringAsFixed(1)}%',
                    value: _currencyFormat.format(rawTotal - afterDiscount),
                    color: Colors.orange,
                  ),
                ],

                if (item.taxPercent > 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('+', style: TextStyle(color: Colors.purple, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _buildCalcChip(
                    label: 'Tax ${item.taxPercent.toStringAsFixed(1)}%',
                    value: _currencyFormat.format(lineTotal - afterDiscount),
                    color: Colors.purple,
                  ),
                ],

                const Spacer(),

                // Final total
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(lineTotal),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Batch + expiry fields
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _batchControllers.containsKey(item.id)
                ? _buildBatchExpiryFields(
              batchController: _batchControllers[item.id]!,
              expiryDate: _expiryDates[item.id],
              onExpiryTap: () => _selectExpiryDate(item.id),
              onExpiryClear: () =>
                  setState(() => _expiryDates[item.id] = null),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color.withOpacity(0.8),
                fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: color,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Shared batch + expiry fields widget
  Widget _buildBatchExpiryFields({
    required TextEditingController batchController,
    required DateTime? expiryDate,
    required VoidCallback onExpiryTap,
    required VoidCallback onExpiryClear,
  }) {
    return Row(
      children: [
        // Batch number
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Batch Number',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: batchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Optional',
                  hintStyle: const TextStyle(
                      color: Color(0xFFC7C7CC), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: Color(0xFF7C3AED), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Expiry date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expiry Date',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onExpiryTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border:
                    Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: expiryDate != null
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFC7C7CC),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          expiryDate != null
                              ? _dateFormat.format(expiryDate)
                              : 'Optional',
                          style: TextStyle(
                            fontSize: 13,
                            color: expiryDate != null
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFC7C7CC),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (expiryDate != null)
                        GestureDetector(
                          onTap: onExpiryClear,
                          child: const Icon(Icons.close,
                              size: 13, color: Color(0xFF8E8E93)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Extra Items Section ───────────────────────────────────────────────────

  Widget _buildExtraItemsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.add_box_outlined,
                    size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Items',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      Text(
                        'Add items received that were not in the PO',
                        style:
                        TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                ),
                if (_extraItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_extraItems.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Extra item rows
          if (_extraItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F7),
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E5EA)),
                  bottom: BorderSide(color: Color(0xFFE5E5EA)),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Text('PRODUCT',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8E93),
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 2,
                      child: Text('QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8E93),
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 3,
                      child: Text('UNIT COST',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8E93),
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 2,
                      child: Text('DISC %',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8E93),
                              letterSpacing: 0.5))),
                  const SizedBox(width: 36), // delete col

                ],
              ),
            ),
            ...List.generate(
              _extraItems.length,
                  (i) => _buildExtraItemRow(i),
            ),
          ],

          // Add extra item button
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _addExtraItem,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF7C3AED).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF7C3AED)),
                    SizedBox(width: 6),
                    Text(
                      'Add Extra Item',
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
          ),
        ],
      ),
    );
  }

  Widget _buildExtraItemRow(int index) {
    final extra = _extraItems[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product dropdown
              Expanded(
                flex: 4,
                child: Consumer<ProductProvider>(
                  builder: (context, productProvider, _) {
                    return Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: extra.selectedProductId,
                          isExpanded: true,
                          hint: const Text('Select product…',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2D3142)),
                          icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 16),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Select product…',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey))),
                            ...productProvider.products.map(
                                  (p) => DropdownMenuItem<int?>(
                                value: p.id,
                                child: Text(p.itemName,
                                    style: const TextStyle(
                                        fontSize: 12),
                                    overflow:
                                    TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              extra.selectedProductId = v;
                              if (v != null) {
                                final product = productProvider
                                    .products
                                    .firstWhere((p) => p.id == v);
                                extra.unitCostController.text =
                                    product.costPrice.toString();
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),

              // Qty
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _buildQtyButton(
                      icon: Icons.remove,
                      onTap: () {
                        final cur = int.tryParse(
                            extra.quantityController.text) ??
                            1;
                        if (cur > 1) {
                          setState(() => extra.quantityController
                              .text = (cur - 1).toString());
                        }
                      },
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: TextField(
                        controller: extra.quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFE5E5EA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFE5E5EA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF7C3AED),
                                width: 1.5),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 2),
                    _buildQtyButton(
                      icon: Icons.add,
                      onTap: () {
                        final cur = int.tryParse(
                            extra.quantityController.text) ??
                            0;
                        setState(() => extra.quantityController
                            .text = (cur + 1).toString());
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Unit cost
              // Unit cost
              Expanded(
                flex: 3,
                child: TextField(
                  controller: extra.unitCostController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: 'Pkr ',
                    prefixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),

// Discount %
              Expanded(
                flex: 2,
                child: TextField(
                  controller: extra.discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: '%',
                    suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),

              // Delete button
              const SizedBox(width: 6),

              // Delete button
              SizedBox(
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 30, minHeight: 30),
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _removeExtraItem(index),
                ),
              ),
            ],
          ),

          // Batch + Expiry for extra item
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildBatchExpiryFields(
              batchController: extra.batchController,
              expiryDate: extra.expiryDate,
              onExpiryTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: extra.expiryDate ??
                      DateTime.now()
                          .add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now()
                      .add(const Duration(days: 365 * 5)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                          primary: Color(0xFF7C3AED)),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => extra.expiryDate = picked);
                }
              },
              onExpiryClear: () =>
                  setState(() => extra.expiryDate = null),
            ),
          ),
        ],
      ),
    );
  }

  void _addExtraItem() {
    setState(() {
      _extraItems.add(_ExtraReceiptItem());
    });
  }

  void _removeExtraItem(int index) {
    _extraItems[index].dispose();
    setState(() {
      _extraItems.removeAt(index);
    });
  }

  // ─── Notes Card ────────────────────────────────────────────────────────────

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_outlined,
                  size: 18, color: Color(0xFF8E8E93)),
              SizedBox(width: 8),
              Text(
                'Receipt Notes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(width: 6),
              Text(
                '(Optional)',
                style:
                TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add any notes about this receipt...',
              hintStyle: const TextStyle(
                  color: Color(0xFFC7C7CC), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF7C3AED), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Submit Button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createReceipt,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          disabledBackgroundColor:
          const Color(0xFF7C3AED).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Confirm Receipt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── All Received State ────────────────────────────────────────────────────

  Widget _buildAllReceivedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                size: 64, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text(
            'All Items Received',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This purchase order is fully received.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close',
                style:
                TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ─── Quantity Helpers ──────────────────────────────────────────────────────

  void _incrementQty(PurchaseOrderItemModel item) {
    final controller = _quantityControllers[item.id];
    if (controller == null) return;
    final current = int.tryParse(controller.text) ?? 0;
    controller.text = (current + 1).toString();
    _validateQty(item, controller.text);
  }

  void _decrementQty(PurchaseOrderItemModel item) {
    final controller = _quantityControllers[item.id];
    if (controller == null) return;
    final current = int.tryParse(controller.text) ?? 0;
    if (current > 0) {
      controller.text = (current - 1).toString();
      _validateQty(item, controller.text);
    }
  }

  void _validateQty(PurchaseOrderItemModel item, String value) {
    final qty = int.tryParse(value);
    setState(() {
      if (qty == null || qty < 0) {
        _quantityErrors[item.id] = 'Invalid quantity';
      } else if (qty > item.remainingQuantity) {
        _quantityErrors[item.id] = 'Exceeds remaining (${item.remainingQuantity})';
      } else {
        _quantityErrors.remove(item.id);
      }
    });
  }

  Future<void> _selectExpiryDate(int itemId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDates[itemId] ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
          const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDates[itemId] = picked);
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<void> _createReceipt() async {
    final invalidErrors = _quantityErrors.values
        .where((e) => e != null && !e.contains('Exceeds'))
        .toList();
    if (invalidErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix invalid quantities before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
// Over-quantity is allowed but warn the user
    final overErrors = _quantityErrors.values
        .where((e) => e != null && e.contains('Exceeds'))
        .toList();
    if (overErrors.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Over-Receiving'),
            ],
          ),
          content: Text(
            '${overErrors.length} item${overErrors.length > 1 ? 's' : ''} '
                'exceed${overErrors.length == 1 ? 's' : ''} the remaining quantity. '
                'Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Over-Receive'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final order =
        Provider.of<PurchaseOrderProvider>(context, listen: false)
            .selectedPurchaseOrder;
    if (order == null) return;

    final receiptItems = [];
    bool hasItems = false;

    // ── PO items ──
    for (var item in order.items ?? []) {
      if (item.remainingQuantity <= 0) continue;
      final isIncluded = _itemIncluded[item.id] ?? true;
      if (!isIncluded) continue;

      final controller = _quantityControllers[item.id];
      if (controller == null) continue;
      final quantity = int.tryParse(controller.text);
      if (quantity == null || quantity <= 0) continue;

      hasItems = true;
      receiptItems.add({
        'purchase_order_item_id': item.id,
        'product_id': item.productId,
        'quantity_received': quantity,
        'batch_number':
        (_batchControllers[item.id]?.text.isEmpty ?? true)
            ? null
            : _batchControllers[item.id]?.text,
        'expiry_date': _expiryDates[item.id]?.toIso8601String(),
        'notes': null,
      });
    }

    // ── Extra items ──
    for (var extra in _extraItems) {
      if (extra.selectedProductId == null) continue;
      final quantity =
      int.tryParse(extra.quantityController.text);
      if (quantity == null || quantity <= 0) continue;

      hasItems = true;
      receiptItems.add({
        'purchase_order_item_id': null,
        'product_id': extra.selectedProductId,
        'quantity_received': quantity,
        'unit_cost': double.tryParse(extra.unitCostController.text) ?? 0,
        'discount_percent': double.tryParse(extra.discountController.text) ?? 0,
        'batch_number': extra.batchController.text.isEmpty ? null : extra.batchController.text,
        'expiry_date': extra.expiryDate?.toIso8601String(),
        'notes': null,
      });
    }

    if (!hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Please include at least one item to receive'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider =
      Provider.of<PurchaseReceiptProvider>(context, listen: false);
      final result = await provider.createPurchaseReceipt({
        'purchase_order_id': widget.orderId,
        'receipt_date': DateFormat('yyyy-MM-dd').format(_receiptDate.toLocal()),
        'items': receiptItems,
        'notes': _notesController.text.isEmpty
            ? null
            : _notesController.text,
      });

      if (result['success'] && mounted) {
        // Clear all local state before popping
        for (var c in _quantityControllers.values) c.dispose();
        for (var c in _batchControllers.values) c.dispose();
        _quantityControllers.clear();
        _batchControllers.clear();
        _expiryDates.clear();
        _quantityErrors.clear();
        _itemIncluded.clear();
        for (var e in _extraItems) e.dispose();
        _extraItems.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(
            result['error'] ?? 'Failed to create receipt');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ─── Extra Item Model ──────────────────────────────────────────────────────

class _ExtraReceiptItem {
  int? selectedProductId;
  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController discountController;
  final TextEditingController batchController;
  DateTime? expiryDate;

  _ExtraReceiptItem()
      : quantityController = TextEditingController(text: '1'),
        unitCostController = TextEditingController(text: '0'),
        discountController = TextEditingController(text: '0'),
        batchController = TextEditingController();

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
    discountController.dispose();
    batchController.dispose();
  }
}