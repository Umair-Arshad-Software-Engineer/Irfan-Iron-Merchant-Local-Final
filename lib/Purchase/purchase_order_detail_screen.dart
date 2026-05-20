// lib/screens/purchases/purchase_order_detail_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/purchase_receipt_provider.dart';
import '../../models/purchase_order_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';
import '../services/purchase_pdf_generator.dart';
import 'add_edit_purchase_order_screen.dart';
import 'create_receipt_screen.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final int orderId;

  const PurchaseOrderDetailScreen({super.key, required this.orderId});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState
    extends State<PurchaseOrderDetailScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final poProvider =
    Provider.of<PurchaseOrderProvider>(context, listen: false);
    final receiptProvider =
    Provider.of<PurchaseReceiptProvider>(context, listen: false);

    await poProvider.fetchPurchaseOrderById(widget.orderId);
    await receiptProvider.fetchReceiptsByPurchaseOrder(widget.orderId);
  }


  Future<void> _printPurchaseOrder() async {
    if (_selectedPurchaseOrder == null) return;

    final order = _selectedPurchaseOrder!;

    // Prepare items for PDF
    final items = order.items?.map((item) {
      final qty = item.quantityOrdered.toDouble();
      final cost = item.unitCost;
      final discountPercent = item.discountPercent;
      final taxPercent = item.taxPercent;

      final subtotal = qty * cost;
      final afterDiscount = subtotal * (1 - discountPercent / 100);
      final lineTotal = afterDiscount * (1 + taxPercent / 100);

      return {
        'product_name': item.product?.itemName ?? 'Unknown',
        'barcode': item.product?.barcode,
        'quantity': qty,
        'unit_cost': cost,
        'discount_percent': discountPercent,
        'tax_percent': taxPercent,
        'line_total': lineTotal,
      };
    }).toList() ?? [];

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfData = await PurchasePdfGenerator.generatePurchaseOrderPdf(
        order: order,
        items: items,
      );

      if (mounted) Navigator.pop(context);
      _showPrintOptions(pdfData, '${order.poNumber}.pdf');
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

  Future<void> _printReceipt(PurchaseReceiptModel receipt) async {
    if (_selectedPurchaseOrder == null) return;

    final order = _selectedPurchaseOrder!;

    // Prepare receipt items for PDF
    final items = receipt.items?.map((item) {
      final qty = item.quantityReceived.toDouble();
      final cost = item.unitCost;

      // For receipt items, we don't have discount/tax in the same way as PO items
      // Using the actual values from the receipt
      final lineTotal = qty * cost;

      return {
        'product_name': item.product?.itemName ?? 'Unknown',
        'barcode': item.product?.barcode,
        'quantity': qty,
        'unit_cost': cost,
        'discount_percent': 0, // Receipt items may not have discount
        'tax_percent': 0,       // Receipt items may not have tax
        'line_total': lineTotal,
        'batch_number': item.batchNumber,
      };
    }).toList() ?? [];

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfData = await PurchasePdfGenerator.generatePurchaseReceiptPdf(
        receipt: receipt,
        order: order,
        items: items,
      );

      if (mounted) Navigator.pop(context);
      _showPrintOptions(pdfData, '${receipt.receiptNumber}.pdf');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
      );
    }
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Purchase Order Details',
          style: TextStyle(
              color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF7C3AED)),
            onPressed: _printPurchaseOrder,
            tooltip: 'Print PO',
          ),
          // Edit button — only for draft
          if (_selectedPurchaseOrder?.status == 'draft')
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF7C3AED)),
              onPressed: _editOrder,
            ),

          // 3-dot menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: _handleAction,
            itemBuilder: (context) => [
              if (_selectedPurchaseOrder?.status == 'ordered' ||
                  _selectedPurchaseOrder?.status == 'partial')
                const PopupMenuItem(
                  value: 'receive',
                  child: Row(
                    children: [
                      Icon(Icons.inventory, size: 18, color: Color(0xFF7C3AED)),
                      SizedBox(width: 8),
                      Text('Receive Items'),
                    ],
                  ),
                ),
              if (_selectedPurchaseOrder?.status == 'draft')
                const PopupMenuItem(
                  value: 'place_order',
                  child: Row(
                    children: [
                      Icon(Icons.send, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Place Order'),
                    ],
                  ),
                ),
              if (_selectedPurchaseOrder?.status == 'draft' ||
                  _selectedPurchaseOrder?.status == 'cancelled')
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Order',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              if (_selectedPurchaseOrder?.status == 'ordered' ||
                  _selectedPurchaseOrder?.status == 'partial')
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Cancel Order'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Consumer<PurchaseOrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingIndicator();
          }

          if (provider.errorMessage != null) {
            return CustomErrorWidget(
              message: provider.errorMessage!,
              onRetry: _loadData,
            );
          }

          if (provider.selectedPurchaseOrder == null) {
            return const Center(child: Text('Order not found'));
          }

          final order = provider.selectedPurchaseOrder!;

          return Column(
            children: [
              _buildHeader(order, dateFormat, currencyFormat),
              // ── PO-level over-received banner ──────────────────────────
              if (order.hasOverReceivedItems) _buildPoOverReceivedBanner(order),
              _buildTabBar(),
              Expanded(child: _buildTabContent(order, currencyFormat)),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<PurchaseOrderProvider>(
        builder: (context, provider, _) {
          final status = provider.selectedPurchaseOrder?.status;
          if (status != 'ordered' && status != 'partial') {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: _navigateToCreateReceipt,
            label: const Text('Receive Items',
                style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.inventory, color: Colors.white),
            backgroundColor: const Color(0xFF7C3AED),
          );
        },
      ),
    );
  }

  PurchaseOrderModel? get _selectedPurchaseOrder =>
      Provider.of<PurchaseOrderProvider>(context, listen: false)
          .selectedPurchaseOrder;

  // ─── PO-level over-received banner ────────────────────────────────────────

  Widget _buildPoOverReceivedBanner(PurchaseOrderModel order) {
    final overCount = order.items?.where((i) => i.isOverReceived).length ?? 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Over-received: $overCount item${overCount > 1 ? 's exceed' : ' exceeds'} '
                  'the ordered quantity. Review the Items tab for details.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(PurchaseOrderModel order, DateFormat dateFormat,
      NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: order.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getStatusIcon(order.status),
                    color: order.statusColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.poNumber,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: order.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: order.statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.supplier?.name ?? 'Unknown Supplier',
                      style:
                      TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildInfoBox('Order Date',
                  dateFormat.format(order.orderDate), Colors.blue),
              const SizedBox(width: 12),
              _buildInfoBox('Total Amount',
                  currencyFormat.format(order.totalAmount), Colors.green),
              const SizedBox(width: 12),
              _buildInfoBox(
                  'Items', '${order.items?.length ?? 0}', Colors.purple),
            ],
          ),
          if (order.expectedDeliveryDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Expected Delivery: ${dateFormat.format(order.expectedDeliveryDate!)}',
                      style: const TextStyle(color: Colors.orange),
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

  Widget _buildInfoBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  // ─── Tab Bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('Items', 0),
          _buildTab('Receipts', 1),
          _buildTab('Details', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF7C3AED)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF7C3AED) : Colors.grey,
              fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tab Content ──────────────────────────────────────────────────────────

  Widget _buildTabContent(
      PurchaseOrderModel order, NumberFormat currencyFormat)
  {
    switch (_selectedTab) {
      case 0:
        return _buildItemsTab(order, currencyFormat);
      case 1:
        return _buildReceiptsTab(order);
      case 2:
        return _buildDetailsTab(order, currencyFormat);
      default:
        return _buildItemsTab(order, currencyFormat);
    }
  }

  // ─── Items Tab ────────────────────────────────────────────────────────────

  Widget _buildItemsTab(
      PurchaseOrderModel order, NumberFormat currencyFormat) {
    if (order.items == null || order.items!.isEmpty) {
      return const Center(child: Text('No items found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: order.items!.length,
      itemBuilder: (context, index) {
        final item = order.items![index];

        final rawTotal = item.quantityOrdered * item.unitCost;
        final afterDiscount = rawTotal * (1 - item.discountPercent / 100);
        final lineTotal = afterDiscount * (1 + item.taxPercent / 100);

        final receivedPercent =
        (item.quantityReceived / item.quantityOrdered * 100)
            .clamp(0, 150); // allow > 100 for over-received

        // Determine badge & progress colours
        final Color badgeBg = item.isOverReceived
            ? Colors.red.withOpacity(0.12)
            : item.isFullyReceived
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1);

        final Color badgeFg = item.isOverReceived
            ? Colors.red
            : item.isFullyReceived
            ? Colors.green
            : Colors.orange;

        final Color progressColor = item.isOverReceived
            ? Colors.red
            : item.isFullyReceived
            ? Colors.green
            : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isOverReceived
                  ? Colors.red.withOpacity(0.4)
                  : const Color(0xFFF0F0F5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product name + unit badge + received/ordered badge ──
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.product?.itemName ?? 'Unknown Product',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        // ── ADD THIS ──
                        if (item.product?.unit?.symbol != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: const Color(0xFF7C3AED).withOpacity(0.2)),
                            ),
                            child: Text(
                              item.product!.unit!.symbol,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                        // ─────────────
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.quantityReceived}/${item.quantityOrdered}',
                      style: TextStyle(
                        fontSize: 12,
                        color: badgeFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                      child: _buildItemDetail('Unit Cost',
                          currencyFormat.format(item.unitCost))),
                  // ── CHANGE THIS ──
                  Expanded(
                      child: _buildItemDetail(
                          'Qty',
                          item.product?.unit?.symbol != null
                              ? '× ${item.quantityOrdered} ${item.product!.unit!.symbol}'
                              : '× ${item.quantityOrdered}')),
                  // ─────────────────
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.discountPercent > 0)
                    Expanded(
                        child: _buildItemDetail('After Disc',
                            currencyFormat.format(afterDiscount))),
                  Expanded(
                      child: _buildItemDetail(
                          'Line Total', currencyFormat.format(lineTotal),
                          highlight: true)),
                ],
              ),
              if (item.discountPercent > 0 || item.taxPercent > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (item.discountPercent > 0)
                      Expanded(
                          child: _buildItemDetail(
                              'Discount', '${item.discountPercent}%')),
                    if (item.taxPercent > 0)
                      Expanded(
                          child: _buildItemDetail(
                              'Tax', '${item.taxPercent}%')),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Progress bar — capped visually at 100 % for normal, shows full
              // red bar for over-received
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.isOverReceived
                      ? 1.0
                      : receivedPercent / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor:
                  AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 6,
                ),
              ),

              // ── Over-received banner (per item) ────────────────────────
              if (item.isOverReceived) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(7),
                    border:
                    Border.all(color: Colors.red.withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 15),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Over-received: ${item.quantityReceived} received '
                              'vs ${item.quantityOrdered} ordered '
                              '(+${item.overReceivedQuantity} extra unit${item.overReceivedQuantity > 1 ? 's' : ''})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Note: ${item.notes}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemDetail(String label, String value,
      {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlight
                    ? const Color(0xFF059669)
                    : const Color(0xFF2D3142))),
      ],
    );
  }

  // ─── Receipts Tab ─────────────────────────────────────────────────────────

  Widget _buildReceiptsTab(PurchaseOrderModel order) {
    return Consumer<PurchaseReceiptProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final receipts = provider.receipts;

        if (receipts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No receipts yet',
                    style:
                    TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                if (order.status == 'ordered' || order.status == 'partial')
                  ElevatedButton.icon(
                    onPressed: _navigateToCreateReceipt,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Receipt'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            final receipt = receipts[index];
            return _buildReceiptCard(receipt, order);
          },
        );
      },
    );
  }

  // ── Receipt Card ──────────────────────────────────────────────────────────

  Widget _buildReceiptCard(PurchaseReceiptModel receipt, PurchaseOrderModel order) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    // Detect over-received items within THIS receipt by cross-referencing
    // the PO items list.
    final overReceivedInReceipt = receipt.items?.where((ri) {
      if (ri.purchaseOrderItemId <= 0) return false; // extra item, skip
      final poItem = order.items?.firstWhere(
            (poi) => poi.id == ri.purchaseOrderItemId,
        orElse: () => PurchaseOrderItemModel(
          id: -1,
          purchaseOrderId: 0,
          productId: 0,
          quantityOrdered: 1,
          quantityReceived: 0,
          unitCost: 0,
          lineTotal: 0,
          discountPercent: 0,
          taxPercent: 0,
          notes: null,
          product: null,
          receiptItems: null,
        ),
      );
      return poItem != null && poItem.isOverReceived;
    }).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overReceivedInReceipt.isNotEmpty
              ? Colors.red.withOpacity(0.4)
              : const Color(0xFFF0F0F5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Receipt icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: overReceivedInReceipt.isNotEmpty
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt,
                    color: overReceivedInReceipt.isNotEmpty
                        ? Colors.red
                        : Colors.green,
                    size: 20),
              ),
              const SizedBox(width: 12),

              // Receipt number + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.receiptNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      dateFormat.format(receipt.receiptDate),
                      style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Item count badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${receipt.items?.length ?? 0} items',
                  style:
                  const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),

              // Print button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.print_outlined,
                    color: Color(0xFF7C3AED), size: 20),
                tooltip: 'Print Receipt',
                onPressed: () => _printReceipt(receipt),
              ),

              const SizedBox(width: 4),

              // Delete button
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                tooltip: 'Delete Receipt',
                onPressed: () => _confirmDeleteReceipt(receipt),
              ),
            ],
          ),

          // ── Over-received banner inside receipt card ──────────────────
          if (overReceivedInReceipt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.red.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${overReceivedInReceipt.length} item${overReceivedInReceipt.length > 1 ? 's' : ''} in this receipt '
                          '${overReceivedInReceipt.length > 1 ? 'exceed' : 'exceeds'} the ordered quantity.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Item preview
          const SizedBox(height: 12),
          ...?receipt.items?.take(2).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Text(
                    item.product?.itemName ?? 'Unknown',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  'x${item.quantityReceived}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
                if (item.batchNumber != null && item.batchNumber!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Batch: ${item.batchNumber}',
                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
          )),
          if (receipt.items != null && receipt.items!.length > 2)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Text(
                '+${receipt.items!.length - 2} more items',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ── Confirm & delete receipt ──────────────────────────────────────────────

  Future<void> _confirmDeleteReceipt(PurchaseReceiptModel receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Delete Receipt'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${receipt.receiptNumber}?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This will:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  _BulletPoint('Reverse stock for all received items'),
                  _BulletPoint('Reset PO item quantities'),
                  _BulletPoint('Update PO status accordingly'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _deleteReceipt(receipt.id);
    }
  }

  Future<void> _deleteReceipt(int receiptId) async {
    final receiptProvider =
    Provider.of<PurchaseReceiptProvider>(context, listen: false);

    final result = await receiptProvider.deletePurchaseReceipt(receiptId);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt deleted & stock reversed'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to delete receipt'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Details Tab ──────────────────────────────────────────────────────────

  Widget _buildDetailsTab(
      PurchaseOrderModel order, NumberFormat currencyFormat)
  {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection('Order Information', [
            _buildInfoRow('PO Number', order.poNumber),
            _buildInfoRow('Status', order.statusText,
                color: order.statusColor),
            _buildInfoRow(
                'Order Date', dateFormat.format(order.orderDate)),
            _buildInfoRow(
                'Expected Delivery',
                order.expectedDeliveryDate != null
                    ? dateFormat.format(order.expectedDeliveryDate!)
                    : 'Not set'),
            _buildInfoRow(
                'Delivery Date',
                order.deliveryDate != null
                    ? dateFormat.format(order.deliveryDate!)
                    : 'Not delivered'),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('Supplier Information', [
            _buildInfoRow('Name', order.supplier?.name ?? 'N/A'),
            _buildInfoRow('Contact', order.supplier?.contact ?? 'N/A'),
            _buildInfoRow('Email', order.supplier?.email ?? 'N/A'),
            _buildInfoRow(
                'Payment Terms', order.supplier?.paymentTerms ?? 'N/A'),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('Financial Summary', [
            _buildInfoRow(
                'Subtotal', currencyFormat.format(order.subtotal)),
            _buildInfoRow('Tax', currencyFormat.format(order.taxAmount)),
            _buildInfoRow('Discount',
                currencyFormat.format(order.discountAmount),
                isNegative: true),
            _buildInfoRow(
                'Shipping', currencyFormat.format(order.shippingCost)),
            _buildInfoRow(
                'Total', currencyFormat.format(order.totalAmount),
                isBold: true),
          ]),
          const SizedBox(height: 20),
          _buildInfoSection('Additional Information', [
            if (order.notes != null && order.notes!.isNotEmpty)
              _buildInfoRow('Notes', order.notes!, isMultiline: true),
            if (order.paymentTerms != null &&
                order.paymentTerms!.isNotEmpty)
              _buildInfoRow('Payment Terms', order.paymentTerms!),
            if (order.termsConditions != null &&
                order.termsConditions!.isNotEmpty)
              _buildInfoRow(
                  'Terms & Conditions', order.termsConditions!,
                  isMultiline: true),
            _buildInfoRow(
                'Created At', dateFormat.format(order.createdAt)),
            _buildInfoRow(
                'Last Updated', dateFormat.format(order.updatedAt)),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142))),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color,
        bool isBold = false,
        bool isNegative = false,
        bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ??
                    (isNegative ? Colors.red : const Color(0xFF2D3142)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return Icons.drafts;
      case 'ordered':
        return Icons.shopping_cart;
      case 'partial':
        return Icons.star_half;
      case 'received':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _handleAction(String action) {
    switch (action) {
      case 'receive':
        _navigateToCreateReceipt();
        break;
      case 'place_order':
        _updateStatus('ordered');
        break;
      case 'cancel':
        _updateStatus('cancelled');
        break;
      case 'delete':
        _deleteOrder();
        break;
    }
  }

  Future<void> _updateStatus(String status) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            '${status == 'ordered' ? 'Place' : 'Cancel'} Order'),
        content: Text(
            'Are you sure you want to ${status == 'ordered' ? 'place' : 'cancel'} this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              status == 'cancelled' ? Colors.red : const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            child: Text(
                status == 'cancelled' ? 'Yes, Cancel' : 'Yes, Place Order'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider =
      Provider.of<PurchaseOrderProvider>(context, listen: false);
      final result =
      await provider.updateOrderStatus(widget.orderId, status);

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Order ${status == 'ordered' ? 'placed' : 'cancelled'} successfully'),
          backgroundColor: Colors.green,
        ));
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error'] ?? 'Failed to update status'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text(
            'Are you sure you want to delete this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider =
      Provider.of<PurchaseOrderProvider>(context, listen: false);
      final result = await provider.deletePurchaseOrder(widget.orderId);

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order deleted successfully'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error'] ?? 'Failed to delete order'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _editOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddEditPurchaseOrderScreen(orderId: widget.orderId),
      ),
    ).then((refresh) {
      if (refresh == true) _loadData();
    });
  }

  void _navigateToCreateReceipt() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReceiptScreen(orderId: widget.orderId),
      ),
    ).then((refresh) {
      if (refresh == true) _loadData();
    });
  }
}

// ─── Small helper widget for bullet points in dialog ─────────────────────────

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.red, fontSize: 13)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}