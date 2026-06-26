// lib/screens/purchases/create_receipt_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
import '../providers/lanprovider.dart';
import '../services/purchase_pdf_generator.dart';

class CreateReceiptScreen extends StatefulWidget {
  final int orderId;

  const CreateReceiptScreen({super.key, required this.orderId});

  @override
  State<CreateReceiptScreen> createState() => _CreateReceiptScreenState();
}

class _CreateReceiptScreenState extends State<CreateReceiptScreen> {
  final _notesController = TextEditingController();

  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, TextEditingController> _batchControllers = {};
  final Map<int, DateTime?> _expiryDates = {};
  final Map<int, String?> _quantityErrors = {};
  final Map<int, bool> _itemIncluded = {};

  final List<_ExtraReceiptItem> _extraItems = [];

  DateTime _receiptDate = DateTime.now();
  bool _isLoading = false;

  final _currencyFormat = NumberFormat.currency(symbol: 'Rs ');
  final _dateFormat = DateFormat('MMM dd, yyyy');

  // Web-specific
  final ScrollController _scrollController = ScrollController();
  final FocusNode _shortcutFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrder());
    _setupKeyboardShortcuts();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var c in _quantityControllers.values) c.dispose();
    for (var c in _batchControllers.values) c.dispose();
    for (var e in _extraItems) e.dispose();
    _scrollController.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  void _setupKeyboardShortcuts() {
    // Keyboard shortcuts will be handled by the KeyboardListener widget
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool isCtrl = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;

      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
        _createReceipt();
        return KeyEventResult.handled;
      }
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyP) {
        _printReceiptPreview();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _printReceiptPreview() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final order = Provider.of<PurchaseOrderProvider>(context, listen: false).selectedPurchaseOrder;
    if (order == null) return;

    final items = <Map<String, dynamic>>[];

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
        'product_name': item.product?.itemName ?? (lp.isEnglish ? 'Unknown' : 'نامعلوم'),
        'barcode': item.product?.barcode,
        'quantity': quantity,
        'unit_cost': cost,
        'discount_percent': item.discountPercent,
        'tax_percent': item.taxPercent,
        'line_total': lineTotal,
        'batch_number': (_batchControllers[item.id]?.text.isEmpty ?? true) ? null : _batchControllers[item.id]?.text,
      });
    }

    for (var extra in _extraItems) {
      if (extra.selectedProductId == null) continue;
      final quantity = int.tryParse(extra.quantityController.text);
      if (quantity == null || quantity <= 0) continue;

      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final product = productProvider.products.firstWhere(
            (p) => p.id == extra.selectedProductId,
        orElse: () => ProductModel(
          id: 0,
          itemName: lp.isEnglish ? 'Unknown Product' : 'نامعلوم پروڈکٹ',
          barcode: null,
          categoryId: 0,
          unitId: 0,
          salePrice: 0,
          costPrice: double.tryParse(extra.unitCostController.text) ?? 0,
          physicalQty: 0,
          minStock: 0,
          isActive: true,
          availableQty: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
      final lineTotal = afterDiscount;

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
        SnackBar(content: Text(lp.isEnglish ? 'No items to preview' : 'پیش نظارہ کے لیے کوئی آئٹم نہیں'), backgroundColor: Colors.red),
      );
      return;
    }

    final tempReceipt = PurchaseReceiptModel(
      id: 0,
      receiptNumber: 'REC-PREVIEW-${DateTime.now().millisecondsSinceEpoch}',
      purchaseOrderId: widget.orderId,
      receiptDate: DateTime.now(),
      items: [],
      totalAmount: items.fold(0, (sum, item) => sum + (item['line_total'] as double)),
      notes: _notesController.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: '',
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
        languageProvider: lp,
      );

      if (mounted) Navigator.pop(context);
      _showPrintOptions(pdfData, 'RECEIPT_PREVIEW.pdf', lp);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lp.isEnglish ? 'Error generating PDF' : 'PDF بنانے میں خرابی'}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPrintOptions(Uint8List pdfData, String filename, LanguageProvider lp) {
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
            Text(
              lp.isEnglish ? 'Receipt Options' : 'رسید کے اختیارات',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildPrintOption(
                  icon: Icons.print,
                  label: lp.isEnglish ? 'Print' : 'پرنٹ کریں',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.pop(ctx);
                    PurchasePdfGenerator.printPdf(pdfData);
                  },
                  lp: lp,
                ),
                _buildPrintOption(
                  icon: Icons.share,
                  label: lp.isEnglish ? 'Share' : 'شیئر کریں',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(ctx);
                    PurchasePdfGenerator.sharePdf(pdfData, filename);
                  },
                  lp: lp,
                ),
                _buildPrintOption(
                  icon: Icons.visibility,
                  label: lp.isEnglish ? 'Preview' : 'پیش نظارہ',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPdfPreview(pdfData);
                  },
                  lp: lp,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں'),
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
    required LanguageProvider lp,
  }) {
    return SizedBox(
      width: 100,
      child: GestureDetector(
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
                  fontFamily: lp.fontFamily,
                ),
              ),
            ],
          ),
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
          _itemIncluded[item.id] = true;
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    final isDesktop = screenSize.width >= 1200;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: _buildAppBar(languageProvider, isMobile),
          body: KeyboardListener(
            focusNode: _shortcutFocusNode,
            onKeyEvent: _handleKeyEvent,
            child: Consumer<PurchaseOrderProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  );
                }

                final order = provider.selectedPurchaseOrder;
                if (order == null) {
                  return Center(child: Text(languageProvider.isEnglish ? 'Order not found' : 'آرڈر نہیں ملا'));
                }

                final items = order.items
                    ?.where((i) => i.remainingQuantity > 0)
                    .toList() ??
                    [];

                if (items.isEmpty && _extraItems.isEmpty) {
                  return _buildAllReceivedState(languageProvider);
                }

                return Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.all(
                          isMobile ? 16 : isTablet ? 20 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Two-column layout for desktop
                            if (isDesktop) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        _buildOrderInfoCard(order, languageProvider, isMobile),
                                        const SizedBox(height: 16),
                                        if (items.isNotEmpty) _buildItemsTable(items, languageProvider, isMobile, isTablet),
                                        const SizedBox(height: 16),
                                        _buildExtraItemsSection(languageProvider, isMobile, isTablet),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        _buildReceiptDateCard(languageProvider, isMobile),
                                        const SizedBox(height: 16),
                                        _buildNotesCard(languageProvider, isMobile),
                                        const SizedBox(height: 16),
                                        _buildSummaryCard(order, items, languageProvider),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              _buildOrderInfoCard(order, languageProvider, isMobile),
                              const SizedBox(height: 16),
                              if (items.isNotEmpty) _buildItemsTable(items, languageProvider, isMobile, isTablet),
                              const SizedBox(height: 16),
                              _buildExtraItemsSection(languageProvider, isMobile, isTablet),
                              const SizedBox(height: 16),
                              _buildReceiptDateCard(languageProvider, isMobile),
                              const SizedBox(height: 16),
                              _buildNotesCard(languageProvider, isMobile),
                            ],
                            const SizedBox(height: 24),
                            _buildSubmitButton(languageProvider, isDesktop),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    // Sidebar for desktop - quick actions
                    if (isDesktop) ...[
                      Container(
                        width: 280,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: const Color(0xFFF0F0F5),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.isEnglish ? 'Quick Actions' : 'فوری کارروائیاں',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildQuickActionButton(
                              icon: Icons.add_shopping_cart,
                              label: languageProvider.isEnglish ? 'Add Extra Item' : 'اضافی آئٹم شامل کریں',
                              color: const Color(0xFF7C3AED),
                              onTap: _addExtraItem,
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionButton(
                              icon: Icons.print,
                              label: languageProvider.isEnglish ? 'Print Preview' : 'پرنٹ پیش نظارہ',
                              color: const Color(0xFF10B981),
                              onTap: _printReceiptPreview,
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionButton(
                              icon: Icons.save,
                              label: languageProvider.isEnglish ? 'Save Receipt' : 'رسید محفوظ کریں',
                              color: const Color(0xFF3B82F6),
                              onTap: _createReceipt,
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 20),
                            Text(
                              languageProvider.isEnglish ? 'Summary' : 'خلاصہ',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryLine(
                              languageProvider.isEnglish ? 'PO Items' : 'پی او اشیاء',
                              items.where((i) => _itemIncluded[i.id] ?? true).length.toString(),
                            ),
                            _buildSummaryLine(
                              languageProvider.isEnglish ? 'Extra Items' : 'اضافی اشیاء',
                              _extraItems.length.toString(),
                            ),
                            const SizedBox(height: 20),
                            if (kIsWeb) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '⌨️ ${languageProvider.isEnglish ? 'Keyboard Shortcuts' : 'کی بورڈ شارٹ کٹس'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ctrl+S ${languageProvider.isEnglish ? 'Save' : 'محفوظ کریں'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    Text(
                                      'Ctrl+P ${languageProvider.isEnglish ? 'Print Preview' : 'پرنٹ پیش نظارہ'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isBold ? const Color(0xFF2D3142) : const Color(0xFF6B7280),
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isBold ? const Color(0xFF7C3AED) : const Color(0xFF2D3142),
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ]
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(LanguageProvider lp, bool isMobile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: isMobile ? 0 : 1,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFF1C1C1E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lp.isEnglish ? 'Receive Items' : 'آئٹمز وصول کریں',
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (!isMobile)
            Text(
              lp.isEnglish ? 'Record incoming stock' : 'آنے والا اسٹاک ریکارڈ کریں',
              style: const TextStyle(
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
          tooltip: lp.isEnglish ? 'Print Preview' : 'پرنٹ پیش نظارہ',
        ),
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createReceipt,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(lp.isEnglish ? 'Save' : 'محفوظ کریں'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (isMobile)
          TextButton(
            onPressed: _isLoading ? null : _createReceipt,
            child: Text(
              lp.isEnglish ? 'Save' : 'محفوظ کریں',
              style: TextStyle(
                color: _isLoading ? Colors.grey : const Color(0xFF7C3AED),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSummaryCard(PurchaseOrderModel order, List<PurchaseOrderItemModel> items, LanguageProvider lp) {
    final totalItems = items.where((i) => _itemIncluded[i.id] ?? true).length;
    final extraItemsCount = _extraItems.length;

    double totalAmount = 0;
    for (var item in items) {
      if (!(_itemIncluded[item.id] ?? true)) continue;
      final qty = int.tryParse(_quantityControllers[item.id]?.text ?? '0') ?? 0;
      if (qty <= 0) continue;
      final subtotal = qty * item.unitCost;
      final afterDiscount = subtotal * (1 - item.discountPercent / 100);
      totalAmount += afterDiscount * (1 + item.taxPercent / 100);
    }

    for (var extra in _extraItems) {
      final qty = int.tryParse(extra.quantityController.text) ?? 0;
      if (qty <= 0 || extra.selectedProductId == null) continue;
      final cost = double.tryParse(extra.unitCostController.text) ?? 0;
      final discount = double.tryParse(extra.discountController.text) ?? 0;
      final subtotal = qty * cost;
      totalAmount += subtotal * (1 - discount / 100);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lp.isEnglish ? 'Receipt Summary' : 'رسید کا خلاصہ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4C1D95),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryLine(
            lp.isEnglish ? 'PO Items' : 'پی او اشیاء',
            '$totalItems',
          ),
          _buildSummaryLine(
            lp.isEnglish ? 'Extra Items' : 'اضافی اشیاء',
            '$extraItemsCount',
          ),
          const Divider(),
          _buildSummaryLine(
            lp.isEnglish ? 'Total Amount' : 'کل رقم',
            _currencyFormat.format(totalAmount),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(PurchaseOrderModel order, LanguageProvider lp, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: isMobile
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment, color: Color(0xFF7C3AED), size: 22),
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
                    Text(
                      order.supplier?.name ?? (lp.isEnglish ? 'Unknown Supplier' : 'نامعلوم سپلائر'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      )
          : Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment, color: Color(0xFF7C3AED), size: 22),
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
                  order.supplier?.name ?? (lp.isEnglish ? 'Unknown Supplier' : 'نامعلوم سپلائر'),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
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

  Widget _buildItemsTable(List<PurchaseOrderItemModel> items, LanguageProvider lp, bool isMobile, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Text(
                  lp.isEnglish ? 'Items to Receive' : 'وصول کرنے کے لیے آئٹمز',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length} ${lp.isEnglish ? 'item' : 'آئٹم'}${items.length > 1 ? (lp.isEnglish ? 's' : 'ز') : ''}',
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
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                lp.isEnglish
                    ? 'Toggle the checkbox to include/exclude each item. Set quantity to 0 or uncheck to skip.'
                    : 'ہر آئٹم کو شامل/خارج کرنے کے لیے چیک باکس کو ٹوگل کریں۔ مقدار 0 مقرر کریں یا چھوڑنے کے لیے ان چیک کریں۔',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: lp.fontFamily),
              ),
            ),
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
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lp.isEnglish
                          ? '$overItems item${overItems > 1 ? 's exceed' : ' exceeds'} the remaining quantity. You can still save — this allows over-receiving.'
                          : '$overItems آئٹم باقی مقدار سے زیادہ ہے۔ آپ پھر بھی محفوظ کر سکتے ہیں — یہ زیادہ وصول کرنے کی اجازت دیتا ہے۔',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F7),
              border: Border(
                top: BorderSide(color: Color(0xFFE5E5EA)),
                bottom: BorderSide(color: Color(0xFFE5E5EA)),
              ),
            ),
            child: isMobile
                ? Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  flex: 3,
                  child: Text(
                    lp.isEnglish ? 'PRODUCT' : 'پروڈکٹ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    lp.isEnglish ? 'QTY' : 'مقدار',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  flex: isTablet ? 3 : 4,
                  child: Text(
                    lp.isEnglish ? 'PRODUCT' : 'پروڈکٹ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildHeaderCell(lp.isEnglish ? 'ORDERED' : 'آرڈر شدہ', flex: 2, lp: lp),
                _buildHeaderCell(lp.isEnglish ? 'RECV\'D' : 'موصول شدہ', flex: 2, lp: lp),
                _buildHeaderCell(lp.isEnglish ? 'REM.' : 'باقی', flex: 2, lp: lp),
                _buildHeaderCell(lp.isEnglish ? 'UNIT' : 'یونٹ', flex: 2, lp: lp),
                _buildHeaderCell(lp.isEnglish ? 'QTY NOW' : 'اب مقدار', flex: isTablet ? 2 : 3, alignRight: false, lp: lp),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;
            return Column(
              children: [
                _buildTableRow(item, isLast, lp, isMobile, isTablet),
                if (!isMobile) _buildDetailRow(item, lp),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 2, bool alignRight = true, required LanguageProvider lp}) {
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

  Widget _buildTableRow(PurchaseOrderItemModel item, bool isLast, LanguageProvider lp, bool isMobile, bool isTablet) {
    final isIncluded = _itemIncluded[item.id] ?? true;
    final hasError = _quantityErrors[item.id] != null;

    if (isMobile) {
      return _buildMobileTableRow(item, isIncluded, hasError, lp);
    }

    return Container(
      decoration: BoxDecoration(
        color: isIncluded ? Colors.white : const Color(0xFFFAFAFC),
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isIncluded,
              activeColor: const Color(0xFF7C3AED),
              onChanged: (val) {
                setState(() {
                  _itemIncluded[item.id] = val ?? false;
                  if (val == true) {
                    _quantityControllers[item.id]?.text = item.remainingQuantity.toString();
                    _quantityErrors.remove(item.id);
                  }
                });
              },
            ),
          ),
          Expanded(
            flex: isTablet ? 3 : 4,
            child: Opacity(
              opacity: isIncluded ? 1.0 : 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product?.itemName ?? (lp.isEnglish ? 'Unknown Product' : 'نامعلوم پروڈکٹ'),
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
          Expanded(
            flex: 2,
            child: Text(
              '${item.quantityOrdered}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF3C3C43)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.quantityReceived}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: item.quantityReceived > 0 ? Colors.green[700] : const Color(0xFF8E8E93),
                fontWeight: item.quantityReceived > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
          Expanded(
            flex: isTablet ? 2 : 3,
            child: isIncluded
                ? Column(
              children: [
                Row(
                  children: [
                    _buildQtyButton(
                      icon: Icons.remove,
                      onTap: () => _decrementQty(item),
                      lp: lp,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityControllers[item.id],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hasError ? Colors.red : const Color(0xFF1C1C1E),
                          fontFamily: lp.fontFamily,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: hasError ? Colors.red : const Color(0xFFE5E5EA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: hasError ? Colors.red : const Color(0xFFE5E5EA)),
                          ),
                        ),
                        onChanged: (value) => _validateQty(item, value),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildQtyButton(
                      icon: Icons.add,
                      onTap: () => _incrementQty(item),
                      lp: lp,
                    ),
                  ],
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _quantityErrors[item.id]!,
                      style: const TextStyle(fontSize: 10, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            )
                : Center(
              child: Text(
                lp.isEnglish ? 'Skipped' : 'چھوڑ دیا گیا',
                style: const TextStyle(
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

  Widget _buildMobileTableRow(PurchaseOrderItemModel item, bool isIncluded, bool hasError, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isIncluded ? Colors.white : const Color(0xFFFAFAFC),
        border: const Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isIncluded,
                activeColor: const Color(0xFF7C3AED),
                onChanged: (val) {
                  setState(() {
                    _itemIncluded[item.id] = val ?? false;
                    if (val == true) {
                      _quantityControllers[item.id]?.text = item.remainingQuantity.toString();
                      _quantityErrors.remove(item.id);
                    }
                  });
                },
              ),
              Expanded(
                child: Opacity(
                  opacity: isIncluded ? 1.0 : 0.4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product?.itemName ?? (lp.isEnglish ? 'Unknown Product' : 'نامعلوم پروڈکٹ'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      Row(
                        children: [
                          if (item.product?.barcode != null)
                            Text(
                              item.product!.barcode!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Rem: ${item.remainingQuantity}',
                              style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.product?.unit?.symbol ?? '—',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
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
          if (isIncluded) ...[
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _buildQtyButton(
                          icon: Icons.remove,
                          onTap: () => _decrementQty(item),
                          lp: lp,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityControllers[item.id],
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hasError ? Colors.red : const Color(0xFF1C1C1E),
                              fontFamily: lp.fontFamily,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: hasError ? Colors.red : const Color(0xFFE5E5EA)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: hasError ? Colors.red : const Color(0xFFE5E5EA)),
                              ),
                            ),
                            onChanged: (value) => _validateQty(item, value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildQtyButton(
                          icon: Icons.add,
                          onTap: () => _incrementQty(item),
                          lp: lp,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasError)
                    Expanded(
                      child: Text(
                        _quantityErrors[item.id]!,
                        style: const TextStyle(fontSize: 10, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildBatchExpiryFields(
                  batchController: _batchControllers[item.id]!,
                  expiryDate: _expiryDates[item.id],
                  onExpiryTap: () => _selectExpiryDate(item.id),
                  onExpiryClear: () => setState(() => _expiryDates[item.id] = null),
                  lp: lp,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap, required LanguageProvider lp}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF3C3C43)),
      ),
    );
  }

  Widget _buildDetailRow(PurchaseOrderItemModel item, LanguageProvider lp) {
    final isIncluded = _itemIncluded[item.id] ?? true;
    if (!isIncluded) return const SizedBox.shrink();
    if (!_batchControllers.containsKey(item.id)) return const SizedBox.shrink();

    final enteredQty = double.tryParse(_quantityControllers[item.id]?.text ?? '${item.quantityOrdered}') ?? item.quantityOrdered.toDouble();
    final rawTotal = enteredQty * item.unitCost;
    final afterDiscount = rawTotal * (1 - item.discountPercent / 100);
    final lineTotal = afterDiscount * (1 + item.taxPercent / 100);

    return Container(
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5)))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B).withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
            ),
            child: Row(
              children: [
                _buildCalcChip(
                  label: lp.isEnglish ? 'Qty × Cost' : 'مقدار × لاگت',
                  value: '$enteredQty × ${_currencyFormat.format(item.unitCost)}',
                  color: const Color(0xFF6366F1),
                  lp: lp,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('=', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                _buildCalcChip(
                  label: lp.isEnglish ? 'Subtotal' : 'ذیلی کل',
                  value: _currencyFormat.format(rawTotal),
                  color: Colors.blue,
                  lp: lp,
                ),
                if (item.discountPercent > 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('−', style: TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _buildCalcChip(
                    label: '${lp.isEnglish ? 'Disc' : 'چھوٹ'} ${item.discountPercent.toStringAsFixed(1)}%',
                    value: _currencyFormat.format(rawTotal - afterDiscount),
                    color: Colors.orange,
                    lp: lp,
                  ),
                ],
                if (item.taxPercent > 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('+', style: TextStyle(color: Colors.purple, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _buildCalcChip(
                    label: '${lp.isEnglish ? 'Tax' : 'ٹیکس'} ${item.taxPercent.toStringAsFixed(1)}%',
                    value: _currencyFormat.format(lineTotal - afterDiscount),
                    color: Colors.purple,
                    lp: lp,
                  ),
                ],
                const Spacer(),
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
                      Text(
                        lp.isEnglish ? 'Total' : 'کل',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _currencyFormat.format(lineTotal),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
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
            decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(8)),
            child: _batchControllers.containsKey(item.id)
                ? _buildBatchExpiryFields(
              batchController: _batchControllers[item.id]!,
              expiryDate: _expiryDates[item.id],
              onExpiryTap: () => _selectExpiryDate(item.id),
              onExpiryClear: () => setState(() => _expiryDates[item.id] = null),
              lp: lp,
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
    required LanguageProvider lp,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, color: color.withOpacity(0.8), fontWeight: FontWeight.w600, fontFamily: lp.fontFamily),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, fontFamily: lp.fontFamily),
        ),
      ],
    );
  }

  Widget _buildBatchExpiryFields({
    required TextEditingController batchController,
    required DateTime? expiryDate,
    required VoidCallback onExpiryTap,
    required VoidCallback onExpiryClear,
    required LanguageProvider lp,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lp.isEnglish ? 'Batch Number' : 'بیچ نمبر',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: batchController,
                style: TextStyle(fontSize: 13, fontFamily: lp.fontFamily),
                decoration: InputDecoration(
                  hintText: lp.isEnglish ? 'Optional' : 'اختیاری',
                  hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lp.isEnglish ? 'Expiry Date' : 'ختم ہونے کی تاریخ',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onExpiryTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: expiryDate != null ? const Color(0xFF7C3AED) : const Color(0xFFC7C7CC),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          expiryDate != null ? _dateFormat.format(expiryDate) : (lp.isEnglish ? 'Optional' : 'اختیاری'),
                          style: TextStyle(
                            fontSize: 13,
                            color: expiryDate != null ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC),
                            fontFamily: lp.fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (expiryDate != null)
                        GestureDetector(
                          onTap: onExpiryClear,
                          child: const Icon(Icons.close, size: 13, color: Color(0xFF8E8E93)),
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

  Widget _buildExtraItemsSection(LanguageProvider lp, bool isMobile, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.add_box_outlined, size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lp.isEnglish ? 'Additional Items' : 'اضافی اشیاء',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                      ),
                      if (!isMobile)
                        Text(
                          lp.isEnglish ? 'Add items received that were not in the PO' : 'PO میں شامل نہ ہونے والی موصول شدہ اشیاء شامل کریں',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                        ),
                    ],
                  ),
                ),
                if (_extraItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${_extraItems.length}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          if (_extraItems.isNotEmpty) ...[
            if (!isMobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F7),
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E5EA)),
                    bottom: BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: isTablet ? 3 : 4, child: Text(lp.isEnglish ? 'PRODUCT' : 'پروڈکٹ',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 0.5))),
                    Expanded(flex: 2, child: Text(lp.isEnglish ? 'QTY' : 'مقدار',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 0.5))),
                    Expanded(flex: isTablet ? 2 : 3, child: Text(lp.isEnglish ? 'UNIT COST' : 'فی یونٹ لاگت',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 0.5))),
                    Expanded(flex: 2, child: Text(lp.isEnglish ? 'DISC %' : 'چھوٹ %',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 0.5))),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
            ...List.generate(_extraItems.length, (i) => _buildExtraItemRow(i, lp, isMobile, isTablet)),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _addExtraItem,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 6),
                    Text(
                      lp.isEnglish ? 'Add Extra Item' : 'اضافی آئٹم شامل کریں',
                      style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w600, fontSize: 13),
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

  Widget _buildExtraItemRow(int index, LanguageProvider lp, bool isMobile, bool isTablet) {
    final extra = _extraItems[index];

    if (isMobile) {
      return _buildMobileExtraItemRow(index, extra, lp);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5)))),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isTablet ? 3 : 4,
                child: Consumer<ProductProvider>(
                  builder: (context, productProvider, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: extra.selectedProductId,
                          isExpanded: true,
                          hint: Text(lp.isEnglish ? 'Select product…' : 'پروڈکٹ منتخب کریں…',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2D3142)),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: Text(lp.isEnglish ? 'Select product…' : 'پروڈکٹ منتخب کریں…',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
                            ...productProvider.products.map((p) => DropdownMenuItem<int?>(
                              value: p.id,
                              child: Text(p.itemName,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              extra.selectedProductId = v;
                              if (v != null) {
                                final product = productProvider.products.firstWhere((p) => p.id == v);
                                extra.unitCostController.text = product.costPrice.toString();
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
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _buildQtyButton(
                      icon: Icons.remove,
                      onTap: () {
                        final cur = int.tryParse(extra.quantityController.text) ?? 1;
                        if (cur > 1) setState(() => extra.quantityController.text = (cur - 1).toString());
                      },
                      lp: lp,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: TextField(
                        controller: extra.quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: lp.fontFamily),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 2),
                    _buildQtyButton(
                      icon: Icons.add,
                      onTap: () {
                        final cur = int.tryParse(extra.quantityController.text) ?? 0;
                        setState(() => extra.quantityController.text = (cur + 1).toString());
                      },
                      lp: lp,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: isTablet ? 2 : 3,
                child: TextField(
                  controller: extra.unitCostController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 13, fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: 'Rs ',
                    prefixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: extra.discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 13, fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: '%',
                    suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _removeExtraItem(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(8)),
            child: _buildBatchExpiryFields(
              batchController: extra.batchController,
              expiryDate: extra.expiryDate,
              onExpiryTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: extra.expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => extra.expiryDate = picked);
              },
              onExpiryClear: () => setState(() => extra.expiryDate = null),
              lp: lp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileExtraItemRow(int index, _ExtraReceiptItem extra, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Consumer<ProductProvider>(
                  builder: (context, productProvider, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: extra.selectedProductId,
                          isExpanded: true,
                          hint: Text(lp.isEnglish ? 'Select product…' : 'پروڈکٹ منتخب کریں…',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2D3142)),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: Text(lp.isEnglish ? 'Select product…' : 'پروڈکٹ منتخب کریں…',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
                            ...productProvider.products.map((p) => DropdownMenuItem<int?>(
                              value: p.id,
                              child: Text(p.itemName,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              extra.selectedProductId = v;
                              if (v != null) {
                                final product = productProvider.products.firstWhere((p) => p.id == v);
                                extra.unitCostController.text = product.costPrice.toString();
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFFEF4444)),
                onPressed: () => _removeExtraItem(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMobileField(
                label: lp.isEnglish ? 'Qty' : 'مقدار',
                controller: extra.quantityController,
                width: 60,
                onChanged: (_) => setState(() {}),
                lp: lp,
              ),
              _buildMobileField(
                label: lp.isEnglish ? 'Unit Cost' : 'فی یونٹ لاگت',
                controller: extra.unitCostController,
                width: 80,
                prefix: 'Rs ',
                onChanged: (_) => setState(() {}),
                lp: lp,
              ),
              _buildMobileField(
                label: 'Disc %',
                controller: extra.discountController,
                width: 60,
                onChanged: (_) => setState(() {}),
                lp: lp,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(8)),
            child: _buildBatchExpiryFields(
              batchController: extra.batchController,
              expiryDate: extra.expiryDate,
              onExpiryTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: extra.expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => extra.expiryDate = picked);
              },
              onExpiryClear: () => setState(() => extra.expiryDate = null),
              lp: lp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileField({
    required String label,
    required TextEditingController controller,
    required double width,
    String? prefix,
    void Function(String)? onChanged,
    required LanguageProvider lp,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontFamily: lp.fontFamily,
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 12, fontFamily: lp.fontFamily),
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixText: prefix,
              prefixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
              ),
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

  Widget _buildReceiptDateCard(LanguageProvider lp, bool isMobile) {
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
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Text(
                lp.isEnglish ? 'Receipt Date' : 'رسید کی تاریخ',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
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
                  data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _receiptDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lp.isEnglish ? 'Selected Date' : 'منتخب تاریخ',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateFormat.format(_receiptDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined, size: 18, color: Color(0xFF8E8E93)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(LanguageProvider lp, bool isMobile) {
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
          Row(
            children: [
              const Icon(Icons.notes_outlined, size: 18, color: Color(0xFF8E8E93)),
              const SizedBox(width: 8),
              Text(
                lp.isEnglish ? 'Receipt Notes' : 'رسید کے نوٹس',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
              ),
              const SizedBox(width: 6),
              Text(
                lp.isEnglish ? '(Optional)' : '(اختیاری)',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: isMobile ? 2 : 3,
            style: TextStyle(fontSize: 14, fontFamily: lp.fontFamily),
            decoration: InputDecoration(
              hintText: lp.isEnglish ? 'Add any notes about this receipt...' : 'اس رسید کے بارے میں کوئی نوٹ شامل کریں...',
              hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF5F5F7),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(LanguageProvider lp, bool isDesktop) {
    return isDesktop
        ? const SizedBox.shrink()
        : SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createReceipt,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          disabledBackgroundColor: const Color(0xFF7C3AED).withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              lp.isEnglish ? 'Confirm Receipt' : 'رسید کی تصدیق کریں',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllReceivedState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, size: 64, color: Colors.green),
          ),
          const SizedBox(height: 20),
          Text(
            lp.isEnglish ? 'All Items Received' : 'تمام آئٹمز موصول ہوگئیں',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
          ),
          const SizedBox(height: 8),
          Text(
            lp.isEnglish ? 'This purchase order is fully received.' : 'یہ پرچیز آرڈر مکمل طور پر موصول ہوگیا ہے۔',
            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: lp.fontFamily),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(lp.isEnglish ? 'Close' : 'بند کریں',
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
    );
  }

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
      initialDate: _expiryDates[itemId] ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDates[itemId] = picked);
  }

  Future<void> _createReceipt() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    final invalidErrors = _quantityErrors.values.where((e) => e != null && !e.contains('Exceeds')).toList();
    if (invalidErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix invalid quantities before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final overErrors = _quantityErrors.values.where((e) => e != null && e.contains('Exceeds')).toList();
    if (overErrors.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(lp.isEnglish ? 'Over-Receiving' : 'زیادہ وصول کرنا'),
            ],
          ),
          content: Text(
            lp.isEnglish
                ? '${overErrors.length} item${overErrors.length > 1 ? 's' : ''} exceed${overErrors.length == 1 ? 's' : ''} the remaining quantity. Do you want to continue?'
                : '${overErrors.length} آئٹم باقی مقدار سے زیادہ ہے۔ کیا آپ جاری رکھنا چاہتے ہیں؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lp.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(lp.isEnglish ? 'Yes, Over-Receive' : 'ہاں، زیادہ وصول کریں'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final order = Provider.of<PurchaseOrderProvider>(context, listen: false).selectedPurchaseOrder;
    if (order == null) return;

    final receiptItems = [];
    bool hasItems = false;

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
        'batch_number': (_batchControllers[item.id]?.text.isEmpty ?? true) ? null : _batchControllers[item.id]?.text,
        'expiry_date': _expiryDates[item.id]?.toIso8601String(),
        'notes': null,
      });
    }

    for (var extra in _extraItems) {
      if (extra.selectedProductId == null) continue;
      final quantity = int.tryParse(extra.quantityController.text);
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
          content: Text('Please include at least one item to receive'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<PurchaseReceiptProvider>(context, listen: false);
      final result = await provider.createPurchaseReceipt({
        'purchase_order_id': widget.orderId,
        'receipt_date': DateFormat('yyyy-MM-dd').format(_receiptDate.toLocal()),
        'items': receiptItems,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      });

      if (result['success'] && mounted) {
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
          SnackBar(
            content: Text(lp.isEnglish ? 'Receipt created successfully' : 'رسید کامیابی سے بن گئی'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(result['error'] ?? (lp.isEnglish ? 'Failed to create receipt' : 'رسید بنانے میں ناکامی'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lp.isEnglish ? 'Error' : 'خرابی'}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

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