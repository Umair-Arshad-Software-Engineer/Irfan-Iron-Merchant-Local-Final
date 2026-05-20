import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/supplier.dart';

class PdfService {
  static const PdfColor primaryGreen = PdfColor.fromInt(0xFF10B981);
  static const PdfColor darkGreen = PdfColor.fromInt(0xFF059669);
  static const PdfColor lightGreen = PdfColor.fromInt(0xFFD1FAE5);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor textMedium = PdfColor.fromInt(0xFF4B5563);
  static const PdfColor textLight = PdfColor.fromInt(0xFF9CA3AF);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFE5E7EB);

  static final _df = DateFormat('MMM dd, yyyy');
  static final _dtf = DateFormat('MMM dd, yyyy • hh:mm a');
  static final _cf = NumberFormat('#,##0.00');

  // Generate PDF document
  static Future<pw.Document> _generatePdfDocument({
    required Supplier supplier,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(supplier, fontBold),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          _buildTitle(supplier, filterMethod, dateRange, fontBold),
          pw.SizedBox(height: 20),
          _buildSummaryCards(payments.length, totalPaid, font, fontBold),
          pw.SizedBox(height: 24),
          _buildPaymentsTable(payments, font, fontBold),
          pw.SizedBox(height: 20),
          _buildSignatureSection(font),
          pw.SizedBox(height: 10),
          _buildDisclaimer(font),
        ],
      ),
    );

    return pdf;
  }

  // Generate and share PDF
  static Future<void> generatePaymentReport({
    required Supplier supplier,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
  }) async {
    try {
      final pdf = await _generatePdfDocument(
        supplier: supplier,
        payments: payments,
        totalPaid: totalPaid,
        filterMethod: filterMethod,
        dateRange: dateRange,
      );

      await _sharePdf(pdf, supplier);
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      rethrow;
    }
  }

  // Generate and download PDF
  static Future<String?> downloadPaymentReport({
    required Supplier supplier,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
    required BuildContext context,
  }) async {
    try {
      // Check and request storage permission for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            _showSnackBar(context, 'Storage permission is required to download PDF', isError: true);
            return null;
          }
        }
      }

      final pdf = await _generatePdfDocument(
        supplier: supplier,
        payments: payments,
        totalPaid: totalPaid,
        filterMethod: filterMethod,
        dateRange: dateRange,
      );

      return await _savePdfToDownloads(pdf, supplier, context);
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      _showSnackBar(context, 'Error downloading PDF: $e', isError: true);
      rethrow;
    }
  }

  // Preview PDF
  static Future<void> previewPdf({
    required Supplier supplier,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
  }) async {
    try {
      final pdf = await _generatePdfDocument(
        supplier: supplier,
        payments: payments,
        totalPaid: totalPaid,
        filterMethod: filterMethod,
        dateRange: dateRange,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Payment_Report_${supplier.name}',
      );
    } catch (e) {
      debugPrint('Error previewing PDF: $e');
      rethrow;
    }
  }

  // Save PDF to Downloads folder
  static Future<String?> _savePdfToDownloads(
      pw.Document pdf,
      Supplier supplier,
      BuildContext context,
      ) async {
    try {
      final bytes = await pdf.save();

      // For Android 10+ and all iOS, use getExternalStorageDirectory
      // For older Android, you might need different approach
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        // Try to get the Downloads directory
        downloadsDir = Directory('/storage/emulated/0/Download');

        // If not accessible, fallback to external storage directory
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        // For iOS, use documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        _showSnackBar(context, 'Could not access downloads folder', isError: true);
        return null;
      }

      // Create filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Payment_Report_${supplier.name.replaceAll(' ', '_')}_$timestamp.pdf';
      final file = File('${downloadsDir.path}/$fileName');

      await file.writeAsBytes(bytes);

      _showSnackBar(context, 'PDF downloaded successfully to Downloads folder');
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      _showSnackBar(context, 'Error saving PDF: $e', isError: true);
      rethrow;
    }
  }

  // Share PDF
  static Future<void> _sharePdf(pw.Document pdf, Supplier supplier) async {
    try {
      final bytes = await pdf.save();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Payment_Report_${supplier.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Supplier Payment Report',
        );
      } catch (e) {
        debugPrint('Share error: $e');
        // Fallback - show file location
        debugPrint('PDF saved at: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      rethrow;
    }
  }

  // Helper method to show snackbar
  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Helper method to show download options
  static Future<void> showDownloadOptions({
    required BuildContext context,
    required Supplier supplier,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Payment Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              supplier.name,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B981)),
              ),
              title: const Text('Preview PDF'),
              subtitle: const Text('View before saving'),
              onTap: () async {
                Navigator.pop(context);
                await previewPdf(
                  supplier: supplier,
                  payments: payments,
                  totalPaid: totalPaid,
                  filterMethod: filterMethod,
                  dateRange: dateRange,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share, color: Color(0xFF10B981)),
              ),
              title: const Text('Share PDF'),
              subtitle: const Text('Share via email, messaging, etc.'),
              onTap: () async {
                Navigator.pop(context);
                await generatePaymentReport(
                  supplier: supplier,
                  payments: payments,
                  totalPaid: totalPaid,
                  filterMethod: filterMethod,
                  dateRange: dateRange,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.download, color: Color(0xFF10B981)),
              ),
              title: const Text('Download PDF'),
              subtitle: Text(
                  Platform.isAndroid
                      ? 'Save to Downloads folder'
                      : 'Save to Documents folder'
              ),
              onTap: () async {
                Navigator.pop(context);
                final filePath = await downloadPaymentReport(
                  supplier: supplier,
                  payments: payments,
                  totalPaid: totalPaid,
                  filterMethod: filterMethod,
                  dateRange: dateRange,
                  context: context,
                );
                if (filePath != null) {
                  debugPrint('PDF downloaded to: $filePath');
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // All the existing building methods remain the same...
  static pw.Widget _buildHeader(Supplier supplier, pw.Font fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primaryGreen, width: 2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SUPPLIER PAYMENT REPORT',
                style: pw.TextStyle(font: fontBold, fontSize: 16, color: primaryGreen),
              ),
              pw.Text(
                'Generated on ${_dtf.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: textLight),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: lightGreen,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              supplier.name.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 12, color: darkGreen),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'This is a computer-generated document',
            style: pw.TextStyle(fontSize: 8, color: textLight, font: font),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: textLight, font: font),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTitle(
      Supplier supplier,
      String filterMethod,
      DateTimeRange? dateRange,
      pw.Font fontBold,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          supplier.name,
          style: pw.TextStyle(font: fontBold, fontSize: 24, color: textDark),
        ),
        pw.Text(
          supplier.address ?? 'No address provided',
          style: pw.TextStyle(fontSize: 10, color: textMedium),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${supplier.contact}',
          style: pw.TextStyle(fontSize: 10, color: textMedium),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _buildFilterChip('Payment Method: ${_getMethodLabel(filterMethod)}'),
            if (dateRange != null) ...[
              pw.SizedBox(width: 8),
              _buildFilterChip(
                  'Period: ${_df.format(dateRange.start)} - ${_df.format(dateRange.end)}'),
            ],
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFilterChip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: lightGreen,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, color: darkGreen),
      ),
    );
  }

  static pw.Widget _buildSummaryCards(
      int paymentCount,
      double totalPaid,
      pw.Font font,
      pw.Font fontBold,
      ) {
    return pw.Row(
      children: [
        _buildSummaryCard(
          label: 'Total Payments',
          value: paymentCount.toString(),
          color: primaryGreen,
          font: font,
          fontBold: fontBold,
        ),
        pw.SizedBox(width: 16),
        _buildSummaryCard(
          label: 'Total Paid',
          value: 'Rs ${_cf.format(totalPaid)}',
          color: darkGreen,
          font: font,
          fontBold: fontBold,
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCard({
    required String label,
    required String value,
    required PdfColor color,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0x1A10B981), // 10% opacity
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: color),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 32,
              height: 32,
              decoration: pw.BoxDecoration(
                color: color,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text(
                  label == 'Total Payments' ? '#' : 'Rs',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    font: fontBold,
                  ),
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 10, color: textMedium, font: font),
                ),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPaymentsTable(
      List<Map<String, dynamic>> payments,
      pw.Font font,
      pw.Font fontBold,
      ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: primaryGreen,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                _buildHeaderCell('Date', flex: 2, fontBold: fontBold),
                _buildHeaderCell('Method', flex: 1, fontBold: fontBold),
                _buildHeaderCell('Reference', flex: 2, fontBold: fontBold),
                _buildHeaderCell('Bank/Chq', flex: 2, fontBold: fontBold),
                _buildHeaderCell('Amount', flex: 1, fontBold: fontBold, align: pw.TextAlign.right),
              ],
            ),
          ),
          ...payments.asMap().entries.map((entry) {
            final index = entry.key;
            final payment = entry.value;
            final isEven = index % 2 == 0;

            return pw.Container(
              padding: const pw.EdgeInsets.all(12),
              color: isEven ? null : PdfColor.fromInt(0x1AD1FAE5),
              child: pw.Row(
                children: [
                  _buildCell(
                    _formatDate(payment['transaction_date']),
                    flex: 2,
                    font: font,
                  ),
                  _buildCell(
                    payment['payment_method']?.toString().toUpperCase() ?? '—',
                    flex: 1,
                    font: font,
                  ),
                  _buildCell(
                    payment['reference_number']?.toString() ?? '—',
                    flex: 2,
                    font: font,
                  ),
                  _buildCell(
                    _formatBankInfo(payment),
                    flex: 2,
                    font: font,
                  ),
                  _buildCell(
                    'Rs ${_cf.format(double.tryParse(payment['debit']?.toString() ?? '0') ?? 0)}',
                    flex: 1,
                    font: fontBold,
                    align: pw.TextAlign.right,
                    color: primaryGreen,
                  ),
                ],
              ),
            );
          }).toList(),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor)),
              color: lightGreen,
            ),
            child: pw.Row(
              children: [
                _buildCell('', flex: 5, font: font),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Total:',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Rs ${_cf.format(_calculateTotal(payments))}',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: primaryGreen,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderCell(
      String text, {
        required int flex,
        required pw.Font fontBold,
        pw.TextAlign align = pw.TextAlign.left,
      }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 10,
          color: PdfColors.white,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildCell(
      String text, {
        required int flex,
        required pw.Font font,
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor? color,
      }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: color ?? textDark,
        ),
        textAlign: align,
        maxLines: 2,
      ),
    );
  }

  static pw.Widget _buildSignatureSection(pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('_________________________',
                style: pw.TextStyle(fontSize: 12, color: textLight)),
            pw.Text('Authorized Signature',
                style: pw.TextStyle(fontSize: 8, color: textLight, font: font)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('_________________________',
                style: pw.TextStyle(fontSize: 12, color: textLight)),
            pw.Text('Supplier Acknowledgment',
                style: pw.TextStyle(fontSize: 8, color: textLight, font: font)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDisclaimer(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x1AD1FAE5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'This payment report is system generated and does not require a physical signature. '
            'All amounts are in Pakistani Rupees (Rs). For any discrepancies, please contact support.',
        style: pw.TextStyle(fontSize: 7, color: textMedium, font: font),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      return _df.format(DateTime.parse(date.toString()));
    } catch (e) {
      return '—';
    }
  }

  static String _formatBankInfo(Map<String, dynamic> payment) {
    final buffer = <String>[];
    if (payment['bank_name'] != null) {
      buffer.add(payment['bank_name'].toString());
    }
    if (payment['cheque_number'] != null) {
      buffer.add('Chq# ${payment['cheque_number']}');
    }
    return buffer.isNotEmpty ? buffer.join(' • ') : '—';
  }

  static double _calculateTotal(List<Map<String, dynamic>> payments) {
    double total = 0;
    for (final p in payments) {
      total += double.tryParse(p['debit']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  static String _getMethodLabel(String method) {
    const labels = {
      'all': 'All Methods',
      'cash': 'Cash',
      'bank': 'Bank Transfer',
      'cheque': 'Cheque',
      'slip': 'Pay Slip',
    };
    return labels[method.toLowerCase()] ?? method;
  }
}