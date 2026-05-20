// lib/services/product_pdf_generator.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product_model.dart';
import 'CustomerPdfService.dart';

class ProductPdfGenerator {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF7C3AED);
  static const PdfColor accentColor = PdfColor.fromInt(0xFF10B981);
  static const PdfColor dangerColor = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor warningColor = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E1E2D);
  static const PdfColor textMedium = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor textLight = PdfColor.fromInt(0xFF9CA3AF);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFEEEEF5);
  static const PdfColor white = PdfColors.white;
  static const PdfColor bgLight = PdfColor.fromInt(0xFFF9FAFB);
  static const PdfColor primaryLight = PdfColor.fromInt(0xFFF3F0FD);

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Pkr ');

  // ─────────────────────────────────────────────────────────────────────────
  //  GENERATE PRODUCTS LIST PDF
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateProductsListPdf({
    required List<ProductModel> products,
    required Map<String, dynamic> filterInfo,
    required Map<String, dynamic> stats,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,

        margin: const pw.EdgeInsets.only(
          top: 32,      // Keep top margin for header
          bottom: 32,   // Keep bottom margin for footer
          left: 10,     // Minimal left margin
          right: 10,    // Minimal right margin
        ),
        build: (pw.Context context) => [
          _buildHeader(filterInfo),
          pw.SizedBox(height: 20),
          _buildStats(stats),
          pw.SizedBox(height: 20),
          _buildFilterSummary(filterInfo),
          pw.SizedBox(height: 20),
          _buildProductsTable(products),
          pw.SizedBox(height: 20),
          _buildFooter(products.length), // Pass products count
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HEADER SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(Map<String, dynamic> filterInfo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PRODUCTS LIST',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated on: ${_dateFormat.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: textMedium),
              ),
              pw.Text(
                'Total Products: ${filterInfo['total_count']}',
                style: pw.TextStyle(
                  fontSize: 12,
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
                'Email: info@company.com',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  STATS SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildStats(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: bgLight,
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          _buildStatBox(
            'Total Products',
            stats['total'].toString(),
            // Icons.inventory_2, // This will still cause error - see note below
            primaryColor,
          ),
          pw.SizedBox(width: 16),
          _buildStatBox(
            'Low Stock',
            stats['low_stock'].toString(),
            // Icons.warning_amber_rounded, // This will still cause error
            warningColor,
          ),
          pw.SizedBox(width: 16),
          _buildStatBox(
            'Active',
            stats['active'].toString(),
            // Icons.check_circle, // This will still cause error
            accentColor,
          ),
          pw.SizedBox(width: 16),
          _buildStatBox(
            'Inactive',
            stats['inactive'].toString(),
            // Icons.cancel, // This will still cause error
            dangerColor,
          ),
        ],
      ),
    );
  }

  // Fix for the Icon issue - use pw.Icon without Flutter Icons
  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    // Use a map of icon names to pw.IconData or use text-based icons
    pw.IconData getIconData(String name) {
      switch (name) {
        case 'inventory':
          return pw.IconData(0xe574); // You'll need the correct code points
        case 'warning':
          return pw.IconData(0xe002);
        case 'check':
          return pw.IconData(0xe5ca);
        case 'cancel':
          return pw.IconData(0xe5cd);
        default:
          return pw.IconData(0xe88e);
      }
    }

    return pw.Expanded(
      child: pw.Row(
        children: [
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 9, color: textMedium),
                ),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get icon symbols
  static String _getIconSymbol(String iconName) {
    switch (iconName) {
      case 'inventory':
        return '📦';
      case 'warning':
        return '⚠️';
      case 'check':
        return '✓';
      case 'cancel':
        return '✗';
      default:
        return '•';
    }
  }

  // Alternative approach using simple text emojis instead of icons
  static pw.Widget _buildStatsAlternative(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: bgLight,
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          _buildSimpleStatBox('📦', 'Total', stats['total'].toString(), primaryColor),
          pw.SizedBox(width: 16),
          _buildSimpleStatBox('⚠️', 'Low Stock', stats['low_stock'].toString(), warningColor),
          pw.SizedBox(width: 16),
          _buildSimpleStatBox('✓', 'Active', stats['active'].toString(), accentColor),
          pw.SizedBox(width: 16),
          _buildSimpleStatBox('✗', 'Inactive', stats['inactive'].toString(), dangerColor),
        ],
      ),
    );
  }

  static pw.Widget _buildSimpleStatBox(String emoji, String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Row(
        children: [
          pw.Container(
            width: 32,
            height: 32,
            decoration: pw.BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Center(
              child: pw.Text(
                emoji,
                style: pw.TextStyle(fontSize: 16),
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(fontSize: 9, color: textMedium),
                ),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FILTER SUMMARY SECTION
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildFilterSummary(Map<String, dynamic> filterInfo) {
    final List<String> activeFilters = [];

    if (filterInfo['category'] != null) {
      activeFilters.add('Category: ${filterInfo['category']}');
    }
    if (filterInfo['supplier'] != null) {
      activeFilters.add('Supplier: ${filterInfo['supplier']}');
    }
    if (filterInfo['unit'] != null) {
      activeFilters.add('Unit: ${filterInfo['unit']}');
    }
    if (filterInfo['low_stock'] == true) {
      activeFilters.add('Low Stock Only');
    }
    if (filterInfo['active_only'] == true) {
      activeFilters.add('Active Only');
    }
    if (filterInfo['search'] != null && filterInfo['search'].isNotEmpty) {
      activeFilters.add('Search: "${filterInfo['search']}"');
    }

    if (activeFilters.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Applied Filters:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: textDark,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 4,
            children: activeFilters.map((filter) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: primaryLight,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  filter,
                  style: pw.TextStyle(fontSize: 9, color: primaryColor),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PRODUCTS TABLE
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildProductsTable(List<ProductModel> products) {
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
                pw.Expanded(flex: 4, child: pw.Text('Product Name', style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Barcode', style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Category', style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Stock', textAlign: pw.TextAlign.center, style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Cost', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
                pw.Expanded(flex: 2, child: pw.Text('Sale', textAlign: pw.TextAlign.right, style: _tableHeaderStyle())),
                // pw.Expanded(flex: 1, child: pw.Text('Status', textAlign: pw.TextAlign.center, style: _tableHeaderStyle())),
              ],
            ),
          ),

          // Items
          ...products.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            final isEven = index.isEven;
            final isLowStock = product.physicalQty <= product.minStock;

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
                    child: pw.Text(
                      product.itemName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: isLowStock ? warningColor : textDark,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      product.barcode ?? '-',
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      product.category?.name ?? '-',
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '${product.physicalQty} ${product.unit?.symbol ?? ''}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: isLowStock ? warningColor : textDark,
                        fontWeight: isLowStock ? pw.FontWeight.bold : pw.FontWeight.normal,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      _currencyFormat.format(product.costPrice),
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      _currencyFormat.format(product.salePrice),
                      textAlign: pw.TextAlign.right,
                      style: _tableCellStyle(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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
    return const pw.TextStyle(fontSize: 9);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FOOTER
  // ─────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(int totalProducts) { // Add parameter
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: borderColor),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total Products: $totalProducts', // Use parameter
              style: pw.TextStyle(color: textLight, fontSize: 9),
            ),
            pw.Text(
              'Page 1 of 1',
              style: pw.TextStyle(color: textLight, fontSize: 9),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'This is a computer generated document',
            style: pw.TextStyle(
              color: textLight,
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
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
}