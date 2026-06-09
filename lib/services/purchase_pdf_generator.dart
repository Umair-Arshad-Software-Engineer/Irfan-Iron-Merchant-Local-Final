import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/purchase_order_model.dart';
import '../providers/lanprovider.dart';
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
  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ');

  // ─────────────────────────────────────────────────────────────────────────
  //  GENERATE PURCHASE ORDER PDF
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generatePurchaseOrderPdf({
    required PurchaseOrderModel order,
    required List<Map<String, dynamic>> items,
    required LanguageProvider languageProvider,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(order, languageProvider),
          pw.SizedBox(height: 20),
          _buildSupplierInfo(order, languageProvider),
          pw.SizedBox(height: 20),
          _buildOrderInfo(order, languageProvider),
          pw.SizedBox(height: 20),
          _buildItemsTable(items, languageProvider),
          pw.SizedBox(height: 20),
          _buildTotals(order, languageProvider),
          pw.SizedBox(height: 20),
          if (order.notes != null || order.termsConditions != null)
            _buildAdditionalInfo(order, languageProvider),
          pw.SizedBox(height: 20),
          _buildFooter(languageProvider),
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
    required LanguageProvider languageProvider,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildReceiptHeader(receipt, languageProvider),
          pw.SizedBox(height: 20),
          _buildReceiptInfo(receipt, order, languageProvider),
          pw.SizedBox(height: 20),
          _buildReceiptItemsTable(items, languageProvider),
          pw.SizedBox(height: 20),
          _buildReceiptTotals(receipt, order, languageProvider),
          pw.SizedBox(height: 20),
          if (receipt.notes != null && receipt.notes!.isNotEmpty)
            _buildReceiptNotes(receipt, languageProvider),
          pw.SizedBox(height: 20),
          _buildFooter(languageProvider),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HEADER SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(PurchaseOrderModel order, LanguageProvider lp) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                lp.isEnglish ? 'PURCHASE ORDER' : 'پرچیز آرڈر',
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
                  _getStatusText(order.status, lp).toUpperCase(),
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
                lp.isEnglish ? 'YOUR COMPANY NAME' : 'آپ کی کمپنی کا نام',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                lp.isEnglish ? '123 Business Avenue, City' : '123 بزنس ایونیو, شہر',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                lp.isEnglish ? 'Phone: +92 XXX XXXXXXX' : 'فون: +92 XXX XXXXXXX',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                lp.isEnglish ? 'Email: purchases@company.com' : 'ای میل: purchases@company.com',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                lp.isEnglish ? 'GST: XX-XXXXXXX-X' : 'جی ایس ٹی: XX-XXXXXXX-X',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptHeader(PurchaseReceiptModel receipt, LanguageProvider lp) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                lp.isEnglish ? 'GOODS RECEIPT NOTE' : 'مال موصولی نوٹ',
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
                lp.isEnglish ? 'YOUR COMPANY NAME' : 'آپ کی کمپنی کا نام',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                lp.isEnglish ? '123 Business Avenue, City' : '123 بزنس ایونیو, شہر',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                lp.isEnglish ? 'Phone: +92 XXX XXXXXXX' : 'فون: +92 XXX XXXXXXX',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                lp.isEnglish ? 'Email: purchases@company.com' : 'ای میل: purchases@company.com',
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
  static pw.Widget _buildSupplierInfo(PurchaseOrderModel order, LanguageProvider lp) {
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
            lp.isEnglish ? 'Supplier Information' : 'سپلائر کی معلومات',
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
                    _infoRow(lp.isEnglish ? 'Supplier Name:' : 'سپلائر کا نام:', order.supplier?.name ?? 'N/A', lp),
                    _infoRow(lp.isEnglish ? 'Contact:' : 'رابطہ:', order.supplier?.contact ?? 'N/A', lp),
                    _infoRow(lp.isEnglish ? 'Email:' : 'ای میل:', order.supplier?.email ?? 'N/A', lp),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow(lp.isEnglish ? 'Payment Terms:' : 'ادائیگی کی شرائط:', order.paymentTerms ?? 'N/A', lp),
                    if (order.supplier?.address != null)
                      _infoRow(lp.isEnglish ? 'Address:' : 'پتہ:', order.supplier!.address!, lp),
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
  static pw.Widget _buildOrderInfo(PurchaseOrderModel order, LanguageProvider lp) {
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
              lp.isEnglish ? 'Order Date' : 'آرڈر کی تاریخ',
              _dateFormat.format(order.orderDate),
              lp,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptInfo(PurchaseReceiptModel receipt, PurchaseOrderModel order, LanguageProvider lp) {
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
              lp.isEnglish ? 'Receipt Date' : 'رسید کی تاریخ',
              _dateTimeFormat.format(receipt.receiptDate),
              lp,
            ),
          ),
          pw.Expanded(
            child: _infoBox(
              lp.isEnglish ? 'Reference PO' : 'حوالہ PO',
              order.poNumber,
              lp,
            ),
          ),
          pw.Expanded(
            child: _infoBox(
              lp.isEnglish ? 'Supplier' : 'سپلائر',
              order.supplier?.name ?? 'N/A',
              lp,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoBox(String label, String value, LanguageProvider lp) {
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
  static pw.Widget _buildItemsTable(List<Map<String, dynamic>> items, LanguageProvider lp) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
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
                pw.Expanded(flex: 1, child: pw.Text('#', style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 4, child: pw.Text(lp.isEnglish ? 'Product' : 'پروڈکٹ', style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 2, child: pw.Text(lp.isEnglish ? 'Qty' : 'مقدار', textAlign: pw.TextAlign.center, style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 2, child: pw.Text(lp.isEnglish ? 'Unit Cost' : 'فی یونٹ لاگت', textAlign: pw.TextAlign.right, style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 2, child: pw.Text(lp.isEnglish ? 'Discount' : 'چھوٹ', textAlign: pw.TextAlign.right, style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 2, child: pw.Text(lp.isEnglish ? 'Tax' : 'ٹیکس', textAlign: pw.TextAlign.right, style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 3, child: pw.Text(lp.isEnglish ? 'Line Total' : 'لائن کل', textAlign: pw.TextAlign.right, style: _tableHeaderStyle(lp))),
              ],
            ),
          ),

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
                  pw.Expanded(flex: 1, child: pw.Text('${index + 1}', style: _tableCellStyle(lp))),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item['product_name'] ?? (lp.isEnglish ? 'Unknown' : 'نامعلوم'),
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
                      style: _tableCellStyle(lp),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      _currencyFormat.format(item['unit_cost']),
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(lp),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '${item['discount_percent']}%',
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(lp),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '${item['tax_percent']}%',
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(lp),
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

  static pw.Widget _buildReceiptItemsTable(List<Map<String, dynamic>> items, LanguageProvider lp) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
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
                pw.Expanded(flex: 1, child: pw.Text('#', style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 5, child: pw.Text(lp.isEnglish ? 'Product' : 'پروڈکٹ', style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 2, child: pw.Text(lp.isEnglish ? 'Qty' : 'مقدار', textAlign: pw.TextAlign.center, style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 3, child: pw.Text(lp.isEnglish ? 'Unit Cost' : 'فی یونٹ لاگت', textAlign: pw.TextAlign.right, style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 3, child: pw.Text(lp.isEnglish ? 'Total' : 'کل', textAlign: pw.TextAlign.right, style: _tableHeaderStyle(lp))),
                pw.Expanded(flex: 2, child: pw.Text(lp.isEnglish ? 'Batch' : 'بیچ', textAlign: pw.TextAlign.right, style: _tableHeaderStyle(lp))),
              ],
            ),
          ),

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
                  pw.Expanded(flex: 1, child: pw.Text('${index + 1}', style: _tableCellStyle(lp))),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item['product_name'] ?? (lp.isEnglish ? 'Unknown' : 'نامعلوم'),
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
                      style: _tableCellStyle(lp),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      _currencyFormat.format(item['unit_cost']),
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(lp),
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
                      style: _tableCellStyle(lp),
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

  static pw.TextStyle _tableHeaderStyle(LanguageProvider lp) {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: textDark,
    );
  }

  static pw.TextStyle _tableCellStyle(LanguageProvider lp) {
    return const pw.TextStyle(fontSize: 10);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TOTALS SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildTotals(PurchaseOrderModel order, LanguageProvider lp) {
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
              _summaryRow(lp.isEnglish ? 'Subtotal:' : 'ذیلی کل:', _currencyFormat.format(order.subtotal), lp: lp),
              if (order.discountAmount > 0)
                _summaryRow(
                  lp.isEnglish ? 'Discount:' : 'چھوٹ:',
                  '-${_currencyFormat.format(order.discountAmount)}',
                  color: accentColor,
                  lp: lp,
                ),
              if (order.taxAmount > 0)
                _summaryRow(lp.isEnglish ? 'Tax:' : 'ٹیکس:', _currencyFormat.format(order.taxAmount), lp: lp),
              if (order.shippingCost > 0)
                _summaryRow(lp.isEnglish ? 'Shipping:' : 'شپنگ:', _currencyFormat.format(order.shippingCost), lp: lp),
              pw.Divider(height: 16, thickness: 1, color: borderColor),
              _summaryRow(
                lp.isEnglish ? 'Total:' : 'کل:',
                _currencyFormat.format(order.totalAmount),
                isBold: true,
                fontSize: 14,
                lp: lp,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptTotals(PurchaseReceiptModel receipt, PurchaseOrderModel order, LanguageProvider lp) {
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
              _summaryRow(lp.isEnglish ? 'Receipt Total:' : 'رسید کل:', _currencyFormat.format(receipt.totalAmount), lp: lp),
              _summaryRow(lp.isEnglish ? 'PO Total:' : 'PO کل:', _currencyFormat.format(order.totalAmount), lp: lp),
              if (receipt.totalAmount != order.totalAmount)
                _summaryRow(
                  lp.isEnglish ? 'Difference:' : 'فرق:',
                  _currencyFormat.format((receipt.totalAmount - order.totalAmount).abs()),
                  color: receipt.totalAmount > order.totalAmount ? dangerColor : accentColor,
                  lp: lp,
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
        required LanguageProvider lp,
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
  static pw.Widget _buildAdditionalInfo(PurchaseOrderModel order, LanguageProvider lp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          pw.Text(
            lp.isEnglish ? 'Notes' : 'نوٹس',
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
            lp.isEnglish ? 'Terms & Conditions' : 'شرائط و ضوابط',
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

  static pw.Widget _buildReceiptNotes(PurchaseReceiptModel receipt, LanguageProvider lp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          lp.isEnglish ? 'Receipt Notes' : 'رسید کے نوٹس',
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
  static pw.Widget _buildFooter(LanguageProvider lp) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: borderColor),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              lp.isEnglish ? 'Authorized Signature' : 'مجاز دستخط',
              style: pw.TextStyle(color: textLight, fontSize: 10),
            ),
            pw.Text(
              lp.isEnglish ? 'For Your Company Name' : 'آپ کی کمپنی کے لیے',
              style: pw.TextStyle(color: textLight, fontSize: 10),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text(
            lp.isEnglish
                ? 'This is a computer generated document - valid without signature'
                : 'یہ کمپیوٹر سے تیار کردہ دستاویز ہے - دستخط کے بغیر درست',
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
  static String _getStatusText(String status, LanguageProvider lp) {
    switch (status) {
      case 'draft':
        return lp.isEnglish ? 'Draft' : 'ڈرافٹ';
      case 'ordered':
        return lp.isEnglish ? 'Ordered' : 'آرڈر شدہ';
      case 'partial':
        return lp.isEnglish ? 'Partial' : 'جزوی';
      case 'received':
        return lp.isEnglish ? 'Received' : 'موصول شدہ';
      case 'cancelled':
        return lp.isEnglish ? 'Cancelled' : 'منسوخ شدہ';
      default:
        return status;
    }
  }

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

  static pw.Widget _infoRow(String label, String value, LanguageProvider lp) {
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
    required LanguageProvider languageProvider,
  }) async {
    try {
      final pdfData = await generatePurchaseOrderPdf(
        order: order,
        items: items,
        languageProvider: languageProvider,
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
    required LanguageProvider languageProvider,
  }) async {
    try {
      final pdfData = await generatePurchaseReceiptPdf(
        receipt: receipt,
        order: order,
        items: items,
        languageProvider: languageProvider,
      );
      await printPdf(pdfData);
    } catch (e) {
      print('Error printing receipt: $e');
      rethrow;
    }
  }
}