// lib/screens/services/customer_pdf_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../models/customer.dart';
import '../providers/lanprovider.dart';

class CustomerPdfService {
  static const _primaryColor = PdfColor.fromInt(0xFF10B981);
  static const _accentColor = PdfColor.fromInt(0xFF059669);
  static const _textColor = PdfColor.fromInt(0xFF1C1C1E);
  static const _lightTextColor = PdfColor.fromInt(0xFF8E8E93);

  static final _df = DateFormat('MMM dd, yyyy');
  static final _dtf = DateFormat('MMM dd, yyyy • hh:mm a');
  static final _cf = NumberFormat('#,##0.00');

  static Future<void> generatePaymentReport({
    required Customer customer,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
    required LanguageProvider languageProvider,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(customer, languageProvider),
        footer: (context) => _buildFooter(languageProvider),
        build: (context) => [
          _buildTitle(languageProvider),
          _buildSummary(totalPaid, payments.length, filterMethod, dateRange, languageProvider),
          pw.SizedBox(height: 20),
          _buildTable(payments, languageProvider),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName =
        '${customer.name.replaceAll(' ', '_')}_payments_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: languageProvider.isEnglish
          ? 'Payment Report for ${customer.name}'
          : '${customer.name} کے لیے ادائیگی رپورٹ',
    );
  }

  static void showDownloadOptions({
    required BuildContext context,
    required Customer customer,
    required List<Map<String, dynamic>> payments,
    required double totalPaid,
    required String filterMethod,
    required DateTimeRange? dateRange,
    required LanguageProvider languageProvider,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                languageProvider.isEnglish ? 'Export Payment Report' : 'ادائیگی رپورٹ ایکسپورٹ کریں',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B981)),
              ),
              title: Text(languageProvider.isEnglish ? 'Generate PDF' : 'PDF بنائیں'),
              subtitle: Text(
                languageProvider.isEnglish
                    ? '${payments.length} payments • Rs ${_cf.format(totalPaid)}'
                    : '${payments.length} ادائیگیاں • Rs ${_cf.format(totalPaid)}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                generatePaymentReport(
                  customer: customer,
                  payments: payments,
                  totalPaid: totalPaid,
                  filterMethod: filterMethod,
                  dateRange: dateRange,
                  languageProvider: languageProvider,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildHeader(Customer customer, LanguageProvider languageProvider) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                languageProvider.isEnglish ? 'Payment Report' : 'ادائیگی رپورٹ',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              pw.Text(
                customer.name,
                style: pw.TextStyle(
                  fontSize: 14,
                  color: _accentColor,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(
              languageProvider.isEnglish
                  ? 'Generated: ${_df.format(DateTime.now())}'
                  : 'تیار کردہ: ${_df.format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(LanguageProvider languageProvider) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            languageProvider.isEnglish ? 'Page ' : 'صفحہ ',
            style: pw.TextStyle(
              fontSize: 10,
              color: _lightTextColor,
            ),
          ),
          pw.Text(
            '{{page}}',
            style: pw.TextStyle(
              fontSize: 10,
              color: _lightTextColor,
            ),
          ),
          pw.Text(
            languageProvider.isEnglish ? ' of {{pages}}' : ' / {{pages}}',
            style: pw.TextStyle(
              fontSize: 10,
              color: _lightTextColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTitle(LanguageProvider languageProvider) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          languageProvider.isEnglish ? 'Payment History' : 'ادائیگی کی تاریخ',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _textColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: _lightTextColor),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _buildSummary(
      double totalPaid,
      int count,
      String filterMethod,
      DateTimeRange? dateRange,
      LanguageProvider languageProvider,
      ) {
    final filterLabel = _getMethodLabel(filterMethod, languageProvider);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF10B981).withOpacity(0.1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF10B981).withOpacity(0.3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                languageProvider.isEnglish ? 'Total Payments' : 'کل ادائیگیاں',
                count.toString(),
                languageProvider,
              ),
              _buildSummaryItem(
                languageProvider.isEnglish ? 'Total Received' : 'کل وصول شدہ',
                'Rs ${_cf.format(totalPaid)}',
                languageProvider,
              ),
              _buildSummaryItem(
                languageProvider.isEnglish ? 'Filter' : 'فلٹر',
                filterLabel.toUpperCase(),
                languageProvider,
              ),
            ],
          ),
          if (dateRange != null) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Text(
                  '📅 ',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: _primaryColor,
                  ),
                ),
                pw.Text(
                  '${_df.format(dateRange.start)} - ${_df.format(dateRange.end)}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _getMethodLabel(String method, LanguageProvider languageProvider) {
    if (languageProvider.isEnglish) {
      const labels = {
        'all': 'All',
        'cash': 'Cash',
        'bank': 'Bank Transfer',
        'cheque': 'Cheque',
        'card': 'Card',
        'online': 'Online',
      };
      return labels[method.toLowerCase()] ?? method;
    } else {
      const labels = {
        'all': 'سب',
        'cash': 'نقد',
        'bank': 'بینک ٹرانسفر',
        'cheque': 'چیک',
        'card': 'کارڈ',
        'online': 'آن لائن',
      };
      return labels[method.toLowerCase()] ?? method;
    }
  }

  static pw.Widget _buildSummaryItem(String label, String value, LanguageProvider languageProvider) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: _lightTextColor,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTable(List<Map<String, dynamic>> payments, LanguageProvider languageProvider) {
    return pw.Table(
      border: pw.TableBorder.all(color: _lightTextColor.withOpacity(0.3)),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primaryColor),
          children: [
            _buildTableCell(languageProvider.isEnglish ? 'Date' : 'تاریخ', isHeader: true),
            _buildTableCell(languageProvider.isEnglish ? 'Method' : 'طریقہ', isHeader: true),
            _buildTableCell(languageProvider.isEnglish ? 'Reference' : 'حوالہ', isHeader: true),
            _buildTableCell(languageProvider.isEnglish ? 'Amount' : 'رقم', isHeader: true, align: pw.Alignment.centerRight),
          ],
        ),
        ...payments.map((payment) {
          final date = payment['payment_date'] != null
              ? _df.format(DateTime.parse(payment['payment_date']))
              : payment['created_at'] != null
              ? _df.format(DateTime.parse(payment['created_at']))
              : '—';

          String method = payment['payment_method']?.toString() ?? 'cash';
          final methodLabel = _getMethodLabel(method, languageProvider);

          final refNum = payment['reference_number']?.toString() ??
              payment['reference']?.toString() ??
              '—';

          double amount = 0;
          if (payment['credit'] != null) {
            amount = double.tryParse(payment['credit'].toString()) ?? 0;
          } else if (payment['amount'] != null) {
            amount = double.tryParse(payment['amount'].toString()) ?? 0;
          }

          return pw.TableRow(
            children: [
              _buildTableCell(date),
              _buildTableCell(methodLabel),
              _buildTableCell(refNum),
              _buildTableCell(
                'Rs ${_cf.format(amount)}',
                align: pw.Alignment.centerRight,
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text,
      {bool isHeader = false, pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : _textColor,
        ),
      ),
    );
  }
}

// Extension to add withOpacity to PdfColor
extension PdfColorExtension on PdfColor {
  PdfColor withOpacity(double opacity) {
    return PdfColor.fromInt(
        (red.toInt() << 16) |
        (green.toInt() << 8) |
        blue.toInt() |
        ((opacity * 255).toInt() << 24)
    );
  }
}