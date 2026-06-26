// lib/screens/purchases/add_edit_purchase_order_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/purchase_order_model.dart';
import '../providers/lanprovider.dart';
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

  final _notesController = TextEditingController();
  final _termsController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _shippingController = TextEditingController(text: '0');

  int? _selectedSupplierId;
  DateTime? _expectedDeliveryDate;

  final List<PurchaseOrderItemRow> _items = [];

  final TextEditingController _barcodeSearchController = TextEditingController();
  List<Map<String, dynamic>> _barcodeSearchResults = [];
  bool _isSearchingBarcode = false;

  double _subtotal = 0;
  double _taxAmount = 0;
  double _discountAmount = 0;
  double _shippingCost = 0;
  double _totalAmount = 0;

  bool _isLoading = false;
  bool _isSaving = false;

  final NumberFormat _currency = NumberFormat.currency(symbol: 'Rs ');

  DateTime _orderDate = DateTime.now();

  // Web-specific controllers for responsive layout
  final ScrollController _scrollController = ScrollController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());

    // Web-specific keyboard shortcuts
    if (kIsWeb) {
      _setupWebShortcuts();
    }
  }

  void _setupWebShortcuts() {
    // Use RawKeyboardListener correctly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // We'll use Focus widget with onKey instead
    });
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
    _barcodeFocusNode.dispose();
    _scrollController.dispose();
    _shortcutFocusNode.dispose();
    for (final row in _items) {
      row.dispose();
    }
    super.dispose();
  }

  void _showPrintOptions(Uint8List pdfData, String filename, LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              lp.isEnglish ? 'Document Options' : 'دستاویز کے اختیارات',
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
                textAlign: TextAlign.center,
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

  Future<void> _printPreview() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    if (_formKey.currentState!.validate() == false) return;

    final items = _items.where((r) =>
    r.selectedProductId != null &&
        (double.tryParse(r.quantityController.text) ?? 0) > 0
    ).toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lp.isEnglish ? 'Please add at least one item' : 'براہ کرم کم از کم ایک آئٹم شامل کریں')),
      );
      return;
    }

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
        languageProvider: lp,
      );

      if (mounted) Navigator.pop(context);

      _showPrintOptions(pdfData, 'PO_PREVIEW.pdf', lp);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lp.isEnglish ? 'Error generating PDF' : 'PDF بنانے میں خرابی'}: $e'), backgroundColor: Colors.red),
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
      final lp = Provider.of<LanguageProvider>(context, listen: false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${lp.isEnglish ? 'Error loading data' : 'ڈیٹا لوڈ کرنے میں خرابی'}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateForm(PurchaseOrderModel order) {
    _selectedSupplierId = order.supplierId;
    _orderDate = order.orderDate;
    _expectedDeliveryDate = order.expectedDeliveryDate;
    _notesController.text = order.notes ?? '';
    _termsController.text = order.termsConditions ?? '';
    _paymentTermsController.text = order.paymentTerms ?? '';

    _taxAmount = double.parse(order.taxAmount?.toString() ?? '0');
    _discountAmount = double.parse(order.discountAmount?.toString() ?? '0');
    _shippingCost = double.parse(order.shippingCost?.toString() ?? '0');

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
          unitSymbol: product?.unit?.symbol ?? '',
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

      final subtotal = qty * cost;
      final afterDiscount = subtotal * (1 - discountPercent / 100);
      final lineTotal = afterDiscount * (1 + taxPercent / 100);

      sub += lineTotal;
    }

    _subtotal = sub;
    _taxAmount = double.tryParse(_taxController.text) ?? 0;
    _discountAmount = double.tryParse(_discountController.text) ?? 0;
    _shippingCost = double.tryParse(_shippingController.text) ?? 0;

    _totalAmount = _subtotal + _taxAmount + _shippingCost - _discountAmount;

    setState(() {});
  }

  void _addEmptyRow() {
    setState(() {
      _items.add(PurchaseOrderItemRow.empty());
      // Scroll to bottom on web
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  void _removeRow(int index) {
    _items[index].dispose();
    setState(() {
      _items.removeAt(index);
      _recalculate();
    });
  }

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

      final results = productProvider.products.where((product) {
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
    PurchaseOrderItemRow? targetRow;

    for (var row in _items) {
      if (row.selectedProductId == null) {
        targetRow = row;
        break;
      }
    }

    if (targetRow == null) {
      targetRow = PurchaseOrderItemRow.empty();
      _items.add(targetRow);
    }

    setState(() {
      targetRow!.selectedProductId = product['id'];
      targetRow!.productName = product['name'];
      targetRow!.unitCostController.text = product['cost_price'].toString();

      _barcodeSearchController.clear();
      _barcodeSearchResults = [];

      _recalculate();
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Check for Ctrl (Windows/Linux) or Cmd (Mac)
      final bool isCtrl = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;

      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
        _saveOrder();
        return KeyEventResult.handled;
      }
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyP) {
        _printPreview();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final isEditing = widget.orderId != null;
        final screenSize = MediaQuery.of(context).size;
        final isMobile = screenSize.width < 600;
        final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
        final isDesktop = screenSize.width >= 1200;

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: kIsWeb ? 1 : 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF2D3142)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isEditing
                  ? (languageProvider.isEnglish ? 'Edit Purchase Order' : 'پرچیز آرڈر میں ترمیم کریں')
                  : (languageProvider.isEnglish ? 'New Purchase Order' : 'نیا پرچیز آرڈر'),
              style: const TextStyle(
                  color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
            ),
            actions: [
              if (_selectedSupplierId != null && _items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: Color(0xFF7C3AED)),
                  onPressed: _printPreview,
                  tooltip: languageProvider.isEnglish ? 'Print Preview' : 'پرنٹ پیش نظارہ',
                ),
              if (isDesktop)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _isSaving ? null : _saveOrder,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save),
                    label: Text(
                      languageProvider.isEnglish ? 'Save' : 'محفوظ کریں',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (isMobile || isTablet)
                TextButton(
                  onPressed: _isLoading || _isSaving ? null : _saveOrder,
                  child: Text(
                    languageProvider.isEnglish ? 'Save' : 'محفوظ کریں',
                    style: TextStyle(
                      color: _isLoading || _isSaving ? Colors.grey : const Color(0xFF7C3AED),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
            bottom: kIsWeb && isDesktop
                ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: const Color(0xFFF0F0F5),
              ),
            )
                : null,
          ),
          body: KeyboardListener(
            focusNode: _shortcutFocusNode,
            onKeyEvent: _handleKeyEvent,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.all(
                      isMobile ? 16 : isTablet ? 24 : 32,
                    ),
                    child: Form(
                      key: _formKey,
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
                                      _buildBasicInfoSection(languageProvider),
                                      const SizedBox(height: 20),
                                      _buildAdditionalInfoSection(languageProvider),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      _buildBarcodeSearchSection(languageProvider),
                                      const SizedBox(height: 20),
                                      _buildTotalsSection(languageProvider),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildItemsTableSection(languageProvider),
                          ] else ...[
                            _buildBasicInfoSection(languageProvider),
                            const SizedBox(height: 20),
                            _buildBarcodeSearchSection(languageProvider),
                            const SizedBox(height: 20),
                            _buildItemsTableSection(languageProvider),
                            const SizedBox(height: 20),
                            _buildTotalsSection(languageProvider),
                            const SizedBox(height: 20),
                            _buildAdditionalInfoSection(languageProvider),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
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
                          label: languageProvider.isEnglish ? 'Add Item' : 'آئٹم شامل کریں',
                          color: const Color(0xFF7C3AED),
                          onTap: _addEmptyRow,
                        ),
                        const SizedBox(height: 12),
                        _buildQuickActionButton(
                          icon: Icons.qr_code_scanner,
                          label: languageProvider.isEnglish ? 'Scan Barcode' : 'بارکوڈ اسکین کریں',
                          color: const Color(0xFF3B82F6),
                          onTap: () {
                            _barcodeFocusNode.requestFocus();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildQuickActionButton(
                          icon: Icons.print,
                          label: languageProvider.isEnglish ? 'Print Preview' : 'پرنٹ پیش نظارہ',
                          color: const Color(0xFF10B981),
                          onTap: _selectedSupplierId != null && _items.isNotEmpty
                              ? _printPreview
                              : null,
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
                          languageProvider.isEnglish ? 'Items' : 'اشیاء',
                          _items.where((r) => r.selectedProductId != null).length.toString(),
                        ),
                        _buildSummaryLine(
                          languageProvider.isEnglish ? 'Total' : 'کل',
                          _currency.format(_totalAmount),
                          isBold: true,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading || _isSaving ? null : _saveOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Text(
                              languageProvider.isEnglish ? 'Save Order' : 'آرڈر محفوظ کریں',
                            ),
                          ),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 12),
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

  Widget _buildBasicInfoSection(LanguageProvider lp) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return _buildCard(
      lp.isEnglish ? 'Basic Information' : 'بنیادی معلومات',
      lp,
      child: isMobile
          ? Column(
        children: [
          _buildSupplierDropdown(lp),
          const SizedBox(height: 16),
          _buildOrderDatePicker(lp),
          const SizedBox(height: 16),
          _buildDeliveryDatePicker(lp),
        ],
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildSupplierDropdown(lp),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildOrderDatePicker(lp),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDeliveryDatePicker(lp),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierDropdown(LanguageProvider lp) {
    return Consumer<SupplierProvider>(
      builder: (context, provider, _) {
        return DropdownButtonFormField<int?>(
          value: _selectedSupplierId,
          decoration: InputDecoration(
            labelText: lp.isEnglish ? 'Supplier *' : 'سپلائر *',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.business),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                lp.isEnglish ? 'Select Supplier' : 'سپلائر منتخب کریں',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            ...provider.suppliers.map(
                  (s) => DropdownMenuItem<int?>(
                value: s.id,
                child: Text(
                  s.name,
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() {
            _selectedSupplierId = v;
            if (v != null) {
              final supplierProvider =
              Provider.of<SupplierProvider>(context, listen: false);
              final supplier =
              supplierProvider.suppliers.firstWhere((s) => s.id == v);
              for (final row in _items) {
                row.discountController.text =
                    supplier.discountPercent.toStringAsFixed(2);
              }
              _recalculate();
            }
          }),
          validator: (v) => v == null
              ? (lp.isEnglish
              ? 'Supplier required'
              : 'سپلائر ضروری ہے')
              : null,
          style: TextStyle(
            fontFamily: lp.fontFamily,
            color: Colors.black,
          ),
          dropdownColor: Colors.white,
          iconEnabledColor: Colors.black,
        );
      },
    );
  }

  Widget _buildOrderDatePicker(LanguageProvider lp) {
    return InkWell(
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
          color: const Color(0xFFF9FAFB),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${lp.isEnglish ? 'Order Date' : 'آرڈر کی تاریخ'}: ${DateFormat('MMM dd, yyyy').format(_orderDate)}',
                style: const TextStyle(color: Colors.black87),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDatePicker(LanguageProvider lp) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _expectedDeliveryDate ??
              DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
            ),
            child: child!,
          ),
        );
        if (date != null) setState(() => _expectedDeliveryDate = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF9FAFB),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _expectedDeliveryDate == null
                    ? (lp.isEnglish ? 'Expected Delivery Date (Optional)' : 'متوقع ترسیل کی تاریخ (اختیاری)')
                    : '${lp.isEnglish ? 'Expected' : 'متوقع'}: ${DateFormat('MMM dd, yyyy').format(_expectedDeliveryDate!)}',
                style: TextStyle(
                  color: _expectedDeliveryDate == null
                      ? Colors.grey[600]
                      : Colors.black87,
                  fontFamily: lp.fontFamily,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeSearchSection(LanguageProvider lp) {
    return _buildCard(
      lp.isEnglish ? 'Quick Add by Barcode' : 'بارکوڈ کے ذریعے فوری شامل کریں',
      lp,
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
                    focusNode: _barcodeFocusNode,
                    style: TextStyle(fontFamily: lp.fontFamily),
                    decoration: InputDecoration(
                      hintText: lp.isEnglish ? 'Scan or enter barcode...' : 'بارکوڈ اسکین کریں یا درج کریں...',
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
                    onSubmitted: (value) {
                      if (value.isNotEmpty && _barcodeSearchResults.isNotEmpty) {
                        _addItemFromBarcode(_barcodeSearchResults.first);
                      }
                    },
                  ),
                ),
                if (kIsWeb)
                  Tooltip(
                    message: lp.isEnglish ? 'Press Enter to add first result' : 'پہلا نتیجہ شامل کرنے کے لیے Enter دبائیں',
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),

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
                      '${lp.isEnglish ? 'Barcode' : 'بارکوڈ'}: ${product['barcode']}  |  ${lp.isEnglish ? 'Cost' : 'لاگت'}: ${_currency.format(product['cost_price'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () => _addItemFromBarcode(product),
                      child: Text(lp.isEnglish ? 'Add' : 'شامل کریں'),
                    ),
                  );
                },
              ),
            ),
          ],

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
                      lp.isEnglish
                          ? 'No products found with this barcode. Try scanning again or add manually.'
                          : 'اس بارکوڈ کے ساتھ کوئی پروڈکٹ نہیں ملی۔ دوبارہ اسکین کریں یا دستی طور پر شامل کریں۔',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                        fontFamily: lp.fontFamily,
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

  Widget _buildItemsTableSection(LanguageProvider lp) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 900;

    return _buildCard(
      lp.isEnglish ? 'Order Items' : 'آرڈر کی اشیاء',
      lp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header - responsive
          if (!isMobile)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  _headerCell(lp.isEnglish ? 'Product' : 'پروڈکٹ', flex: isTablet ? 3 : 4, lp: lp),
                  _headerCell(lp.isEnglish ? 'Qty' : 'مقدار', flex: isTablet ? 1 : 2, lp: lp),
                  if (!isTablet) _headerCell(lp.isEnglish ? 'Unit' : 'یونٹ', flex: 2, lp: lp),
                  _headerCell(lp.isEnglish ? 'Unit Cost' : 'فی یونٹ لاگت', flex: isTablet ? 2 : 3, lp: lp),
                  if (!isTablet) ...[
                    _headerCell(lp.isEnglish ? 'Disc %' : 'چھوٹ %', flex: 2, lp: lp),
                    _headerCell(lp.isEnglish ? 'Tax %' : 'ٹیکس %', flex: 2, lp: lp),
                  ],
                  _headerCell(lp.isEnglish ? 'Line Total' : 'لائن کل', flex: isTablet ? 2 : 3, lp: lp),
                  const SizedBox(width: 36),
                ],
              ),
            ),
          const SizedBox(height: 4),

          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.table_rows_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(lp.isEnglish ? 'No items yet. Click "+ Add Row" to begin.' : 'ابھی تک کوئی آئٹم نہیں۔ شروع کرنے کے لیے "+ Add Row" پر کلک کریں۔',
                        style: TextStyle(color: Colors.grey[500], fontFamily: lp.fontFamily)),
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
                        entry.key, entry.value, productProvider, lp, isMobile, isTablet);
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F5)),
          const SizedBox(height: 12),

          Row(
            children: [
              GestureDetector(
                onTap: _addEmptyRow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withOpacity(0.3),
                        style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Text(
                        lp.isEnglish ? 'Add Row' : 'قطار شامل کریں',
                        style: const TextStyle(
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
              Expanded(
                child: Text(
                  lp.isEnglish ? '💡 Tip: Use the barcode scanner above to quickly add items' : '💡 ٹپ: آئٹمز کو فوری طور پر شامل کرنے کے لیے اوپر بارکوڈ اسکینر استعمال کریں',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                    fontFamily: lp.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1, required LanguageProvider lp}) {
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
      int index,
      PurchaseOrderItemRow row,
      ProductProvider productProvider,
      LanguageProvider lp,
      bool isMobile,
      bool isTablet,
      ) {
    final qty = double.tryParse(row.quantityController.text) ?? 0;
    final cost = double.tryParse(row.unitCostController.text) ?? 0;
    final discountPercent = double.tryParse(row.discountController.text) ?? 0;
    final taxPercent = double.tryParse(row.taxController.text) ?? 0;

    final subtotal = qty * cost;
    final afterDiscount = subtotal * (1 - discountPercent / 100);
    final lineTotal = afterDiscount * (1 + taxPercent / 100);

    if (isMobile) {
      return _buildMobileTableRow(index, row, productProvider, lp, lineTotal);
    }

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

          Expanded(
            flex: isTablet ? 3 : 4,
            child: _buildProductDropdown(row, productProvider, lp),
          ),
          const SizedBox(width: 6),

          Expanded(
            flex: isTablet ? 1 : 2,
            child: _buildCompactField(
              controller: row.quantityController,
              hint: '0',
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalculate(),
              lp: lp,
            ),
          ),
          if (!isTablet) ...[
            const SizedBox(width: 6),
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
          ],
          const SizedBox(width: 6),

          Expanded(
            flex: isTablet ? 2 : 3,
            child: _buildCompactField(
              controller: row.unitCostController,
              hint: '0.00',
              prefix: 'Rs ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalculate(),
              lp: lp,
            ),
          ),
          if (!isTablet) ...[
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _buildCompactField(
                controller: row.discountController,
                hint: '0',
                suffix: '%',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _recalculate(),
                lp: lp,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _buildCompactField(
                controller: row.taxController,
                hint: '0',
                suffix: '%',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _recalculate(),
                lp: lp,
              ),
            ),
          ],
          const SizedBox(width: 6),

          Expanded(
            flex: isTablet ? 2 : 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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

          SizedBox(
            width: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(Icons.remove_circle_outline,
                  size: 18, color: Color(0xFFEF4444)),
              onPressed: () => _removeRow(index),
              tooltip: lp.isEnglish ? 'Remove' : 'ہٹائیں',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTableRow(
      int index,
      PurchaseOrderItemRow row,
      ProductProvider productProvider,
      LanguageProvider lp,
      double lineTotal,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProductDropdown(row, productProvider, lp),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(Icons.remove_circle_outline,
                    size: 20, color: Color(0xFFEF4444)),
                onPressed: () => _removeRow(index),
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
                controller: row.quantityController,
                width: 60,
                onChanged: (_) => _recalculate(),
                lp: lp,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  row.unitSymbol.isNotEmpty ? row.unitSymbol : '—',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              _buildMobileField(
                label: lp.isEnglish ? 'Unit Cost' : 'فی یونٹ لاگت',
                controller: row.unitCostController,
                width: 80,
                prefix: 'Rs ',
                onChanged: (_) => _recalculate(),
                lp: lp,
              ),
              _buildMobileField(
                label: 'Disc %',
                controller: row.discountController,
                width: 60,
                onChanged: (_) => _recalculate(),
                lp: lp,
              ),
              _buildMobileField(
                label: 'Tax %',
                controller: row.taxController,
                width: 60,
                onChanged: (_) => _recalculate(),
                lp: lp,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${lp.isEnglish ? 'Total' : 'کل'}: ${_currency.format(lineTotal)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
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

  Widget _buildProductDropdown(
      PurchaseOrderItemRow row, ProductProvider productProvider, LanguageProvider lp) {
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
          hint: Text(lp.isEnglish ? 'Select…' : 'منتخب کریں…',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF2D3142)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          dropdownColor: Colors.white,
          items: [
            DropdownMenuItem<int?>(
                value: null,
                child: Text(lp.isEnglish ? 'Select…' : 'منتخب کریں…',
                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
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
                row.unitSymbol = product.unit?.symbol ?? '';
                row.unitCostController.text = product.costPrice.toString();
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
    required LanguageProvider lp,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 12, fontFamily: lp.fontFamily),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
        prefixText: prefix,
        prefixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        suffixText: suffix,
        suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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

  Widget _buildTotalsSection(LanguageProvider lp) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return _buildCard(
      lp.isEnglish ? 'Order Totals' : 'آرڈر کے کل',
      lp,
      child: Column(
        children: [
          if (!isMobile)
            Row(
              children: [
                Expanded(
                  child: _buildLabeledField(
                    label: lp.isEnglish ? 'Tax Amount' : 'ٹیکس کی رقم',
                    controller: _taxController,
                    onChanged: (_) => _recalculate(),
                    lp: lp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLabeledField(
                    label: lp.isEnglish ? 'Discount' : 'چھوٹ',
                    controller: _discountController,
                    onChanged: (_) => _recalculate(),
                    lp: lp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLabeledField(
                    label: lp.isEnglish ? 'Shipping' : 'شپنگ',
                    controller: _shippingController,
                    onChanged: (_) => _recalculate(),
                    lp: lp,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildLabeledField(
                  label: lp.isEnglish ? 'Tax Amount' : 'ٹیکس کی رقم',
                  controller: _taxController,
                  onChanged: (_) => _recalculate(),
                  lp: lp,
                ),
                const SizedBox(height: 12),
                _buildLabeledField(
                  label: lp.isEnglish ? 'Discount' : 'چھوٹ',
                  controller: _discountController,
                  onChanged: (_) => _recalculate(),
                  lp: lp,
                ),
                const SizedBox(height: 12),
                _buildLabeledField(
                  label: lp.isEnglish ? 'Shipping' : 'شپنگ',
                  controller: _shippingController,
                  onChanged: (_) => _recalculate(),
                  lp: lp,
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
                _totalLine(lp.isEnglish ? 'Subtotal' : 'ذیلی کل', _subtotal, lp: lp),
                const SizedBox(height: 8),
                _totalLine(lp.isEnglish ? 'Tax' : 'ٹیکس', _taxAmount, lp: lp),
                const SizedBox(height: 8),
                _totalLine(lp.isEnglish ? 'Discount' : 'چھوٹ', -_discountAmount,
                    color: const Color(0xFFEF4444), lp: lp),
                const SizedBox(height: 8),
                _totalLine(lp.isEnglish ? 'Shipping' : 'شپنگ', _shippingCost, lp: lp),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFDDD6FE)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lp.isEnglish ? 'Total' : 'کل',
                      style: const TextStyle(
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

  Widget _totalLine(String label, double amount, {Color? color, required LanguageProvider lp}) {
    final displayColor = color ??
        (amount < 0 ? const Color(0xFFEF4444) : const Color(0xFF4B5563));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 14, color: const Color(0xFF6B7280), fontFamily: lp.fontFamily)),
        Text(
          amount < 0
              ? '-${_currency.format(amount.abs())}'
              : _currency.format(amount),
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: displayColor, fontFamily: lp.fontFamily),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    void Function(String)? onChanged,
    required LanguageProvider lp,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontFamily: lp.fontFamily)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 13, fontFamily: lp.fontFamily),
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixText: 'Rs ',
            prefixStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection(LanguageProvider lp) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return _buildCard(
      lp.isEnglish ? 'Additional Information' : 'اضافی معلومات',
      lp,
      child: isMobile
          ? Column(
        children: [
          TextFormField(
            controller: _notesController,
            style: TextStyle(fontFamily: lp.fontFamily),
            decoration: InputDecoration(
              labelText: lp.isEnglish ? 'Notes' : 'نوٹس',
              hintText: lp.isEnglish ? 'Any additional notes...' : 'کوئی اضافی نوٹس...',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _paymentTermsController,
            style: TextStyle(fontFamily: lp.fontFamily),
            decoration: InputDecoration(
              labelText: lp.isEnglish ? 'Payment Terms' : 'ادائیگی کی شرائط',
              hintText: lp.isEnglish ? 'e.g., Net 30' : 'مثال: نیٹ 30',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsController,
            style: TextStyle(fontFamily: lp.fontFamily),
            decoration: InputDecoration(
              labelText: lp.isEnglish ? 'Terms & Conditions' : 'شرائط و ضوابط',
              hintText: lp.isEnglish ? 'Any terms and conditions...' : 'کوئی شرائط و ضوابط...',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 2,
          ),
        ],
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _notesController,
              style: TextStyle(fontFamily: lp.fontFamily),
              decoration: InputDecoration(
                labelText: lp.isEnglish ? 'Notes' : 'نوٹس',
                hintText: lp.isEnglish ? 'Any additional notes...' : 'کوئی اضافی نوٹس...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                TextFormField(
                  controller: _paymentTermsController,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Payment Terms' : 'ادائیگی کی شرائط',
                    hintText: lp.isEnglish ? 'e.g., Net 30' : 'مثال: نیٹ 30',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _termsController,
                  style: TextStyle(fontFamily: lp.fontFamily),
                  decoration: InputDecoration(
                    labelText: lp.isEnglish ? 'Terms & Conditions' : 'شرائط و ضوابط',
                    hintText: lp.isEnglish ? 'Any terms and conditions...' : 'کوئی شرائط و ضوابط...',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, LanguageProvider lp, {required Widget child}) {
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                  fontFamily: lp.fontFamily)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Future<void> _saveOrder() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lp.isEnglish ? 'Please select a supplier' : 'براہ کرم سپلائر منتخب کریں')));
      return;
    }

    final validItems = _items
        .where((r) =>
    r.selectedProductId != null &&
        (double.tryParse(r.quantityController.text) ?? 0) > 0)
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lp.isEnglish ? 'Please add at least one item' : 'براہ کرم کم از کم ایک آئٹم شامل کریں')));
      return;
    }

    setState(() => _isSaving = true);

    final orderData = {
      'supplier_id': _selectedSupplierId,
      'order_date': "${_orderDate.year}-${_orderDate.month.toString().padLeft(2, '0')}-${_orderDate.day.toString().padLeft(2, '0')}",
      'expected_delivery_date': _expectedDeliveryDate == null ? null
          : "${_expectedDeliveryDate!.year}-${_expectedDeliveryDate!.month.toString().padLeft(2, '0')}-${_expectedDeliveryDate!.day.toString().padLeft(2, '0')}",
      'items': validItems
          .map((r) => {
        'product_id': r.selectedProductId,
        'quantity_ordered': int.tryParse(r.quantityController.text) ?? 1,
        'unit_cost': double.tryParse(r.unitCostController.text) ?? 0,
        'discount_percent': double.tryParse(r.discountController.text) ?? 0,
        'tax_percent': double.tryParse(r.taxController.text) ?? 0,
        'notes': r.notesController.text.isEmpty ? null : r.notesController.text,
      })
          .toList(),
      'tax_amount': _taxAmount,
      'discount_amount': _discountAmount,
      'shipping_cost': _shippingCost,
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
      'payment_terms': _paymentTermsController.text.isEmpty ? null : _paymentTermsController.text,
      'terms_conditions': _termsController.text.isEmpty ? null : _termsController.text,
    };

    try {
      final provider = Provider.of<PurchaseOrderProvider>(context, listen: false);
      Map<String, dynamic> result;

      if (widget.orderId != null) {
        result = await provider.updateOrderStatus(widget.orderId!, 'draft');
      } else {
        result = await provider.createPurchaseOrder(orderData);
      }

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.orderId != null
              ? (lp.isEnglish ? 'Order updated successfully' : 'آرڈر کامیابی سے اپ ڈیٹ ہوگیا')
              : (lp.isEnglish ? 'Order created successfully' : 'آرڈر کامیابی سے بن گیا')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        Navigator.pop(context, true);
      } else {
        throw Exception(result['error'] ?? (lp.isEnglish ? 'Failed to save order' : 'آرڈر محفوظ کرنے میں ناکامی'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lp.isEnglish ? 'Error' : 'خرابی'}: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ─── Row data model ──────────────────────────────────────────────────────────

class PurchaseOrderItemRow {
  int? selectedProductId;
  String productName;
  String unitSymbol;
  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController discountController;
  final TextEditingController taxController;
  final TextEditingController notesController;

  PurchaseOrderItemRow({
    this.selectedProductId,
    this.productName = '',
    this.unitSymbol = '',
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
    unitSymbol: '',
  );

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
    discountController.dispose();
    taxController.dispose();
    notesController.dispose();
  }
}