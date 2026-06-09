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
import '../providers/lanprovider.dart';

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
    required LanguageProvider languageProvider,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(supplier, fontBold, languageProvider),
        footer: (context) => _buildFooter(context, font, languageProvider),
        build: (context) => [
          _buildTitle(supplier, filterMethod, dateRange, fontBold, languageProvider),
          pw.SizedBox(height: 20),
          _buildSummaryCards(payments.length, totalPaid, font, fontBold, languageProvider),
          pw.SizedBox(height: 24),
          _buildPaymentsTable(payments, font, fontBold, languageProvider),
          pw.SizedBox(height: 20),
          _buildSignatureSection(font, languageProvider),
          pw.SizedBox(height: 10),
          _buildDisclaimer(font, languageProvider),
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
    required LanguageProvider languageProvider,
  }) async {
    try {
      final pdf = await _generatePdfDocument(
        supplier: supplier,
        payments: payments,
        totalPaid: totalPaid,
        filterMethod: filterMethod,
        dateRange: dateRange,
        languageProvider: languageProvider,
      );

      await _sharePdf(pdf, supplier, languageProvider);
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
    required LanguageProvider languageProvider,
  }) async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            _showSnackBar(context, languageProvider.isEnglish ? 'Storage permission is required to download PDF' : 'PDF ڈاؤن لوڈ کرنے کے لیے اسٹوریج کی اجازت درکار ہے', isError: true);
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
        languageProvider: languageProvider,
      );

      return await _savePdfToDownloads(pdf, supplier, context, languageProvider);
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      _showSnackBar(context, '${languageProvider.isEnglish ? 'Error downloading PDF' : 'PDF ڈاؤن لوڈ کرنے میں خرابی'}: $e', isError: true);
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
    required LanguageProvider languageProvider,
  }) async {
    try {
      final pdf = await _generatePdfDocument(
        supplier: supplier,
        payments: payments,
        totalPaid: totalPaid,
        filterMethod: filterMethod,
        dateRange: dateRange,
        languageProvider: languageProvider,
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
      LanguageProvider languageProvider,
      ) async {
    try {
      final bytes = await pdf.save();

      Directory? downloadsDir;

      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');

        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        _showSnackBar(context, languageProvider.isEnglish ? 'Could not access downloads folder' : 'ڈاؤن لوڈ فولڈر تک رسائی نہیں ہو سکی', isError: true);
        return null;
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Payment_Report_${supplier.name.replaceAll(' ', '_')}_$timestamp.pdf';
      final file = File('${downloadsDir.path}/$fileName');

      await file.writeAsBytes(bytes);

      _showSnackBar(context, languageProvider.isEnglish ? 'PDF downloaded successfully to Downloads folder' : 'PDF کامیابی سے ڈاؤن لوڈ فولڈر میں ڈاؤن لوڈ ہوگئی');
      return file.path;
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      _showSnackBar(context, '${languageProvider.isEnglish ? 'Error saving PDF' : 'PDF محفوظ کرنے میں خرابی'}: $e', isError: true);
      rethrow;
    }
  }

  // Share PDF
  static Future<void> _sharePdf(pw.Document pdf, Supplier supplier, LanguageProvider languageProvider) async {
    try {
      final bytes = await pdf.save();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Payment_Report_${supplier.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: languageProvider.isEnglish ? 'Supplier Payment Report' : 'سپلائر ادائیگی رپورٹ',
        );
      } catch (e) {
        debugPrint('Share error: $e');
        debugPrint('PDF saved at: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      rethrow;
    }
  }

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

  static Future<void> showDownloadOptions({
    required BuildContext context,
    required Supplier supplier,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
    required LanguageProvider languageProvider,
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
            Text(
              languageProvider.isEnglish ? 'Export Payment Report' : 'ادائیگی رپورٹ ایکسپورٹ کریں',
              style: const TextStyle(
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
              title: Text(languageProvider.isEnglish ? 'Preview PDF' : 'PDF دیکھیں'),
              subtitle: Text(languageProvider.isEnglish ? 'View before saving' : 'محفوظ کرنے سے پہلے دیکھیں'),
              onTap: () async {
                Navigator.pop(context);
                await previewPdf(
                  supplier: supplier,
                  payments: payments,
                  totalPaid: totalPaid,
                  filterMethod: filterMethod,
                  dateRange: dateRange,
                  languageProvider: languageProvider,
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
              title: Text(languageProvider.isEnglish ? 'Share PDF' : 'PDF شیئر کریں'),
              subtitle: Text(languageProvider.isEnglish ? 'Share via email, messaging, etc.' : 'ای میل، میسجنگ وغیرہ کے ذریعے شیئر کریں'),
              onTap: () async {
                Navigator.pop(context);
                await generatePaymentReport(
                  supplier: supplier,
                  payments: payments,
                  totalPaid: totalPaid,
                  filterMethod: filterMethod,
                  dateRange: dateRange,
                  languageProvider: languageProvider,
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
              title: Text(languageProvider.isEnglish ? 'Download PDF' : 'PDF ڈاؤن لوڈ کریں'),
              subtitle: Text(
                  Platform.isAndroid
                      ? (languageProvider.isEnglish ? 'Save to Downloads folder' : 'ڈاؤن لوڈ فولڈر میں محفوظ کریں')
                      : (languageProvider.isEnglish ? 'Save to Documents folder' : 'دستاویزات فولڈر میں محفوظ کریں')
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
                  languageProvider: languageProvider,
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

  static pw.Widget _buildHeader(Supplier supplier, pw.Font fontBold, LanguageProvider languageProvider) {
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
                languageProvider.isEnglish ? 'SUPPLIER PAYMENT REPORT' : 'سپلائر ادائیگی رپورٹ',
                style: pw.TextStyle(font: fontBold, fontSize: 16, color: primaryGreen),
              ),
              pw.Text(
                languageProvider.isEnglish
                    ? 'Generated on ${_dtf.format(DateTime.now())}'
                    : 'تیار کردہ: ${_dtf.format(DateTime.now())}',
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

  static pw.Widget _buildFooter(pw.Context context, pw.Font font, LanguageProvider languageProvider) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            languageProvider.isEnglish ? 'This is a computer-generated document' : 'یہ کمپیوٹر سے تیار کردہ دستاویز ہے',
            style: pw.TextStyle(fontSize: 8, color: textLight, font: font),
          ),
          pw.Text(
            languageProvider.isEnglish ? 'Page ${context.pageNumber} of ${context.pagesCount}' : 'صفحہ ${context.pageNumber} / ${context.pagesCount}',
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
      LanguageProvider languageProvider,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          supplier.name,
          style: pw.TextStyle(font: fontBold, fontSize: 24, color: textDark),
        ),
        pw.Text(
          supplier.address ?? (languageProvider.isEnglish ? 'No address provided' : 'کوئی پتہ فراہم نہیں کیا گیا'),
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
            _buildFilterChip('${languageProvider.isEnglish ? 'Payment Method' : 'ادائیگی کا طریقہ'}: ${_getMethodLabel(filterMethod, languageProvider)}'),
            if (dateRange != null) ...[
              pw.SizedBox(width: 8),
              _buildFilterChip(
                  '${languageProvider.isEnglish ? 'Period' : 'مدت'}: ${_df.format(dateRange.start)} - ${_df.format(dateRange.end)}'),
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
      LanguageProvider languageProvider,
      ) {
    return pw.Row(
      children: [
        _buildSummaryCard(
          label: languageProvider.isEnglish ? 'Total Payments' : 'کل ادائیگیاں',
          value: paymentCount.toString(),
          color: primaryGreen,
          font: font,
          fontBold: fontBold,
        ),
        pw.SizedBox(width: 16),
        _buildSummaryCard(
          label: languageProvider.isEnglish ? 'Total Paid' : 'کل ادا شدہ',
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
          color: PdfColor.fromInt(0x1A10B981),
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
                  label == 'Total Payments' || label == 'کل ادائیگیاں' ? '#' : 'Rs',
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
      LanguageProvider languageProvider,
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
                _buildHeaderCell(languageProvider.isEnglish ? 'Date' : 'تاریخ', flex: 2, fontBold: fontBold),
                _buildHeaderCell(languageProvider.isEnglish ? 'Method' : 'طریقہ', flex: 1, fontBold: fontBold),
                _buildHeaderCell(languageProvider.isEnglish ? 'Reference' : 'حوالہ', flex: 2, fontBold: fontBold),
                _buildHeaderCell(languageProvider.isEnglish ? 'Bank/Chq' : 'بینک/چیک', flex: 2, fontBold: fontBold),
                _buildHeaderCell(languageProvider.isEnglish ? 'Amount' : 'رقم', flex: 1, fontBold: fontBold, align: pw.TextAlign.right),
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
                    _getMethodLabelForPayment(payment['payment_method']?.toString() ?? '—', languageProvider),
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
                    languageProvider.isEnglish ? 'Total:' : 'کل:',
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

  static String _getMethodLabelForPayment(String method, LanguageProvider languageProvider) {
    if (languageProvider.isEnglish) {
      const labels = {
        'cash': 'Cash', 'bank': 'Bank', 'cheque': 'Cheque', 'slip': 'Slip',
      };
      return labels[method.toLowerCase()] ?? method;
    } else {
      const labels = {
        'cash': 'نقد', 'bank': 'بینک', 'cheque': 'چیک', 'slip': 'سلیپ',
      };
      return labels[method.toLowerCase()] ?? method;
    }
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

  static pw.Widget _buildSignatureSection(pw.Font font, LanguageProvider languageProvider) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('_________________________',
                style: pw.TextStyle(fontSize: 12, color: textLight)),
            pw.Text(languageProvider.isEnglish ? 'Authorized Signature' : 'مجاز دستخط',
                style: pw.TextStyle(fontSize: 8, color: textLight, font: font)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('_________________________',
                style: pw.TextStyle(fontSize: 12, color: textLight)),
            pw.Text(languageProvider.isEnglish ? 'Supplier Acknowledgment' : 'سپلائر کا اعتراف',
                style: pw.TextStyle(fontSize: 8, color: textLight, font: font)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDisclaimer(pw.Font font, LanguageProvider languageProvider) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x1AD1FAE5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        languageProvider.isEnglish
            ? 'This payment report is system generated and does not require a physical signature. All amounts are in Pakistani Rupees (Rs). For any discrepancies, please contact support.'
            : 'یہ ادائیگی رپورٹ سسٹم سے تیار کردہ ہے اور اس کے لیے جسمانی دستخط کی ضرورت نہیں ہے۔ تمام رقم پاکستانی روپے (Rs) میں ہے۔ کسی بھی فرق کی صورت میں، براہ کرم سپورٹ سے رابطہ کریں۔',
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

  static String _getMethodLabel(String method, LanguageProvider languageProvider) {
    if (languageProvider.isEnglish) {
      const labels = {
        'all': 'All Methods',
        'cash': 'Cash',
        'bank': 'Bank Transfer',
        'cheque': 'Cheque',
        'slip': 'Pay Slip',
      };
      return labels[method.toLowerCase()] ?? method;
    } else {
      const labels = {
        'all': 'تمام طریقے',
        'cash': 'نقد',
        'bank': 'بینک ٹرانسفر',
        'cheque': 'چیک',
        'slip': 'پے سلیپ',
      };
      return labels[method.toLowerCase()] ?? method;
    }
  }
}