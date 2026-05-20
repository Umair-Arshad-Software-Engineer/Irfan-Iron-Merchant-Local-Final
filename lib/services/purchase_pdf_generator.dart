// // lib/services/purchase_pdf_generator.dart
// import 'dart:typed_data';
// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import '../models/purchase_order_model.dart';
//
// class PurchasePdfGenerator {
//   static const PdfColor primaryColor = PdfColor.fromInt(0xFF7C3AED);
//   static const PdfColor accentColor = PdfColor.fromInt(0xFF10B981);
//   static const PdfColor dangerColor = PdfColor.fromInt(0xFFEF4444);
//   static const PdfColor textDark = PdfColor.fromInt(0xFF1E1E2D);
//   static const PdfColor textMedium = PdfColor.fromInt(0xFF6B7280);
//   static const PdfColor textLight = PdfColor.fromInt(0xFF9CA3AF);
//   static const PdfColor borderColor = PdfColor.fromInt(0xFFEEEEF5);
//   static const PdfColor white = PdfColors.white;
//   static const PdfColor bgLight = PdfColor.fromInt(0xFFF9FAFB);
//   static const PdfColor primaryLight = PdfColor.fromInt(0xFFF3F0FD);
//
//   static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
//   static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
//   static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$ ');
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  GENERATE PURCHASE ORDER PDF
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<Uint8List> generatePurchaseOrderPdf({
//     required PurchaseOrderModel order,
//     required List<Map<String, dynamic>> items,
//   }) async {
//     final pdf = pw.Document();
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(32),
//         build: (pw.Context context) => [
//           _buildHeader(order),
//           pw.SizedBox(height: 20),
//           _buildSupplierInfo(order),
//           pw.SizedBox(height: 20),
//           _buildOrderInfo(order),
//           pw.SizedBox(height: 20),
//           _buildItemsTable(items),
//           pw.SizedBox(height: 20),
//           _buildTotals(order),
//           pw.SizedBox(height: 20),
//           if (order.notes != null || order.termsConditions != null)
//             _buildAdditionalInfo(order),
//           pw.SizedBox(height: 20),
//           _buildFooter(),
//         ],
//       ),
//     );
//
//     return pdf.save();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  GENERATE PURCHASE RECEIPT PDF
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<Uint8List> generatePurchaseReceiptPdf({
//     required PurchaseReceiptModel receipt,
//     required PurchaseOrderModel order,
//     required List<Map<String, dynamic>> items,
//   }) async {
//     final pdf = pw.Document();
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(32),
//         build: (pw.Context context) => [
//           _buildReceiptHeader(receipt),
//           pw.SizedBox(height: 20),
//           _buildReceiptInfo(receipt, order),
//           pw.SizedBox(height: 20),
//           _buildReceiptItemsTable(items),
//           pw.SizedBox(height: 20),
//           _buildReceiptTotals(receipt, order),
//           pw.SizedBox(height: 20),
//           if (receipt.notes != null)
//             _buildReceiptNotes(receipt),
//           pw.SizedBox(height: 20),
//           _buildFooter(),
//         ],
//       ),
//     );
//
//     return pdf.save();
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  HEADER SECTION
//   // ─────────────────────────────────────────────────────────────────────────
//   static pw.Widget _buildHeader(PurchaseOrderModel order) {
//     return pw.Row(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Expanded(
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 'PURCHASE ORDER',
//                 style: pw.TextStyle(
//                   fontSize: 28,
//                   fontWeight: pw.FontWeight.bold,
//                   color: primaryColor,
//                 ),
//               ),
//               pw.Text(
//                 order.poNumber,
//                 style: pw.TextStyle(
//                   fontSize: 14,
//                   fontWeight: pw.FontWeight.bold,
//                   color: textDark,
//                 ),
//               ),
//               pw.SizedBox(height: 4),
//               pw.Container(
//                 padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: pw.BoxDecoration(
//                   color: _getStatusColor(order.status).withOpacity(0.1),
//                   borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
//                 ),
//                 child: pw.Text(
//                   order.statusText.toUpperCase(),
//                   style: pw.TextStyle(
//                     fontSize: 10,
//                     color: _getStatusColor(order.status),
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         pw.Expanded(
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.end,
//             children: [
//               pw.Text(
//                 'YOUR COMPANY NAME',
//                 style: pw.TextStyle(
//                   fontSize: 16,
//                   fontWeight: pw.FontWeight.bold,
//                 ),
//               ),
//               pw.SizedBox(height: 4),
//               pw.Text(
//                 '123 Business Avenue, City',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//               pw.Text(
//                 'Phone: +92 XXX XXXXXXX',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//               pw.Text(
//                 'Email: purchases@company.com',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//               pw.Text(
//                 'GST: XX-XXXXXXX-X',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   static pw.Widget _buildReceiptHeader(PurchaseReceiptModel receipt) {
//     return pw.Row(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Expanded(
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 'GOODS RECEIPT NOTE',
//                 style: pw.TextStyle(
//                   fontSize: 28,
//                   fontWeight: pw.FontWeight.bold,
//                   color: accentColor,
//                 ),
//               ),
//               pw.Text(
//                 receipt.receiptNumber,
//                 style: pw.TextStyle(
//                   fontSize: 14,
//                   fontWeight: pw.FontWeight.bold,
//                   color: textDark,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         pw.Expanded(
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.end,
//             children: [
//               pw.Text(
//                 'YOUR COMPANY NAME',
//                 style: pw.TextStyle(
//                   fontSize: 16,
//                   fontWeight: pw.FontWeight.bold,
//                 ),
//               ),
//               pw.SizedBox(height: 4),
//               pw.Text(
//                 '123 Business Avenue, City',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//               pw.Text(
//                 'Phone: +92 XXX XXXXXXX',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//               pw.Text(
//                 'Email: purchases@company.com',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  SUPPLIER INFO SECTION
//   // ─────────────────────────────────────────────────────────────────────────
//   static pw.Widget _buildSupplierInfo(PurchaseOrderModel order) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: bgLight,
//         border: pw.Border.all(color: borderColor),
//         borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text(
//             'Supplier Information',
//             style: pw.TextStyle(
//               fontSize: 14,
//               fontWeight: pw.FontWeight.bold,
//               color: primaryColor,
//             ),
//           ),
//           pw.SizedBox(height: 10),
//           pw.Row(
//             children: [
//               pw.Expanded(
//                 child: pw.Column(
//                   crossAxisAlignment: pw.CrossAxisAlignment.start,
//                   children: [
//                     _infoRow('Supplier Name:', order.supplier?.name ?? 'N/A'),
//                     _infoRow('Contact:', order.supplier?.contact ?? 'N/A'),
//                     _infoRow('Email:', order.supplier?.email ?? 'N/A'),
//                   ],
//                 ),
//               ),
//               pw.Expanded(
//                 child: pw.Column(
//                   crossAxisAlignment: pw.CrossAxisAlignment.start,
//                   children: [
//                     _infoRow('Payment Terms:', order.supplier?.paymentTerms ?? 'N/A'),
//                     if (order.supplier?.address != null)
//                       _infoRow('Address:', order.supplier!.address!),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  ORDER INFO SECTION
//   // ─────────────────────────────────────────────────────────────────────────
//   static pw.Widget _buildOrderInfo(PurchaseOrderModel order) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         border: pw.Border.all(color: borderColor),
//         borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//       ),
//       child: pw.Row(
//         children: [
//           pw.Expanded(
//             child: _infoBox(
//               'Order Date',
//               _dateFormat.format(order.orderDate),
//               icon: Icons.calendar_today,
//             ),
//           ),
//           pw.Expanded(
//             child: _infoBox(
//               'Expected Delivery',
//               order.expectedDeliveryDate != null
//                   ? _dateFormat.format(order.expectedDeliveryDate!)
//                   : 'Not Set',
//               icon: Icons.event,
//             ),
//           ),
//           pw.Expanded(
//             child: _infoBox(
//               'Delivery Date',
//               order.deliveryDate != null
//                   ? _dateFormat.format(order.deliveryDate!)
//                   : 'Not Delivered',
//               icon: Icons.local_shipping,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   static pw.Widget _buildReceiptInfo(PurchaseReceiptModel receipt, PurchaseOrderModel order) {
//     return pw.Container(
//       padding: const pw.EdgeInsets.all(16),
//       decoration: pw.BoxDecoration(
//         color: bgLight,
//         border: pw.Border.all(color: borderColor),
//         borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//       ),
//       child: pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Row(
//             children: [
//               pw.Expanded(
//                 child: _infoBox(
//                   'Receipt Date',
//                   _dateTimeFormat.format(receipt.receiptDate),
//                   icon: Icons.calendar_today,
//                 ),
//               ),
//               pw.Expanded(
//                 child: _infoBox(
//                   'Reference PO',
//                   order.poNumber,
//                   icon: Icons.receipt,
//                 ),
//               ),
//               pw.Expanded(
//                 child: _infoBox(
//                   'Supplier',
//                   order.supplier?.name ?? 'N/A',
//                   icon: Icons.business,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   static pw.Widget _infoBox(String label, String value, {required pw.IconData icon}) {
//     return pw.Row(
//       children: [
//         pw.Icon(icon, size: 14, color: primaryColor),
//         pw.SizedBox(width: 8),
//         pw.Expanded(
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 label,
//                 style: pw.TextStyle(fontSize: 10, color: textMedium),
//               ),
//               pw.Text(
//                 value,
//                 style: pw.TextStyle(
//                   fontSize: 12,
//                   fontWeight: pw.FontWeight.bold,
//                   color: textDark,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  ITEMS TABLE
//   // ─────────────────────────────────────────────────────────────────────────
//   static pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
//     return pw.Container(
//       decoration: pw.BoxDecoration(
//         border: pw.Border.all(color: borderColor),
//         borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//       ),
//       child: pw.Column(
//         children: [
//           // Header
//           pw.Container(
//             padding: const pw.EdgeInsets.all(12),
//             decoration: pw.BoxDecoration(
//               color: primaryLight,
//               borderRadius: const pw.BorderRadius.only(
//                 topLeft: pw.Radius.circular(8),
//                 topRight: pw.Radius.circular(8),
//               ),
//             ),
//             child: pw.Row(
//               children: [
//                 pw.Expanded(flex: 1, child: pw.Text('#', style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 4, child: pw.Text('Product', style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 2, child: pw.Text('Unit Cost', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 2, child: pw.Text('Discount', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 2, child: pw.Text('Tax', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 3, child: pw.Text('Line Total', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
//               ],
//             ),
//           ),
//
//           // Items
//           ...items.asMap().entries.map((entry) {
//             final index = entry.key;
//             final item = entry.value;
//             final isEven = index.isEven;
//
//             return pw.Container(
//               padding: const pw.EdgeInsets.all(12),
//               decoration: pw.BoxDecoration(
//                 color: isEven ? white : bgLight,
//                 border: pw.Border(
//                   top: pw.BorderSide(color: borderColor),
//                 ),
//               ),
//               child: pw.Row(
//                 children: [
//                   pw.Expanded(flex: 1, child: pw.Text('${index + 1}', style: _tableCellStyle())),
//                   pw.Expanded(
//                     flex: 4,
//                     child: pw.Column(
//                       crossAxisAlignment: pw.CrossAxisAlignment.start,
//                       children: [
//                         pw.Text(
//                           item['product_name'] ?? 'Unknown',
//                           style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
//                         ),
//                         if (item['barcode'] != null)
//                           pw.Text(
//                             item['barcode'],
//                             style: pw.TextStyle(fontSize: 8, color: textMedium),
//                           ),
//                       ],
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 2,
//                     child: pw.Text(
//                       item['quantity'].toString(),
//                       textAlign: pw.TextAlign.center,
//                       style: _tableCellStyle(),
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 2,
//                     child: pw.Text(
//                       _currencyFormat.format(item['unit_cost']),
//                       textAlign: pw.TextAlign.right,
//                       style: _tableCellStyle(),
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 2,
//                     child: pw.Text(
//                       '${item['discount_percent']}%',
//                       textAlign: pw.TextAlign.right,
//                       style: _tableCellStyle(),
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 2,
//                     child: pw.Text(
//                       '${item['tax_percent']}%',
//                       textAlign: pw.TextAlign.right,
//                       style: _tableCellStyle(),
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 3,
//                     child: pw.Text(
//                       _currencyFormat.format(item['line_total']),
//                       textAlign: pw.TextAlign.right,
//                       style: pw.TextStyle(
//                         fontSize: 10,
//                         fontWeight: pw.FontWeight.bold,
//                         color: primaryColor,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }
//
//   static pw.Widget _buildReceiptItemsTable(List<Map<String, dynamic>> items) {
//     return pw.Container(
//       decoration: pw.BoxDecoration(
//         border: pw.Border.all(color: borderColor),
//         borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//       ),
//       child: pw.Column(
//         children: [
//           // Header
//           pw.Container(
//             padding: const pw.EdgeInsets.all(12),
//             decoration: pw.BoxDecoration(
//               color: primaryLight,
//               borderRadius: const pw.BorderRadius.only(
//                 topLeft: pw.Radius.circular(8),
//                 topRight: pw.Radius.circular(8),
//               ),
//             ),
//             child: pw.Row(
//               children: [
//                 pw.Expanded(flex: 1, child: pw.Text('#', style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 5, child: pw.Text('Product', style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 3, child: pw.Text('Unit Cost', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 3, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
//                 pw.Expanded(flex: 2, child: pw.Text('Batch', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
//               ],
//             ),
//           ),
//
//           // Items
//           ...items.asMap().entries.map((entry) {
//             final index = entry.key;
//             final item = entry.value;
//             final isEven = index.isEven;
//
//             return pw.Container(
//               padding: const pw.EdgeInsets.all(12),
//               decoration: pw.BoxDecoration(
//                 color: isEven ? white : bgLight,
//                 border: pw.Border(
//                   top: pw.BorderSide(color: borderColor),
//                 ),
//               ),
//               child: pw.Row(
//                 children: [
//                   pw.Expanded(flex: 1, child: pw.Text('${index + 1}', style: _tableCellStyle())),
//                   pw.Expanded(
//                     flex: 5,
//                     child: pw.Column(
//                       crossAxisAlignment: pw.CrossAxisAlignment.start,
//                       children: [
//                         pw.Text(
//                           item['product_name'] ?? 'Unknown',
//                           style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
//                         ),
//                         if (item['barcode'] != null)
//                           pw.Text(
//                             item['barcode'],
//                             style: pw.TextStyle(fontSize: 8, color: textMedium),
//                           ),
//                       ],
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 2,
//                     child: pw.Text(
//                       item['quantity'].toString(),
//                       textAlign: pw.TextAlign.center,
//                       style: _tableCellStyle(),
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 3,
//                     child: pw.Text(
//                       _currencyFormat.format(item['unit_cost']),
//                       textAlign: pw.TextAlign.right,
//                       style: _tableCellStyle(),
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 3,
//                     child: pw.Text(
//                       _currencyFormat.format(item['line_total']),
//                       textAlign: pw.TextAlign.right,
//                       style: pw.TextStyle(
//                         fontSize: 10,
//                         fontWeight: pw.FontWeight.bold,
//                         color: accentColor,
//                       ),
//                     ),
//                   ),
//                   pw.Expanded(
//                     flex: 2,
//                     child: pw.Text(
//                       item['batch_number'] ?? '-',
//                       textAlign: pw.TextAlign.right,
//                       style: _tableCellStyle(),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }
//
//   static pw.TextStyle _tableHeaderStyle() {
//     return pw.TextStyle(
//       fontSize: 10,
//       fontWeight: pw.FontWeight.bold,
//       color: textDark,
//     );
//   }
//
//   static pw.TextStyle _tableCellStyle() {
//     return const pw.TextStyle(fontSize: 10);
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  TOTALS SECTION
//   // ─────────────────────────────────────────────────────────────────────────
//   static pw.Widget _buildTotals(PurchaseOrderModel order) {
//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.end,
//       children: [
//         pw.Container(
//           width: 300,
//           padding: const pw.EdgeInsets.all(16),
//           decoration: pw.BoxDecoration(
//             color: bgLight,
//             border: pw.Border.all(color: borderColor),
//             borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//           ),
//           child: pw.Column(
//             children: [
//               _summaryRow('Subtotal:', _currencyFormat.format(order.subtotal)),
//               if (order.discountAmount > 0)
//                 _summaryRow(
//                   'Discount:',
//                   '-${_currencyFormat.format(order.discountAmount)}',
//                   color: accentColor,
//                 ),
//               if (order.taxAmount > 0)
//                 _summaryRow('Tax:', _currencyFormat.format(order.taxAmount)),
//               if (order.shippingCost > 0)
//                 _summaryRow('Shipping:', _currencyFormat.format(order.shippingCost)),
//               pw.Divider(height: 16, thickness: 1, color: borderColor),
//               _summaryRow(
//                 'Total:',
//                 _currencyFormat.format(order.totalAmount),
//                 isBold: true,
//                 fontSize: 14,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   static pw.Widget _buildReceiptTotals(PurchaseReceiptModel receipt, PurchaseOrderModel order) {
//     return pw.Row(
//       mainAxisAlignment: pw.MainAxisAlignment.end,
//       children: [
//         pw.Container(
//           width: 300,
//           padding: const pw.EdgeInsets.all(16),
//           decoration: pw.BoxDecoration(
//             color: bgLight,
//             border: pw.Border.all(color: borderColor),
//             borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//           ),
//           child: pw.Column(
//             children: [
//               _summaryRow('Receipt Total:', _currencyFormat.format(receipt.totalAmount)),
//               _summaryRow('PO Total:', _currencyFormat.format(order.totalAmount)),
//               if (receipt.totalAmount != order.totalAmount)
//                 _summaryRow(
//                   'Difference:',
//                   _currencyFormat.format(receipt.totalAmount - order.totalAmount),
//                   color: receipt.totalAmount > order.totalAmount ? dangerColor : accentColor,
//                 ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   static pw.Widget _summaryRow(
//       String label,
//       String value, {
//         bool isBold = false,
//         double fontSize = 12,
//         PdfColor? color,
//       }) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 2),
//       child: pw.Row(
//         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//         children: [
//           pw.Text(
//             label,
//             style: pw.TextStyle(
//               fontSize: fontSize,
//               fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
//               color: color ?? textMedium,
//             ),
//           ),
//           pw.Text(
//             value,
//             style: pw.TextStyle(
//               fontSize: fontSize,
//               fontWeight: pw.FontWeight.bold,
//               color: color ?? textDark,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  ADDITIONAL INFO SECTION
//   // ─────────────────────────────────────────────────────────────────────────
//   static pw.Widget _buildAdditionalInfo(PurchaseOrderModel order) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         if (order.notes != null && order.notes!.isNotEmpty) ...[
//           pw.Text(
//             'Notes',
//             style: pw.TextStyle(
//               fontSize: 14,
//               fontWeight: pw.FontWeight.bold,
//               color: primaryColor,
//             ),
//           ),
//           pw.SizedBox(height: 6),
//           pw.Container(
//             padding: const pw.EdgeInsets.all(12),
//             decoration: pw.BoxDecoration(
//               color: bgLight,
//               border: pw.Border.all(color: borderColor),
//               borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//             ),
//             child: pw.Text(order.notes!, style: const pw.TextStyle(fontSize: 10)),
//           ),
//           pw.SizedBox(height: 16),
//         ],
//         if (order.termsConditions != null && order.termsConditions!.isNotEmpty) ...[
//           pw.Text(
//             'Terms & Conditions',
//             style: pw.TextStyle(
//               fontSize: 14,
//               fontWeight: pw.FontWeight.bold,
//               color: primaryColor,
//             ),
//           ),
//           pw.SizedBox(height: 6),
//           pw.Container(
//             padding: const pw.EdgeInsets.all(12),
//             decoration: pw.BoxDecoration(
//               color: bgLight,
//               border: pw.Border.all(color: borderColor),
//               borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//             ),
//             child: pw.Text(order.termsConditions!, style: const pw.TextStyle(fontSize: 10)),
//           ),
//         ],
//       ],
//     );
//   }
//
//   static pw.Widget _buildReceiptNotes(PurchaseReceiptModel receipt) {
//     return pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Text(
//           'Receipt Notes',
//           style: pw.TextStyle(
//             fontSize: 14,
//             fontWeight: pw.FontWeight.bold,
//             color: accentColor,
//           ),
//         ),
//         pw.SizedBox(height: 6),
//         pw.Container(
//           padding: const pw.EdgeInsets.all(12),
//           decoration: pw.BoxDecoration(
//             color: bgLight,
//             border: pw.Border.all(color: borderColor),
//             borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//           ),
//           child: pw.Text(receipt.notes!, style: const pw.TextStyle(fontSize: 10)),
//         ),
//       ],
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  FOOTER
//   // ─────────────────────────────────────────────────────────────────────────
//   static pw.Widget _buildFooter() {
//     return pw.Column(
//       children: [
//         pw.Divider(thickness: 1, color: borderColor),
//         pw.SizedBox(height: 8),
//         pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Text(
//               'Authorized Signature',
//               style: pw.TextStyle(color: textLight, fontSize: 10),
//             ),
//             pw.Text(
//               'For Your Company Name',
//               style: pw.TextStyle(color: textLight, fontSize: 10),
//             ),
//           ],
//         ),
//         pw.SizedBox(height: 16),
//         pw.Center(
//           child: pw.Text(
//             'This is a computer generated document - valid without signature',
//             style: pw.TextStyle(
//               color: textLight,
//               fontSize: 9,
//               fontStyle: pw.FontStyle.italic,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  HELPER METHODS
//   // ─────────────────────────────────────────────────────────────────────────
//   static PdfColor _getStatusColor(String status) {
//     switch (status) {
//       case 'draft':
//         return PdfColors.grey;
//       case 'ordered':
//         return PdfColors.blue;
//       case 'partial':
//         return PdfColors.orange;
//       case 'received':
//         return PdfColors.green;
//       case 'cancelled':
//         return dangerColor;
//       default:
//         return PdfColors.grey;
//     }
//   }
//
//   static pw.Widget _infoRow(String label, String value) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.only(bottom: 4),
//       child: pw.Row(
//         children: [
//           pw.Text(
//             label,
//             style: pw.TextStyle(
//               fontSize: 10,
//               fontWeight: pw.FontWeight.bold,
//               color: textMedium,
//             ),
//           ),
//           pw.SizedBox(width: 8),
//           pw.Text(
//             value,
//             style: pw.TextStyle(fontSize: 10, color: textDark),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   //  PRINT / SHARE METHODS
//   // ─────────────────────────────────────────────────────────────────────────
//   static Future<void> printPdf(Uint8List pdfData) async {
//     await Printing.layoutPdf(onLayout: (_) async => pdfData);
//   }
//
//   static Future<void> sharePdf(Uint8List pdfData, String filename) async {
//     await Printing.sharePdf(bytes: pdfData, filename: filename);
//   }
//
//   static Future<void> generateAndPrintPurchaseOrder({
//     required PurchaseOrderModel order,
//     required List<Map<String, dynamic>> items,
//   }) async {
//     try {
//       final pdfData = await generatePurchaseOrderPdf(
//         order: order,
//         items: items,
//       );
//       await printPdf(pdfData);
//     } catch (e) {
//       print('Error printing purchase order: $e');
//       rethrow;
//     }
//   }
//
//   static Future<void> generateAndPrintPurchaseReceipt({
//     required PurchaseReceiptModel receipt,
//     required PurchaseOrderModel order,
//     required List<Map<String, dynamic>> items,
//   }) async {
//     try {
//       final pdfData = await generatePurchaseReceiptPdf(
//         receipt: receipt,
//         order: order,
//         items: items,
//       );
//       await printPdf(pdfData);
//     } catch (e) {
//       print('Error printing receipt: $e');
//       rethrow;
//     }
//   }
// }

// lib/services/purchase_pdf_generator.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/purchase_order_model.dart';
import 'CustomerPdfService.dart';

class PurchasePdfGenerator {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF7C3AED);
  static const PdfColor accentColor = PdfColor.fromInt(0xFF10B981);
  static const PdfColor dangerColor = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E1E2D);
  static const PdfColor textMedium = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor textLight = PdfColor.fromInt(0xFF9CA3AF);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFEEEEF5);
  static const PdfColor white = PdfColors.white;
  static const PdfColor bgLight = PdfColor.fromInt(0xFFF9FAFB);
  static const PdfColor primaryLight = PdfColor.fromInt(0xFFF3F0FD);

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Pkr ');

  // ─────────────────────────────────────────────────────────────────────────
  //  GENERATE PURCHASE ORDER PDF
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generatePurchaseOrderPdf({
    required PurchaseOrderModel order,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(order),
          pw.SizedBox(height: 20),
          _buildSupplierInfo(order),
          pw.SizedBox(height: 20),
          _buildOrderInfo(order),
          pw.SizedBox(height: 20),
          _buildItemsTable(items),
          pw.SizedBox(height: 20),
          _buildTotals(order),
          pw.SizedBox(height: 20),
          if (order.notes != null || order.termsConditions != null)
            _buildAdditionalInfo(order),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  GENERATE PURCHASE RECEIPT PDF
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generatePurchaseReceiptPdf({
    required PurchaseReceiptModel receipt,
    required PurchaseOrderModel order,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildReceiptHeader(receipt),
          pw.SizedBox(height: 20),
          _buildReceiptInfo(receipt, order),
          pw.SizedBox(height: 20),
          _buildReceiptItemsTable(items),
          pw.SizedBox(height: 20),
          _buildReceiptTotals(receipt, order),
          pw.SizedBox(height: 20),
          if (receipt.notes != null && receipt.notes!.isNotEmpty)
            _buildReceiptNotes(receipt),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HEADER SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(PurchaseOrderModel order) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PURCHASE ORDER',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.Text(
                order.poNumber,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(order.status).withOpacity(0.1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  order.statusText.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _getStatusColor(order.status),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'YOUR COMPANY NAME',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '123 Business Avenue, City',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Phone: +92 XXX XXXXXXX',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Email: purchases@company.com',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'GST: XX-XXXXXXX-X',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptHeader(PurchaseReceiptModel receipt) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'GOODS RECEIPT NOTE',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: accentColor,
                ),
              ),
              pw.Text(
                receipt.receiptNumber,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'YOUR COMPANY NAME',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '123 Business Avenue, City',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Phone: +92 XXX XXXXXXX',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Email: purchases@company.com',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SUPPLIER INFO SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildSupplierInfo(PurchaseOrderModel order) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: bgLight,
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Supplier Information',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Supplier Name:', order.supplier?.name ?? 'N/A'),
                    _infoRow('Contact:', order.supplier?.contact ?? 'N/A'),
                    _infoRow('Email:', order.supplier?.email ?? 'N/A'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Payment Terms:', order.paymentTerms ?? 'N/A'),
                    if (order.supplier?.address != null)
                      _infoRow('Address:', order.supplier!.address!),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ORDER INFO SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildOrderInfo(PurchaseOrderModel order) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _infoBox(
              'Order Date',
              _dateFormat.format(order.orderDate),
            ),
          ),
          // pw.Expanded(
          //   child: _infoBox(
          //     'Expected Delivery',
          //     order.expectedDeliveryDate != null
          //         ? _dateFormat.format(order.expectedDeliveryDate!)
          //         : 'Not Set',
          //   ),
          // ),
          // pw.Expanded(
          //   child: _infoBox(
          //     'Delivery Date',
          //     order.deliveryDate != null
          //         ? _dateFormat.format(order.deliveryDate!)
          //         : 'Not Delivered',
          //   ),
          // ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptInfo(PurchaseReceiptModel receipt, PurchaseOrderModel order) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: bgLight,
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _infoBox(
              'Receipt Date',
              _dateTimeFormat.format(receipt.receiptDate),
            ),
          ),
          pw.Expanded(
            child: _infoBox(
              'Reference PO',
              order.poNumber,
            ),
          ),
          pw.Expanded(
            child: _infoBox(
              'Supplier',
              order.supplier?.name ?? 'N/A',
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoBox(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: textMedium),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: textDark,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ITEMS TABLE
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: primaryLight,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 1, child: pw.Text('#', style: _tableHeaderStyle())),
                pw.Expanded(flex: 4, child: pw.Text('Product', style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Unit Cost', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Discount', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Tax', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
                pw.Expanded(flex: 3, child: pw.Text('Line Total', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
              ],
            ),
          ),

          // Items
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index.isEven;

            return pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: isEven ? white : bgLight,
                border: pw.Border(
                  top: pw.BorderSide(color: borderColor),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 1, child: pw.Text('${index + 1}', style: _tableCellStyle())),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item['product_name'] ?? 'Unknown',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                        if (item['barcode'] != null)
                          pw.Text(
                            item['barcode'],
                            style: pw.TextStyle(fontSize: 8, color: textMedium),
                          ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      item['quantity'].toString(),
                      textAlign: pw.TextAlign.center,
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      _currencyFormat.format(item['unit_cost']),
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '${item['discount_percent']}%',
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '${item['tax_percent']}%',
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      _currencyFormat.format(item['line_total']),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptItemsTable(List<Map<String, dynamic>> items) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: primaryLight,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 1, child: pw.Text('#', style: _tableHeaderStyle())),
                pw.Expanded(flex: 5, child: pw.Text('Product', style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: _tableHeaderStyle())),
                pw.Expanded(flex: 3, child: pw.Text('Unit Cost', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
                pw.Expanded(flex: 3, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Batch', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
              ],
            ),
          ),

          // Items
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isEven = index.isEven;

            return pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: isEven ? white : bgLight,
                border: pw.Border(
                  top: pw.BorderSide(color: borderColor),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 1, child: pw.Text('${index + 1}', style: _tableCellStyle())),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item['product_name'] ?? 'Unknown',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                        if (item['barcode'] != null)
                          pw.Text(
                            item['barcode'],
                            style: pw.TextStyle(fontSize: 8, color: textMedium),
                          ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      item['quantity'].toString(),
                      textAlign: pw.TextAlign.center,
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      _currencyFormat.format(item['unit_cost']),
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      _currencyFormat.format(item['line_total']),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      item['batch_number'] ?? '-',
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.TextStyle _tableHeaderStyle() {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: textDark,
    );
  }

  static pw.TextStyle _tableCellStyle() {
    return const pw.TextStyle(fontSize: 10);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TOTALS SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildTotals(PurchaseOrderModel order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 300,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: bgLight,
            border: pw.Border.all(color: borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            children: [
              _summaryRow('Subtotal:', _currencyFormat.format(order.subtotal)),
              if (order.discountAmount > 0)
                _summaryRow(
                  'Discount:',
                  '-${_currencyFormat.format(order.discountAmount)}',
                  color: accentColor,
                ),
              if (order.taxAmount > 0)
                _summaryRow('Tax:', _currencyFormat.format(order.taxAmount)),
              if (order.shippingCost > 0)
                _summaryRow('Shipping:', _currencyFormat.format(order.shippingCost)),
              pw.Divider(height: 16, thickness: 1, color: borderColor),
              _summaryRow(
                'Total:',
                _currencyFormat.format(order.totalAmount),
                isBold: true,
                fontSize: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptTotals(PurchaseReceiptModel receipt, PurchaseOrderModel order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 300,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: bgLight,
            border: pw.Border.all(color: borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            children: [
              _summaryRow('Receipt Total:', _currencyFormat.format(receipt.totalAmount)),
              _summaryRow('PO Total:', _currencyFormat.format(order.totalAmount)),
              if (receipt.totalAmount != order.totalAmount)
                _summaryRow(
                  'Difference:',
                  _currencyFormat.format((receipt.totalAmount - order.totalAmount).abs()),
                  color: receipt.totalAmount > order.totalAmount ? dangerColor : accentColor,
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryRow(
      String label,
      String value, {
        bool isBold = false,
        double fontSize = 12,
        PdfColor? color,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? textMedium,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: color ?? textDark,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ADDITIONAL INFO SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildAdditionalInfo(PurchaseOrderModel order) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          pw.Text(
            'Notes',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              border: pw.Border.all(color: borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(order.notes!, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.SizedBox(height: 16),
        ],
        if (order.termsConditions != null && order.termsConditions!.isNotEmpty) ...[
          pw.Text(
            'Terms & Conditions',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              border: pw.Border.all(color: borderColor),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(order.termsConditions!, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildReceiptNotes(PurchaseReceiptModel receipt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Receipt Notes',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: bgLight,
            border: pw.Border.all(color: borderColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Text(receipt.notes!, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FOOTER
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: borderColor),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Authorized Signature',
              style: pw.TextStyle(color: textLight, fontSize: 10),
            ),
            pw.Text(
              'For Your Company Name',
              style: pw.TextStyle(color: textLight, fontSize: 10),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text(
            'This is a computer generated document - valid without signature',
            style: pw.TextStyle(
              color: textLight,
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────
  static PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return PdfColors.grey;
      case 'ordered':
        return PdfColors.blue;
      case 'partial':
        return PdfColors.orange;
      case 'received':
        return PdfColors.green;
      case 'cancelled':
        return dangerColor;
      default:
        return PdfColors.grey;
    }
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: textMedium,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, color: textDark),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PRINT / SHARE METHODS
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> printPdf(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (_) async => pdfData);
  }

  static Future<void> sharePdf(Uint8List pdfData, String filename) async {
    await Printing.sharePdf(bytes: pdfData, filename: filename);
  }

  static Future<void> generateAndPrintPurchaseOrder({
    required PurchaseOrderModel order,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final pdfData = await generatePurchaseOrderPdf(
        order: order,
        items: items,
      );
      await printPdf(pdfData);
    } catch (e) {
      print('Error printing purchase order: $e');
      rethrow;
    }
  }

  static Future<void> generateAndPrintPurchaseReceipt({
    required PurchaseReceiptModel receipt,
    required PurchaseOrderModel order,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final pdfData = await generatePurchaseReceiptPdf(
        receipt: receipt,
        order: order,
        items: items,
      );
      await printPdf(pdfData);
    } catch (e) {
      print('Error printing receipt: $e');
      rethrow;
    }
  }
}